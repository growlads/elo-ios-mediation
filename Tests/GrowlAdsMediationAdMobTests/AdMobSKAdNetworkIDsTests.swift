import XCTest
@testable import GrowlAdsMediationAdMob

final class AdMobSKAdNetworkIDsTests: XCTestCase {
    func testSharedListLoadsFromBundle() {
        let ids = AdMobSKAdNetworkIDs.shared
        XCTAssertGreaterThan(ids.count, 30)
        XCTAssertTrue(ids.contains("cstr6suwn9.skadnetwork"))
    }

    func testSharedListEntriesAreSKAdNetworkIDs() {
        let ids = AdMobSKAdNetworkIDs.shared
        for id in ids {
            XCTAssertTrue(id.hasSuffix(".skadnetwork"), "expected .skadnetwork suffix: \(id)")
            XCTAssertFalse(id.isEmpty)
        }
    }
}
