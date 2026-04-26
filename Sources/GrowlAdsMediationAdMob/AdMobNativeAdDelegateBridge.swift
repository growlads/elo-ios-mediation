import Foundation
import GrowlAds

#if canImport(GoogleMobileAds)
@preconcurrency import GoogleMobileAds

/// Forwards `GADNativeAdDelegate` callbacks into Growl's public tracking path
/// so `GrowlAdDelegate` impression and click notifications fire for AdMob
/// fills the same way they fire for Growl-sourced creatives.
///
/// AdMob counts impressions and clicks itself once the creative is registered
/// against a `GADNativeAdView`. This bridge mirrors those signals into
/// ``Growl/trackImpression(_:)`` / ``Growl/trackClick(_:)`` so the publisher's
/// delegate sees them. ``AdTrackingRegistry`` deduplicates impressions by ad
/// id, so a duplicate fire from the SwiftUI viewability tracker for the same
/// ad is a no-op.
final class AdMobNativeAdDelegateBridge: NSObject, GADNativeAdDelegate, @unchecked Sendable {
    private let onImpression: @Sendable (GrowlAd) -> Void
    private let onClick: @Sendable (GrowlAd) -> Void

    private let lock = NSLock()
    private var attachedAd: GrowlAd?

    init(
        onImpression: @escaping @Sendable (GrowlAd) -> Void = Growl.trackImpression,
        onClick: @escaping @Sendable (GrowlAd) -> Void = Growl.trackClick
    ) {
        self.onImpression = onImpression
        self.onClick = onClick
        super.init()
    }

    /// Wire the bridge to the ``GrowlAd`` it represents. Called from
    /// ``AdMobNetworkAdapter/makeCreative(from:)`` after the creative is built;
    /// the bridge stays inert until then so AdMob callbacks that arrive before
    /// the ad is fully attached are dropped rather than passed an empty value.
    func attach(ad: GrowlAd) {
        lock.lock()
        defer { lock.unlock() }
        attachedAd = ad
    }

    func nativeAdDidRecordImpression(_ nativeAd: GADNativeAd) {
        guard let ad = currentAd() else { return }
        onImpression(ad)
    }

    func nativeAdDidRecordClick(_ nativeAd: GADNativeAd) {
        guard let ad = currentAd() else { return }
        onClick(ad)
    }

    private func currentAd() -> GrowlAd? {
        lock.lock()
        defer { lock.unlock() }
        return attachedAd
    }
}
#endif
