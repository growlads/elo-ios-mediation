import Foundation
import GrowlAds

/// Reusable `AdConsent` fixtures for adapter tests. Keep these
/// snapshot-style — fields that aren't part of the scenario stay at
/// their type defaults so test failures point at the field that
/// actually mattered.
public enum MockAdConsent {
    /// User consented to everything. GDPR applies, TCF + addtl present.
    public static let allConsented = AdConsent(
        coppa: false,
        tfua: false,
        gdprApplies: true,
        tcfString: "CPmock-tcf-string",
        addtlConsent: "1~mock",
        gppString: nil,
        gppSid: nil
    )

    /// COPPA flagged; GDPR not applicable.
    public static let coppaOnly = AdConsent(
        coppa: true,
        tfua: false,
        gdprApplies: false,
        tcfString: nil,
        addtlConsent: nil,
        gppString: nil,
        gppSid: nil
    )

    /// GDPR applies, user did not consent. No TCF string present.
    public static let gdprNoConsent = AdConsent(
        coppa: false,
        tfua: false,
        gdprApplies: true,
        tcfString: nil,
        addtlConsent: nil,
        gppString: nil,
        gppSid: nil
    )
}
