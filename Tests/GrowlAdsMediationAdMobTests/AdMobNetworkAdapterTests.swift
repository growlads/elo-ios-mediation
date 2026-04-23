import XCTest
import GrowlCore
@testable import GrowlAdsMediationAdMob

final class AdMobNetworkAdapterTests: XCTestCase {
    private struct NoopTracker: AdTracker {
        func trackRender() async {}
        func trackImpression() async {}
        func trackClick() async {}
    }

    func testMakeCreativeMapsHeadlineBodyAndImage() {
        let assets = AdMobNativeAssets(
            identifier: "native-1",
            headline: "Sponsored hotel deal",
            body: "Book tonight and save",
            imageURL: "https://example.com/hero.png"
        )

        let ad = AdMobCreativeMapper.makeCreative(from: assets, tracker: NoopTracker())

        XCTAssertEqual(ad?.id, "native-1")
        XCTAssertEqual(ad?.title, "Sponsored hotel deal")
        XCTAssertEqual(ad?.description, "Book tonight and save")
        XCTAssertEqual(ad?.imageUrl, "https://example.com/hero.png")
    }

    func testMakeCreativeRejectsMissingHeadline() {
        let assets = AdMobNativeAssets(
            identifier: "native-2",
            headline: nil,
            body: "Body",
            imageURL: nil
        )

        let ad = AdMobCreativeMapper.makeCreative(from: assets, tracker: NoopTracker())

        XCTAssertNil(ad)
    }
}
