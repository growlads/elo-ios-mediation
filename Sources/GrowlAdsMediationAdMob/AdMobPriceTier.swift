import Foundation

/// One AdMob ad unit paired with the eCPM Growl should report when that ad
/// unit fills.
///
/// Publishers create AdMob ad units configured at fixed eCPM floors (e.g.
/// `$5`, `$2`, `$0.50`) and pass them to ``AdMobNetworkAdapter`` highest-tier
/// first. The adapter loads tiers sequentially and returns the first fill —
/// that tier's ``eCpm`` is the bid value reported to Growl's auction.
///
/// The Google Mobile Ads SDK does not expose a programmatic accessor for the
/// real bid price of a loaded ad, so the price-tier list is the authoritative
/// source of truth for AdMob's eCPM in this auction. *Which tier fills* is
/// determined by AdMob's actual demand at each floor.
public struct AdMobPriceTier: Sendable, Equatable {
    /// AdMob native ad unit id, e.g. `"ca-app-pub-3940256099942544/3986624511"`.
    public let adUnitId: String

    /// Bid value reported to Growl's mediator when this tier fills.
    public let eCpm: Double

    public init(adUnitId: String, eCpm: Double) {
        self.adUnitId = adUnitId
        self.eCpm = eCpm
    }
}
