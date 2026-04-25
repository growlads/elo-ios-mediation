import Foundation
import GrowlCore

#if canImport(GoogleMobileAds) && canImport(UIKit)
import UIKit
@preconcurrency import GoogleMobileAds

/// Builds a compact horizontal `GADNativeAdView` that visually matches
/// ``GrowlAdView``'s Growl-sourced card: "📢 Sponsored" badge on top, a
/// 120pt-wide `GADMediaView` on the leading edge that stretches vertically
/// to fill the card (≥120pt min, more when body copy is long), headline +
/// body stacked to its trailing side, `GADAdChoicesView` in the top-right
/// corner.
///
/// Why 120pt-wide MediaView with flexible height:
///
/// - AdMob's validator warns "MediaView is too small for video" whenever
///   the registered MediaView is smaller than 120×120, independent of the
///   current creative's content type — the check is preemptive to cover
///   future video fills on the same ad unit. 120pt is the floor.
/// - The height is `≥ 120` and pinned to the card bottom, so when the body
///   text wraps to multiple lines and pushes the card taller than 120pt,
///   the mediaView grows with it instead of leaving an empty band on the
///   left. Width stays fixed at 120pt to keep the text column predictable.
/// - Text column width on iPhone-SE-class devices (343pt container) is
///   ~187pt after paddings, which wraps a typical body into 2–3 lines.
///   Larger phones (390pt+) fit most bodies in 2 lines.
///
/// Not yet responsive to SwiftUI's `\.growlAdStyle` environment — defaults
/// match Growl's card colors so styled and unstyled apps look close.
@MainActor
final class AdMobNativeAdRenderer: AdRenderer, @unchecked Sendable {
    private let nativeAd: GADNativeAd
    private let delegateBridge: AdMobNativeAdDelegateBridge
    private let style: AdMobNativeStyle

    /// Cached `GADNativeAdView` so the SwiftUI representable returns the
    /// same instance across re-mounts (e.g. tab switches). Constructing a
    /// fresh `GADNativeAdView` per re-mount and re-assigning `nativeAd =`
    /// re-arms tracking but does not always re-render the bound
    /// `GADMediaView`'s image, leaving the ad text-only on subsequent
    /// mounts. Reusing the same view also avoids double impressions.
    private var cachedView: GADNativeAdView?

    init(
        nativeAd: GADNativeAd,
        delegateBridge: AdMobNativeAdDelegateBridge,
        style: AdMobNativeStyle = .default
    ) {
        self.nativeAd = nativeAd
        self.delegateBridge = delegateBridge
        self.style = style
    }

    func makeView() -> AnyObject {
        if let cached = cachedView {
            // SwiftUI hands the view to a new host on re-mount; detach from
            // the previous host first so AutoLayout doesn't fight the move.
            cached.removeFromSuperview()
            return cached
        }

        let nativeAdView = GADNativeAdView()
        nativeAdView.translatesAutoresizingMaskIntoConstraints = false
        nativeAdView.backgroundColor = style.cardBackground ?? .secondarySystemBackground
        nativeAdView.layer.cornerRadius = style.cornerRadius ?? 12
        nativeAdView.layer.cornerCurve = .continuous
        nativeAdView.clipsToBounds = true
        if let borderColor = style.borderColor, let borderWidth = style.borderWidth {
            nativeAdView.layer.borderColor = borderColor.cgColor
            nativeAdView.layer.borderWidth = borderWidth
        }

        let sponsoredLabel = UILabel()
        sponsoredLabel.translatesAutoresizingMaskIntoConstraints = false
        sponsoredLabel.text = "📢 Sponsored"
        sponsoredLabel.font = .preferredFont(forTextStyle: .caption2)
        sponsoredLabel.textColor = style.badgeColor ?? .secondaryLabel
        nativeAdView.addSubview(sponsoredLabel)

        let adChoicesView = GADAdChoicesView()
        adChoicesView.translatesAutoresizingMaskIntoConstraints = false
        nativeAdView.addSubview(adChoicesView)
        nativeAdView.adChoicesView = adChoicesView

        let mediaView = GADMediaView()
        mediaView.translatesAutoresizingMaskIntoConstraints = false
        mediaView.contentMode = .scaleAspectFill
        mediaView.clipsToBounds = true
        mediaView.layer.cornerRadius = 8
        mediaView.layer.cornerCurve = .continuous
        mediaView.backgroundColor = .tertiarySystemBackground
        mediaView.mediaContent = nativeAd.mediaContent
        nativeAdView.addSubview(mediaView)
        nativeAdView.mediaView = mediaView

        // Place registered asset views as direct subviews of `GADNativeAdView`.
        // AdMob's native-ad validator flags assets that aren't direct children
        // as "Advertiser assets outside native ad view," even when the frames
        // are mathematically inside the native ad view's bounds. Google's own
        // sample native layouts always hang assets directly off the root
        // native ad view.
        //
        // Use `WrappingLabel` so each label re-computes its intrinsic content
        // size once the frame width is known — a free-standing `UILabel` with
        // `numberOfLines = 0` reports its intrinsic size against the full
        // unwrapped text and never rewraps inside auto-layout.
        let headlineLabel = WrappingLabel()
        headlineLabel.translatesAutoresizingMaskIntoConstraints = false
        headlineLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        headlineLabel.numberOfLines = 0
        headlineLabel.lineBreakMode = .byWordWrapping
        headlineLabel.textColor = style.titleColor ?? .label
        headlineLabel.text = nativeAd.headline
        nativeAdView.addSubview(headlineLabel)
        nativeAdView.headlineView = headlineLabel

        let bodyLabel = WrappingLabel()
        bodyLabel.translatesAutoresizingMaskIntoConstraints = false
        bodyLabel.font = .systemFont(ofSize: 13)
        bodyLabel.numberOfLines = 0
        bodyLabel.lineBreakMode = .byWordWrapping
        bodyLabel.textColor = style.descriptionColor ?? .secondaryLabel
        bodyLabel.text = nativeAd.body
        bodyLabel.isHidden = (nativeAd.body?.isEmpty ?? true)
        nativeAdView.addSubview(bodyLabel)
        nativeAdView.bodyView = bodyLabel

        NSLayoutConstraint.activate([
            sponsoredLabel.topAnchor.constraint(equalTo: nativeAdView.topAnchor, constant: 12),
            sponsoredLabel.leadingAnchor.constraint(equalTo: nativeAdView.leadingAnchor, constant: 12),
            sponsoredLabel.trailingAnchor.constraint(lessThanOrEqualTo: adChoicesView.leadingAnchor, constant: -8),

            adChoicesView.topAnchor.constraint(equalTo: nativeAdView.topAnchor, constant: 8),
            adChoicesView.trailingAnchor.constraint(equalTo: nativeAdView.trailingAnchor, constant: -8),
            adChoicesView.widthAnchor.constraint(equalToConstant: 15),
            adChoicesView.heightAnchor.constraint(equalToConstant: 15),

            mediaView.topAnchor.constraint(equalTo: sponsoredLabel.bottomAnchor, constant: 8),
            mediaView.leadingAnchor.constraint(equalTo: nativeAdView.leadingAnchor, constant: 12),
            mediaView.widthAnchor.constraint(equalToConstant: 120),
            mediaView.heightAnchor.constraint(greaterThanOrEqualToConstant: 120),
            mediaView.bottomAnchor.constraint(equalTo: nativeAdView.bottomAnchor, constant: -12),

            headlineLabel.topAnchor.constraint(equalTo: mediaView.topAnchor),
            headlineLabel.leadingAnchor.constraint(equalTo: mediaView.trailingAnchor, constant: 12),
            headlineLabel.trailingAnchor.constraint(equalTo: nativeAdView.trailingAnchor, constant: -12),

            bodyLabel.topAnchor.constraint(equalTo: headlineLabel.bottomAnchor, constant: 4),
            bodyLabel.leadingAnchor.constraint(equalTo: headlineLabel.leadingAnchor),
            bodyLabel.trailingAnchor.constraint(equalTo: headlineLabel.trailingAnchor),
            bodyLabel.bottomAnchor.constraint(lessThanOrEqualTo: nativeAdView.bottomAnchor, constant: -12),
        ])

        // Yield to the trailing constraint before expanding text width.
        headlineLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        bodyLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        // Wire tracking last: delegate before `nativeAd` assignment so the
        // impression callback that fires on view-attachment isn't missed.
        // Assigning `nativeAd` arms AdMob's click tracking on the registered
        // subviews.
        nativeAd.delegate = delegateBridge
        nativeAdView.nativeAd = nativeAd

        cachedView = nativeAdView
        return nativeAdView
    }
}

/// UILabel that keeps `preferredMaxLayoutWidth` in sync with its own frame.
///
/// A plain UILabel with `numberOfLines = 0` reports its intrinsic size
/// against the unwrapped text (single line) because `preferredMaxLayoutWidth`
/// defaults to `0`. Auto-layout then squeezes the label, but the label's
/// internal drawing doesn't re-wrap — the rendered text spills past the
/// frame, and AdMob's native-ad validator flags the result as
/// "Advertiser assets outside native ad view." Syncing the property in
/// `layoutSubviews` forces the second layout pass to compute wrap height
/// against the actual frame width.
private final class WrappingLabel: UILabel {
    override func layoutSubviews() {
        super.layoutSubviews()
        if preferredMaxLayoutWidth != bounds.width {
            preferredMaxLayoutWidth = bounds.width
            setNeedsUpdateConstraints()
        }
    }
}
#endif
