import Foundation

/// Visual treatment for AdMob native ads built by ``AdMobNativeAdRenderer``.
///
/// The layout is fixed at adapter init time — every native fill from a given
/// ``AdMobNetworkAdapter`` uses the same shape. AdMob's `GADNativeAd` may
/// only register against a single `GADNativeAdView` at a time, so per-ad
/// per-mount layout choice would conflict with that contract anyway.
///
/// Pick the layout that matches the surface where the ad will display:
///
/// - ``compactHorizontal`` — chat-row-friendly, square media leading edge.
/// - ``heroCard`` — full-width media on top, ideal for slot-sized cards.
///
public enum AdMobNativeLayout: Sendable, Hashable, CaseIterable {
    /// App icon on the leading edge with headline + body
    /// stacked to its trailing side. Card height stays roughly constant
    /// across creatives, which keeps SwiftUI feeds (`LazyVStack`, `List`)
    /// from jittering when a new auction delivers an ad with a different
    /// aspect ratio.
    case compactHorizontal

    /// `GADMediaView` spans the full card width with its height driven by
    /// `mediaContent.aspectRatio`. Headline and body stack vertically below
    /// the media. Best for surfaces where the creative deserves real
    /// estate (e.g. a dedicated slot under the assistant response, a
    /// "promoted" card in a feed).
    case heroCard
}
