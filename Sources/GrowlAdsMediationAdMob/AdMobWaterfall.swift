import Foundation
import GrowlAds

/// Sequential price-tier waterfall used by ``AdMobNetworkAdapter`` to drive
/// AdMob fills against an explicit eCPM ladder.
///
/// Lives outside the `#if canImport(GoogleMobileAds)` boundary so the
/// iteration logic is testable on macOS without linking the iOS-only AdMob
/// SDK. The closure abstracts the actual ad load so tests can simulate
/// fill / no-fill outcomes directly.
enum AdMobWaterfall {
    /// Iterate `tiers` highest-first, returning the first non-nil ad as an
    /// ``AdBid`` priced at that tier's `eCpm`. Returns `nil` if every tier
    /// reports no-fill or if the deadline elapses before the next attempt.
    ///
    /// - Parameters:
    ///   - tiers: Price tiers ordered highest-eCPM-first.
    ///   - timeout: Total time budget. Tiers are not started after the
    ///     deadline; an in-flight load is allowed to complete.
    ///   - loadAd: Closure that loads an ad for a specific tier ad unit and
    ///     returns the rendered ``GrowlAd`` (or `nil` for no-fill).
    static func firstFill(
        tiers: [AdMobPriceTier],
        timeout: TimeInterval,
        loadAd: (String) async throws -> GrowlAd?
    ) async throws -> AdBid? {
        let deadline = Date().addingTimeInterval(timeout)
        for tier in tiers {
            if Date() >= deadline { return nil }
            guard let ad = try await loadAd(tier.adUnitId) else { continue }
            return AdBid(networkId: "admob", eCpm: tier.eCpm, ad: ad)
        }
        return nil
    }
}
