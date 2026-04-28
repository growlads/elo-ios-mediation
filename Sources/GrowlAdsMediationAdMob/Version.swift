import Foundation

/// Public namespace for `GrowlAdsMediationAdMob` runtime metadata.
public enum AdMobAdapter {
    /// Runtime version of this adapter, in Google's 4-part format:
    /// `<vendor-major>.<vendor-minor>.<vendor-patch>.<adapter-patch>`.
    /// Bumped per-adapter on each behavioral change, independent of
    /// the `elo-ios-mediation` repo tag.
    public static let version: String = "11.10.0.0"
}
