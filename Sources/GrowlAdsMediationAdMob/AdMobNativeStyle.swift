#if canImport(UIKit)
import UIKit

/// Visual overrides applied to the ``GADNativeAdView`` that
/// ``AdMobNativeAdRenderer`` builds for AdMob native fills.
///
/// Mirrors the UIKit-flavored subset of ``GrowlAdStyle`` so the host can
/// keep the AdMob-rendered card visually consistent with Growl-direct
/// cards. Only non-nil fields are applied; everything else falls back to
/// system colors.
///
/// ```swift
/// AdMobNetworkAdapter(
///     priceTiers: tiers,
///     rootViewController: rootVC,
///     nativeAdStyle: AdMobNativeStyle(
///         cardBackground: UIColor(named: "AdCardBackground"),
///         titleColor: .label,
///         cornerRadius: 16
///     )
/// )
/// ```
public struct AdMobNativeStyle: @unchecked Sendable {
    public var cardBackground: UIColor?
    public var titleColor: UIColor?
    public var descriptionColor: UIColor?
    public var badgeColor: UIColor?
    public var borderColor: UIColor?
    public var borderWidth: CGFloat?
    public var cornerRadius: CGFloat?

    public init(
        cardBackground: UIColor? = nil,
        titleColor: UIColor? = nil,
        descriptionColor: UIColor? = nil,
        badgeColor: UIColor? = nil,
        borderColor: UIColor? = nil,
        borderWidth: CGFloat? = nil,
        cornerRadius: CGFloat? = nil
    ) {
        self.cardBackground = cardBackground
        self.titleColor = titleColor
        self.descriptionColor = descriptionColor
        self.badgeColor = badgeColor
        self.borderColor = borderColor
        self.borderWidth = borderWidth
        self.cornerRadius = cornerRadius
    }

    public static let `default` = AdMobNativeStyle()
}
#endif
