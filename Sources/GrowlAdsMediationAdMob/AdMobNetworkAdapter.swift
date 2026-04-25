import Foundation
import GrowlCore

#if canImport(GoogleMobileAds)
import GoogleMobileAds

/// Google AdMob as an ``AdNetworkAdapter`` for Growl's client-side mediation.
///
/// Usage:
/// ```swift
/// Growl.configure(with: GrowlConfiguration(
///     growl: GrowlNetworkConfiguration(
///         publisherId: "YOUR_GROWL_PUB",
///         adUnitId: "YOUR_GROWL_AD_UNIT"
///     ),
///     adapters: [
///         AdMobNetworkAdapter(priceTiers: [
///             AdMobPriceTier(adUnitId: "ca-app-pub-.../high",  eCpm: 5.00),
///             AdMobPriceTier(adUnitId: "ca-app-pub-.../mid",   eCpm: 2.00),
///             AdMobPriceTier(adUnitId: "ca-app-pub-.../floor", eCpm: 0.50),
///         ]),
///     ]
/// ))
/// ```
///
/// Uses AdMob's **native ad** format only — matching Growl's native-card shape
/// in v1. Banner / interstitial / rewarded can be added later once
/// `GrowlAdView` gains format siblings.
///
/// Rendering & billing: AdMob requires creatives to be displayed inside a
/// `GADNativeAdView` for impressions and clicks to count. The adapter always
/// attaches an ``AdMobNativeAdRenderer`` to the returned ``GrowlAd`` so
/// ``GrowlAdView`` embeds an AdMob-owned layout and the ad is billable.
/// `GrowlBadgeAdView` and `GrowlChatAdView` are Growl-styled variants that
/// ignore the renderer — they are not safe surfaces for AdMob creatives.
/// Branch on ``GrowlAd/requiresCustomRendering`` to choose which surfaces to
/// show for a given bid.
///
/// eCPM: `GADNativeAd` does not expose a programmatic bid price. To make
/// AdMob fills compete fairly in Growl's auction, publishers configure AdMob
/// ad units at fixed eCPM floors and pass them as ``priceTiers`` ordered
/// highest-first. The adapter loads tiers sequentially; the first tier that
/// fills wins, and that tier's ``AdMobPriceTier/eCpm`` is the bid value
/// reported to the mediator. The price floors are authoritative — AdMob does
/// not surface a real bid price, but *which tier fills* is driven by AdMob's
/// actual demand at each floor.
public final class AdMobNetworkAdapter: NSObject, AdNetworkAdapter, @unchecked Sendable {
    public let networkId = "admob"

    public let requiredInfoPlistKeys: [String] = ["GADApplicationIdentifier"]

    /// AdMob's published SKAdNetwork identifiers for iOS install attribution.
    ///
    /// Loaded from the bundled `AdMobSKAdNetworkItems.plist` resource, which
    /// is sourced from Google's official iOS quick-start guide. Refresh the
    /// plist when Google updates the published list — see
    /// `Sources/GrowlAdsMediationAdMob/Resources/UPDATING.md`.
    public var requiredSKAdNetworkIds: [String] {
        AdMobSKAdNetworkIDs.shared
    }

    private let priceTiers: [AdMobPriceTier]
    private let rootViewControllerProvider: @MainActor @Sendable () -> UIViewController?

    /// - Parameters:
    ///   - priceTiers: AdMob ad units ordered highest-eCPM-first. The adapter
    ///     loads tiers sequentially and returns the first fill, with that
    ///     tier's ``AdMobPriceTier/eCpm`` as the bid value. Must be non-empty.
    ///   - rootViewController: Closure returning the view controller AdMob
    ///     should anchor its ad loading to. Use `nil` only if you know the
    ///     ad format doesn't need one.
    public init(
        priceTiers: [AdMobPriceTier],
        rootViewController: @escaping @MainActor @Sendable () -> UIViewController? = { nil }
    ) {
        precondition(!priceTiers.isEmpty, "AdMobNetworkAdapter requires at least one price tier")
        self.priceTiers = priceTiers
        self.rootViewControllerProvider = rootViewController
        super.init()
    }

    public func start() async throws {
        try await startGoogleMobileAds()
    }

    public func bid(_ request: AdBidRequest) async throws -> AdBid? {
        try await AdMobWaterfall.firstFill(
            tiers: priceTiers,
            timeout: request.timeout,
            loadAd: { [self] adUnitId in
                guard let nativeAd = try await loadNativeAd(adUnitId: adUnitId, request: request) else {
                    return nil
                }
                return await Self.makeCreative(from: nativeAd)
            }
        )
    }

    // MARK: - GADAdLoader async bridge

    private func loadNativeAd(adUnitId: String, request: AdBidRequest) async throws -> GADNativeAd? {
        let rootVC = await MainActor.run {
            rootViewControllerProvider()
        }
        Self.applyConsent(request.consent, requestConfiguration: GADMobileAds.sharedInstance().requestConfiguration)

        let gadRequest = GADRequest()
        if let npaParameters = AdMobConsent.nonPersonalizedAdParameters(for: request.consent) {
            let extras = GADExtras()
            extras.additionalParameters = npaParameters
            gadRequest.register(extras)
        }

        let loader = AdMobNativeAdLoader(
            adUnitId: adUnitId,
            rootViewController: rootVC,
            request: gadRequest
        )

        // The mediator races the auction against `auctionTimeout` by cancelling
        // slow bid tasks. Without this handler the AdMob load would keep its
        // task suspended until the SDK eventually calls back, defeating the
        // timeout. `cancel()` resumes the continuation with `CancellationError`
        // and releases the loader's self-retainer so the task unblocks promptly.
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<GADNativeAd?, Error>) in
                loader.start(continuation: continuation)
            }
        } onCancel: {
            loader.cancel()
        }
    }

    // MARK: - Decision C — AdMob creative mapping

    /// Map a loaded `GADNativeAd` to Growl's `GrowlAd` shape and attach an
    /// ``AdRenderer`` that registers the ad with `GADNativeAdView` at display
    /// time so AdMob can count impressions and clicks.
    ///
    /// **This is where you decide how AdMob creatives present inside
    /// `GrowlAdView`.** AdMob exposes: `headline`, `body`, `images[0]`
    /// (hero), `icon`, `advertiser`, `callToAction`, `price`, `starRating`.
    /// Growl's `GrowlAd` has only `title`, `description`, `imageUrl`.
    ///
    /// The current mapping is the minimal viable default:
    /// - title      = headline
    /// - description = body
    /// - imageUrl   = images[0]
    ///
    /// To customize, adjust the ``AdMobNativeAssets`` passed to
    /// ``AdMobCreativeMapper/makeCreative(from:tracker:renderer:)``:
    ///
    ///   1. Append the CTA to title: `"\(headline) — \(callToAction)"`.
    ///   2. Prefer icon for `GrowlBadgeAdView` contexts (compact format).
    ///   3. Fall back to advertiser name when body is empty.
    ///
    /// Return `nil` to reject the creative (the bid becomes a no-fill).
    @MainActor
    static func makeCreative(from nativeAd: GADNativeAd) -> GrowlAd? {
        // Always attach a renderer. AdMob counts impressions and clicks only
        // when the creative is displayed inside a `GADNativeAdView`;
        // ``GrowlAdView`` detects the renderer and embeds the AdMob-owned
        // layout. Badge and chat variants remain Growl-styled and are not
        // safe surfaces for AdMob — gate them on
        // ``GrowlAd/requiresCustomRendering`` in host code.
        let delegateBridge = AdMobNativeAdDelegateBridge()
        let renderer = AdMobNativeAdRenderer(
            nativeAd: nativeAd,
            delegateBridge: delegateBridge
        )
        let ad = AdMobCreativeMapper.makeCreative(
            from: AdMobNativeAssets(
                identifier: stableCreativeId(for: nativeAd),
                headline: nativeAd.headline,
                body: nativeAd.body,
                imageURL: nativeAd.images?.first?.imageURL?.absoluteString
            ),
            tracker: AdMobNativeTracker(nativeAd: nativeAd),
            renderer: renderer
        )
        // Wire the delegate bridge to the freshly-built ad so AdMob's
        // impression and click callbacks reach the publisher's
        // ``GrowlAdDelegate`` via ``Growl/trackImpression(_:)`` and
        // ``Growl/trackClick(_:)``.
        if let ad {
            delegateBridge.attach(ad: ad)
        }
        return ad
    }

    /// Derive a content-stable identifier for a loaded `GADNativeAd`.
    ///
    /// Prefer AdMob's `responseIdentifier` (set per ad-request on modern SDK
    /// versions) so the same creative reports the same id across load /
    /// impression / click events. Fall back to the Objective-C object pointer
    /// when the response info is unavailable — still unique for a live ad, but
    /// not stable across memory releases.
    private static func stableCreativeId(for nativeAd: GADNativeAd) -> String {
        if let responseId = nativeAd.responseInfo.responseIdentifier, !responseId.isEmpty {
            return "admob:\(responseId)"
        }
        return "admob:\(ObjectIdentifier(nativeAd).debugDescription)"
    }

    private func startGoogleMobileAds() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            GADMobileAds.sharedInstance().start { _ in
                continuation.resume()
            }
        }
    }

    private static func applyConsent(_ consent: AdConsent, requestConfiguration: GADRequestConfiguration) {
        // AdMob exposes COPPA / TFUA configuration globally on the request
        // configuration object. Additional TCF/GPP strings are still owned by
        // the host CMP / Google UMP, so this adapter forwards only the fields
        // the Google SDK accepts directly here.
        requestConfiguration.tagForChildDirectedTreatment = NSNumber(value: consent.coppa)
        requestConfiguration.tagForUnderAgeOfConsent = NSNumber(value: consent.tfua)
    }

}

/// Bridge GADAdLoader's delegate callbacks into a single-shot async return.
///
/// Construction is split from continuation registration so the surrounding
/// `withTaskCancellationHandler` can cancel the load before (or while) it is
/// in flight. The lock orders three states — `pending`, `loading`, `finished`
/// — so a cancel that races with a successful AdMob callback resolves to a
/// single resume.
private final class AdMobNativeAdLoader: NSObject, GADNativeAdLoaderDelegate, @unchecked Sendable {
    private let adUnitId: String
    private let rootViewController: UIViewController?
    private let request: GADRequest

    private let lock = NSLock()
    private var continuation: CheckedContinuation<GADNativeAd?, Error>?
    private var loader: GADAdLoader?
    private var selfRetainer: AdMobNativeAdLoader?
    private var completed = false
    private var cancelledBeforeStart = false

    init(
        adUnitId: String,
        rootViewController: UIViewController?,
        request: GADRequest
    ) {
        self.adUnitId = adUnitId
        self.rootViewController = rootViewController
        self.request = request
        super.init()
    }

    /// Register the continuation and start the AdMob load. If `cancel()` ran
    /// before this call (the task was already cancelled), resume immediately
    /// with `CancellationError` so the parent task unblocks.
    func start(continuation: CheckedContinuation<GADNativeAd?, Error>) {
        lock.lock()
        if cancelledBeforeStart {
            lock.unlock()
            continuation.resume(throwing: CancellationError())
            return
        }
        self.continuation = continuation
        // Keep the delegate bridge alive until AdMob calls back. Without this,
        // the local `loader` reference would drop before the SDK finishes
        // loading.
        selfRetainer = self
        let options = GADNativeAdViewAdOptions()
        let loader = GADAdLoader(
            adUnitID: adUnitId,
            rootViewController: rootViewController,
            adTypes: [.native],
            options: [options]
        )
        loader.delegate = self
        self.loader = loader
        lock.unlock()
        loader.load(request)
    }

    /// Resolve the in-flight load with `CancellationError`. Safe to call from
    /// any thread and at any point in the loader's lifecycle: before
    /// `start(continuation:)` registers a continuation, while AdMob is
    /// loading, or after a successful resolve (last call wins are no-ops).
    func cancel() {
        lock.lock()
        if continuation == nil && !completed {
            cancelledBeforeStart = true
            lock.unlock()
            return
        }
        lock.unlock()
        finish(.failure(CancellationError()))
    }

    func adLoader(_ adLoader: GADAdLoader, didReceive nativeAd: GADNativeAd) {
        finish(.success(nativeAd))
    }

    func adLoader(_ adLoader: GADAdLoader, didFailToReceiveAdWithError error: Error) {
        // AdMob treats "no fill" as an error code; translate it to a nil bid
        // rather than throwing — no-fill is a normal auction outcome.
        let ns = error as NSError
        if ns.code == GADErrorCode.noFill.rawValue {
            finish(.success(nil))
        } else {
            finish(.failure(error))
        }
    }

    private func finish(_ result: Result<GADNativeAd?, Error>) {
        lock.lock()
        guard !completed else {
            lock.unlock()
            return
        }
        completed = true
        let pendingContinuation = continuation
        continuation = nil
        loader = nil
        selfRetainer = nil
        lock.unlock()

        guard let pendingContinuation else { return }
        switch result {
        case .success(let ad): pendingContinuation.resume(returning: ad)
        case .failure(let err): pendingContinuation.resume(throwing: err)
        }
    }
}

#endif
