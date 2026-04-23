import Foundation
import GrowlCore

#if canImport(GoogleMobileAds)
import GoogleMobileAds

/// Google AdMob as an ``AdNetworkAdapter`` for Growl's client-side mediation.
///
/// Usage:
/// ```swift
/// Growl.configure(with: GrowlConfiguration(
///     publisherId: "YOUR_GROWL_PUB",
///     adUnitId: "YOUR_GROWL_AD_UNIT",
///     adapters: [
///         AdMobNetworkAdapter(
///             adUnitId: "ca-app-pub-.../1234567890",
///             assumedECpm: 1.50
///         ),
///     ]
/// ))
/// ```
///
/// Uses AdMob's **native ad** format only — matching Growl's native-card shape
/// in v1. Banner / interstitial / rewarded can be added later once
/// `GrowlAdView` gains format siblings.
///
/// eCPM: `GADNativeAd` does not expose a bid price directly; the adapter
/// reports the publisher-set ``assumedECpm`` fallback. When AdMob's bidding
/// response-info gains a programmatic eCPM accessor we can read, this
/// adapter will prefer that value over the fallback.
public final class AdMobNetworkAdapter: NSObject, AdNetworkAdapter, @unchecked Sendable {
    public let networkId = "admob"

    private let adUnitId: String
    private let assumedECpm: Double
    private let rootViewControllerProvider: @MainActor @Sendable () -> UIViewController?

    /// - Parameters:
    ///   - adUnitId: Your AdMob native ad unit id
    ///     (e.g. `"ca-app-pub-3940256099942544/2247696110"` for test ads).
    ///   - assumedECpm: Static bid value reported to Growl's mediator.
    ///   - rootViewController: Closure returning the view controller AdMob
    ///     should anchor its ad loading to. Use `nil` only if you know the
    ///     ad format doesn't need one.
    public init(
        adUnitId: String,
        assumedECpm: Double,
        rootViewController: @escaping @MainActor @Sendable () -> UIViewController? = { nil }
    ) {
        self.adUnitId = adUnitId
        self.assumedECpm = assumedECpm
        self.rootViewControllerProvider = rootViewController
        super.init()
    }

    public func start() async throws {
        try await startGoogleMobileAds()
    }

    public func bid(_ request: AdBidRequest) async throws -> AdBid? {
        let nativeAd = try await loadNativeAd(request: request)
        guard let nativeAd else { return nil }

        guard let ad = await Self.makeCreative(from: nativeAd) else { return nil }
        return AdBid(networkId: networkId, eCpm: assumedECpm, ad: ad)
    }

    // MARK: - GADAdLoader async bridge

    private func loadNativeAd(request: AdBidRequest) async throws -> GADNativeAd? {
        let rootVC = await MainActor.run {
            rootViewControllerProvider()
        }
        Self.applyConsent(request.consent, requestConfiguration: GADMobileAds.sharedInstance().requestConfiguration)

        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<GADNativeAd?, Error>) in
            let loader = AdMobNativeAdLoader(
                adUnitId: adUnitId,
                rootViewController: rootVC,
                continuation: continuation
            )
            loader.load()
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
    /// TODO: Replace the body of this function with your product's preferred
    /// mapping. A few directions to consider (pick the one that matches your
    /// ad unit's creative style):
    ///
    ///   1. Append the CTA to title: `"\(headline) — \(callToAction)"`.
    ///   2. Prefer icon for `GrowlBadgeAdView` contexts (compact format).
    ///   3. Fall back to advertiser name when body is empty.
    ///   4. Return `nil` when headline is missing — AdMob treats that as
    ///      a malformed creative and the bid drops from the auction.
    ///
    /// Return `nil` to reject the creative (the bid becomes a no-fill).
    @MainActor
    static func makeCreative(from nativeAd: GADNativeAd) -> GrowlAd? {
        // Display-only mode: AdMob creatives render through Growl's SwiftUI
        // card (``GrowlAdView``'s default branch), not a `GADNativeAdView`.
        //
        // This is the pre-renderer behavior. AdMob impressions and clicks
        // are NOT billed in this mode because AdMob's tracking contract
        // requires `GADNativeAdView` registration — which our SwiftUI card
        // deliberately does not provide. The upside is visual consistency
        // with Growl's card style and no AdMob native-ad validator warnings.
        //
        // When AdMob revenue matters to a publisher, switch to the renderer
        // path by building an `AdMobNativeAdRenderer` here and passing it to
        // ``AdMobCreativeMapper/makeCreative(from:tracker:renderer:)``. The
        // renderer machinery is intact — see ``AdMobNativeAdRenderer`` and
        // ``AdMobNativeAdDelegateBridge``.
        return AdMobCreativeMapper.makeCreative(
            from: AdMobNativeAssets(
                identifier: ObjectIdentifier(nativeAd).debugDescription,
                headline: nativeAd.headline,
                body: nativeAd.body,
                imageURL: nativeAd.images?.first?.imageURL?.absoluteString
            ),
            tracker: AdMobNativeTracker(nativeAd: nativeAd),
            renderer: nil
        )
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
/// Retained by itself while the load is in flight; released in the
/// success / failure path.
private final class AdMobNativeAdLoader: NSObject, GADNativeAdLoaderDelegate, @unchecked Sendable {
    private let adUnitId: String
    private let rootViewController: UIViewController?
    private let continuation: CheckedContinuation<GADNativeAd?, Error>
    private var loader: GADAdLoader?
    private var selfRetainer: AdMobNativeAdLoader?
    private var completed = false
    private let lock = NSLock()

    init(
        adUnitId: String,
        rootViewController: UIViewController?,
        continuation: CheckedContinuation<GADNativeAd?, Error>
    ) {
        self.adUnitId = adUnitId
        self.rootViewController = rootViewController
        self.continuation = continuation
        super.init()
    }

    func load() {
        // Keep the delegate bridge alive until AdMob calls back. Without this,
        // the local `loader` variable in `withCheckedThrowingContinuation`
        // drops its last strong reference before the SDK finishes loading.
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
        loader.load(GADRequest())
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
        defer { lock.unlock() }
        guard !completed else { return }
        completed = true
        loader = nil
        selfRetainer = nil
        switch result {
        case .success(let ad): continuation.resume(returning: ad)
        case .failure(let err): continuation.resume(throwing: err)
        }
    }
}

#endif
