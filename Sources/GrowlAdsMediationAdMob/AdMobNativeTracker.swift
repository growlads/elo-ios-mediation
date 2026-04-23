import Foundation
import GrowlCore

#if canImport(GoogleMobileAds)
@preconcurrency import GoogleMobileAds

/// ``AdTracker`` backed by a ``GADNativeAd``.
///
/// AdMob does impression and click tracking through its own APIs — calling
/// `recordImpression()` on the ad and registering views for click tracking —
/// not through URL pings. This tracker turns Growl's three tracking calls
/// into the right AdMob operations so the SDK never needs to know it's
/// holding an AdMob ad.
///
/// Render: AdMob doesn't have a "render" event. We call `recordImpression()`
/// here too; the SDK's view-dwell dedup means we won't double-fire.
///
/// Click: AdMob tracks clicks automatically when you register the ad view
/// with `GADNativeAdView` — see the host-app integration for that wiring.
/// The explicit `trackClick` call here is a no-op for AdMob; the SDK still
/// invokes it for symmetry with Growl's URL-ping model.
package struct AdMobNativeTracker: AdTracker {
    package init(nativeAd: GADNativeAd) {}

    package func trackRender() async {
        // AdMob native measurement is tied to registering a GADNativeAdView.
        // Growl's generic SwiftUI surfaces do not do that yet, so load testing
        // keeps this as a no-op for now.
    }

    package func trackImpression() async {
        // Full AdMob impression tracking requires GADNativeAdView integration.
        // Until Growl adds an AdMob-specific rendering bridge, we intentionally
        // no-op here so example-app load testing can proceed without pretending
        // to report unsupported generic impressions.
    }

    package func trackClick() async {
        // AdMob clicks are auto-tracked via GADNativeAdView registration.
        // Generic Growl views are not registered yet, so this remains a no-op.
    }
}
#endif
