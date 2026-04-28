import XCTest
import GrowlAds
@testable import GrowlAdsMediationAdMob
#if canImport(UIKit)
import UIKit
#endif

@MainActor
final class AdMobNetworkAdapterTests: XCTestCase {
    private struct NoopTracker: AdTracker {
        func trackRender() async {}
        func trackImpression() async {}
        func trackClick() async {}
    }

    #if canImport(UIKit)
    @MainActor
    private struct StubRenderer: AdRenderer {
        func makeView() -> AnyObject {
            UIView()
        }
    }
    #endif

    func testMakeCreativeMapsHeadlineBodyAndImage() {
        let assets = AdMobNativeAssets(
            identifier: "native-1",
            headline: "Sponsored hotel deal",
            body: "Book tonight and save",
            imageURL: "https://example.com/hero.png"
        )

        #if canImport(UIKit)
        let ad = AdMobCreativeMapper.makeCreative(
            from: assets,
            tracker: NoopTracker(),
            renderer: StubRenderer()
        )
        #else
        let ad = AdMobCreativeMapper.makeCreative(
            from: assets,
            tracker: NoopTracker(),
            renderer: nil
        )
        #endif

        XCTAssertEqual(ad?.id, "native-1")
        XCTAssertEqual(ad?.title, "Sponsored hotel deal")
        XCTAssertEqual(ad?.description, "Book tonight and save")
        XCTAssertEqual(ad?.imageUrl, "https://example.com/hero.png")
        #if canImport(UIKit)
        XCTAssertEqual(ad?.requiresCustomRendering, true)
        #endif
    }

    func testMakeCreativeRejectsMissingHeadline() {
        let assets = AdMobNativeAssets(
            identifier: "native-2",
            headline: nil,
            body: "Body",
            imageURL: nil
        )

        #if canImport(UIKit)
        let ad = AdMobCreativeMapper.makeCreative(
            from: assets,
            tracker: NoopTracker(),
            renderer: StubRenderer()
        )
        #else
        let ad = AdMobCreativeMapper.makeCreative(
            from: assets,
            tracker: NoopTracker(),
            renderer: nil
        )
        #endif

        XCTAssertNil(ad)
    }
}
