import Foundation
import GrowlCore

/// Consent-derived parameters that the adapter forwards to the Google Mobile
/// Ads SDK on each request.
///
/// Lives outside the `#if canImport(GoogleMobileAds)` boundary so the
/// derivation logic is testable on macOS without linking the iOS-only
/// AdMob SDK.
enum AdMobConsent {
    /// Build the AdMob extras dictionary instructing AdMob to serve only
    /// non-personalized ads when GDPR applies and the user has not consented
    /// to TCF Purpose 1 ("Store and/or access information on a device").
    /// Returns `nil` when the request can use personalized ads.
    ///
    /// Reads `IABTCF_PurposeConsents` from the supplied `UserDefaults` (the
    /// IAB-standard key written by TCF v2 consent management platforms). If
    /// the key is absent, treats Purpose 1 as not consented — a fail-closed
    /// default matching AppLovin's adapter behavior in EU traffic.
    static func nonPersonalizedAdParameters(
        for consent: AdConsent,
        userDefaults: UserDefaults = .standard
    ) -> [String: String]? {
        guard consent.gdprApplies == true else { return nil }
        let purposeConsents = userDefaults.string(forKey: "IABTCF_PurposeConsents") ?? ""
        let purpose1Consented = purposeConsents.first == "1"
        guard !purpose1Consented else { return nil }
        return ["npa": "1"]
    }
}
