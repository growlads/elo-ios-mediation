import XCTest
import GrowlCore
@testable import GrowlAdsMediationAdMob

final class AdMobWaterfallTests: XCTestCase {
    private struct NoopTracker: AdTracker {
        func trackRender() async {}
        func trackImpression() async {}
        func trackClick() async {}
    }

    func testFirstFillReturnsBidPricedAtThatTier() async throws {
        let tiers = [
            AdMobPriceTier(adUnitId: "high", eCpm: 5.0),
            AdMobPriceTier(adUnitId: "mid",  eCpm: 2.0),
            AdMobPriceTier(adUnitId: "low",  eCpm: 0.5),
        ]

        let bid = try await AdMobWaterfall.firstFill(
            tiers: tiers,
            timeout: 5.0,
            loadAd: { adUnitId in
                adUnitId == "mid" ? Self.makeStubAd(id: "ad-\(adUnitId)") : nil
            }
        )

        XCTAssertEqual(bid?.networkId, "admob")
        XCTAssertEqual(bid?.eCpm, 2.0)
        XCTAssertEqual(bid?.ad.id, "ad-mid")
    }

    func testFirstFillStopsAtHighestFillingTier() async throws {
        let tiers = [
            AdMobPriceTier(adUnitId: "high", eCpm: 5.0),
            AdMobPriceTier(adUnitId: "low",  eCpm: 0.5),
        ]

        let bid = try await AdMobWaterfall.firstFill(
            tiers: tiers,
            timeout: 5.0,
            loadAd: { adUnitId in
                Self.makeStubAd(id: "ad-\(adUnitId)")
            }
        )

        XCTAssertEqual(bid?.eCpm, 5.0)
        XCTAssertEqual(bid?.ad.id, "ad-high")
    }

    func testFirstFillReturnsNilWhenAllTiersNoFill() async throws {
        let tiers = [
            AdMobPriceTier(adUnitId: "high", eCpm: 5.0),
            AdMobPriceTier(adUnitId: "low",  eCpm: 0.5),
        ]

        let bid = try await AdMobWaterfall.firstFill(
            tiers: tiers,
            timeout: 5.0,
            loadAd: { _ in nil }
        )

        XCTAssertNil(bid)
    }

    func testFirstFillReturnsNilForEmptyTiers() async throws {
        let bid = try await AdMobWaterfall.firstFill(
            tiers: [],
            timeout: 5.0,
            loadAd: { _ in
                XCTFail("loadAd should not be called for empty tiers")
                return nil
            }
        )
        XCTAssertNil(bid)
    }

    private static func makeStubAd(id: String) -> GrowlAd {
        GrowlAd(
            id: id,
            title: "Stub",
            description: nil,
            imageUrl: nil,
            tracker: NoopTracker(),
            renderer: nil
        )
    }
}
