import XCTest
import GrowlAds
@testable import GrowlAdsMediationAdMob

final class AdMobConsentTests: XCTestCase {
    func testNoNPAWhenGDPRDoesNotApply() {
        let consent = Self.makeConsent(gdprApplies: false)
        let suite = Self.freshDefaults("test-npa-no-gdpr")
        XCTAssertNil(AdMobConsent.nonPersonalizedAdParameters(for: consent, userDefaults: suite))
    }

    func testNoNPAWhenGDPRAppliesUnknown() {
        let consent = Self.makeConsent(gdprApplies: nil)
        let suite = Self.freshDefaults("test-npa-gdpr-unknown")
        XCTAssertNil(AdMobConsent.nonPersonalizedAdParameters(for: consent, userDefaults: suite))
    }

    func testNPASetWhenGDPRAppliesAndPurpose1Denied() {
        let consent = Self.makeConsent(gdprApplies: true)
        let suite = Self.freshDefaults("test-npa-purpose1-denied")
        suite.set("00000000000", forKey: "IABTCF_PurposeConsents")
        let params = AdMobConsent.nonPersonalizedAdParameters(for: consent, userDefaults: suite)
        XCTAssertEqual(params?["npa"], "1")
    }

    func testNoNPAWhenPurpose1Consented() {
        let consent = Self.makeConsent(gdprApplies: true)
        let suite = Self.freshDefaults("test-npa-purpose1-ok")
        suite.set("11111111111", forKey: "IABTCF_PurposeConsents")
        XCTAssertNil(AdMobConsent.nonPersonalizedAdParameters(for: consent, userDefaults: suite))
    }

    func testNPASetWhenPurposeConsentsKeyAbsent() {
        // Fail-closed: when no IAB CMP wrote the key, default to NPA on.
        let consent = Self.makeConsent(gdprApplies: true)
        let suite = Self.freshDefaults("test-npa-purpose1-absent")
        let params = AdMobConsent.nonPersonalizedAdParameters(for: consent, userDefaults: suite)
        XCTAssertEqual(params?["npa"], "1")
    }

    private static func makeConsent(gdprApplies: Bool?) -> AdConsent {
        AdConsent(
            coppa: false,
            tfua: false,
            gdprApplies: gdprApplies,
            tcfString: nil,
            addtlConsent: nil,
            gppString: nil,
            gppSid: nil
        )
    }

    private static func freshDefaults(_ suiteName: String) -> UserDefaults {
        let suite = UserDefaults(suiteName: suiteName)!
        suite.removePersistentDomain(forName: suiteName)
        return suite
    }
}
