import Foundation
import GrowlCore

#if canImport(GoogleMobileAds)
@preconcurrency import GoogleMobileAds

/// Forwards `GADNativeAdDelegate` callbacks into Growl's public tracking path.
final class AdMobNativeAdDelegateBridge: NSObject, GADNativeAdDelegate, @unchecked Sendable {
    private let onImpression: @Sendable () -> Void
    private let onClick: @Sendable () -> Void

    init(
        onImpression: @escaping @Sendable () -> Void,
        onClick: @escaping @Sendable () -> Void
    ) {
        self.onImpression = onImpression
        self.onClick = onClick
        super.init()
    }

    func nativeAdDidRecordImpression(_ nativeAd: GADNativeAd) {
        onImpression()
    }

    func nativeAdDidRecordClick(_ nativeAd: GADNativeAd) {
        onClick()
    }
}
#endif
