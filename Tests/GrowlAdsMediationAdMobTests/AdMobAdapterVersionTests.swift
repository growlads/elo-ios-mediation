import XCTest
@testable import GrowlAdsMediationAdMob

final class AdMobAdapterVersionTests: XCTestCase {
    func testVersionFollowsFourPartFormat() {
        let version = AdMobAdapter.version
        let parts = version.split(separator: ".")
        XCTAssertEqual(parts.count, 4, "Expected vendor-major.vendor-minor.vendor-patch.adapter-patch, got \(version)")
        for (i, part) in parts.enumerated() {
            XCTAssertNotNil(Int(part), "Part \(i) (\(part)) is not numeric")
        }
    }

    func testVersionMatchesCurrentRelease() {
        XCTAssertEqual(AdMobAdapter.version, "11.10.0.0")
    }
}
