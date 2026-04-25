import Foundation

/// AdMob's iOS SKAdNetwork identifier allowlist, loaded from a bundled plist.
///
/// The list is sourced from Google's official iOS quick-start documentation
/// and cached on first access. Refreshing the published list is a documented
/// maintenance procedure — see `Resources/UPDATING.md`.
///
/// Internal so tests can `@testable import` and assert coverage; consumers
/// access the list via ``AdMobNetworkAdapter/requiredSKAdNetworkIds``.
enum AdMobSKAdNetworkIDs {
    /// Cached identifiers parsed from `AdMobSKAdNetworkItems.plist`.
    static let shared: [String] = loadFromBundle()

    private static func loadFromBundle() -> [String] {
        guard let url = Bundle.module.url(
            forResource: "AdMobSKAdNetworkItems",
            withExtension: "plist"
        ) else {
            assertionFailure("AdMobSKAdNetworkItems.plist not found in module bundle — check Package.swift resources")
            return []
        }
        do {
            let data = try Data(contentsOf: url)
            let entries = try PropertyListSerialization.propertyList(
                from: data,
                format: nil
            ) as? [[String: Any]] ?? []
            return entries.compactMap { $0["SKAdNetworkIdentifier"] as? String }
        } catch {
            assertionFailure("Failed to parse AdMobSKAdNetworkItems.plist: \(error)")
            return []
        }
    }
}
