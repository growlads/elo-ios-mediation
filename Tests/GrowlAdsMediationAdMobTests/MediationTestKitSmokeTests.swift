import XCTest
import GrowlAds
import MediationTestKit

final class MediationTestKitSmokeTests: XCTestCase {
    func testMockAdConsentAllConsentedHasGdprApplies() {
        let consent = MockAdConsent.allConsented
        XCTAssertTrue(consent.gdprApplies == true)
        XCTAssertNotNil(consent.tcfString)
        XCTAssertFalse(consent.coppa)
    }

    func testMockAdConsentCoppaOnly() {
        let consent = MockAdConsent.coppaOnly
        XCTAssertTrue(consent.coppa)
        XCTAssertFalse(consent.gdprApplies == true)
    }

    func testMockAdConsentGdprNoConsent() {
        let consent = MockAdConsent.gdprNoConsent
        XCTAssertTrue(consent.gdprApplies == true)
        XCTAssertNil(consent.tcfString)
    }

    func testMockAdBidRequestBuilderDefaults() {
        let request = MockAdBidRequest.make(adUnitId: "test-unit")
        XCTAssertEqual(request.adUnitId, "test-unit")
        XCTAssertGreaterThan(request.timeout, 0)
    }

    func testAdNetworkAdapterRunnerExists() {
        // Type-existence check; behavior is exercised by adapter tests.
        let _ = AdNetworkAdapterRunner.self
    }
}
