import Foundation
import GrowlAds

#if canImport(GoogleMobileAds)
@preconcurrency import GoogleMobileAds

/// ``AdTracker`` shim for AdMob native ads.
///
/// AdMob records impressions and clicks automatically once a `GADNativeAdView`
/// is assigned a `GADNativeAd`. The heavy lifting lives in
/// ``AdMobNativeAdRenderer`` and ``AdMobNativeAdDelegateBridge``. This tracker
/// exists only to satisfy the ``AdTracker`` contract that ``GrowlAd``
/// requires, so all methods are intentional no-ops.
package struct AdMobNativeTracker: AdTracker {
    package init(nativeAd: GADNativeAd) {}

    package func trackRender() async {
        // No-op: AdMob has no distinct render event.
    }

    package func trackImpression() async {
        // No-op: AdMob records impressions automatically from GADNativeAdView.
    }

    package func trackClick() async {
        // No-op: AdMob captures clicks through registered native-ad subviews.
    }
}
#endif
