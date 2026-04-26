import Foundation
import GrowlCore

#if canImport(GoogleMobileAds) && canImport(UIKit)
import UIKit
@preconcurrency import GoogleMobileAds

/// Builds a `GADNativeAdView` for an AdMob native fill in one of several
/// visual treatments selected via ``AdMobNativeLayout``.
///
/// All layouts share the same chrome scaffolding: rounded card background,
/// "📢 Sponsored" badge, `GADAdChoicesView` in the top-right corner, and the
/// asset slots (`iconView`/`mediaView`, `headlineView`, `bodyView`) registered
/// against `GADNativeAdView` so AdMob's tracking sees them as direct children. The
/// per-layout `build*Chrome` method only differs in where the assets live
/// and what their constraints are.
///
/// Why two-phase rendering (`makeView` builds chrome, `update` binds data):
///
/// Mirrors AdMob's official `SwiftUIDemo/Native/NativeContentView.swift`.
/// Each SwiftUI host gets a fresh `GADNativeAdView` (sharing one across
/// hosts breaks UIKit's "one superview per view" invariant). Asset binding
/// — especially `nativeAdView.mediaView?.mediaContent = …` and the final
/// `nativeAdView.nativeAd = …` registration — is deferred to ``update(_:)``
/// so it runs after SwiftUI has placed the view in its window. That timing
/// matters: `GADMediaView` lazily resolves its image based on the
/// registered subview's frame, and frames are zero before the host attaches.
@MainActor
final class AdMobNativeAdRenderer: AdRenderer, @unchecked Sendable {
    private let nativeAd: GADNativeAd
    private let delegateBridge: AdMobNativeAdDelegateBridge
    private let style: AdMobNativeStyle
    private let layout: AdMobNativeLayout

    var minimumDisplayHeight: CGFloat {
        switch layout {
        case .compactHorizontal:
            return 128
        case .heroCard:
            return 300
        }
    }

    init(
        nativeAd: GADNativeAd,
        delegateBridge: AdMobNativeAdDelegateBridge,
        style: AdMobNativeStyle = .default,
        layout: AdMobNativeLayout = .compactHorizontal
    ) {
        self.nativeAd = nativeAd
        self.delegateBridge = delegateBridge
        self.style = style
        self.layout = layout
    }

    func makeView() -> AnyObject {
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

        switch layout {
        case .compactHorizontal:
            buildCompactHorizontalChrome(in: nativeAdView)
        case .heroCard:
            buildHeroCardChrome(in: nativeAdView)
        }

        // Set the delegate now (idempotent across multiple makeView calls)
        // so the impression callback that fires on view-attachment isn't
        // missed by the time `nativeAd =` runs in `update(_:)`.
        nativeAd.delegate = delegateBridge

        return nativeAdView
    }

    /// Bind ad assets in the exact order Google's `SwiftUIDemo/Native/
    /// NativeContentView.swift` uses — text and `mediaContent` first, then
    /// `nativeAd =` last. Assigning `nativeAd` is the registration step:
    /// it arms click & impression tracking AND tells the registered
    /// `GADMediaView` to render the `mediaContent` we just put on it.
    func update(_ view: AnyObject) {
        guard let nativeAdView = view as? GADNativeAdView else { return }

        (nativeAdView.headlineView as? UILabel)?.text = nativeAd.headline
        nativeAdView.mediaView?.mediaContent = nativeAd.mediaContent
        if let iconView = nativeAdView.iconView as? UIImageView {
            iconView.image = nativeAd.icon?.image
            iconView.isHidden = nativeAd.icon == nil
        }
        if let bodyLabel = nativeAdView.bodyView as? UILabel {
            bodyLabel.text = nativeAd.body
            bodyLabel.isHidden = (nativeAd.body?.isEmpty ?? true)
        }

        // Required to make the ad clickable. Must be the final binding step.
        nativeAdView.nativeAd = nativeAd
    }

    // MARK: - Layout: compactHorizontal

    /// Compact chat row: app icon leading, headline + body trailing.
    ///
    /// Google's native examples keep app icon and media separate. The public
    /// AdMob test native creative mostly advertises Google Ads itself, so
    /// using `GADMediaView` as a chat thumbnail makes the Google Ads logo
    /// appear as oversized "media." Compact chat rows use `iconView`; the
    /// media asset remains available in `heroCard`.
    private func buildCompactHorizontalChrome(in nativeAdView: GADNativeAdView) {
        let sponsoredLabel = makeSponsoredLabel()
        let adChoicesView = makeAdChoicesView()
        let iconView = makeIconView()
        let headlineLabel = makeHeadlineLabel(font: .systemFont(ofSize: 16, weight: .semibold))
        let bodyLabel = makeBodyLabel(font: .systemFont(ofSize: 13))

        nativeAdView.addSubview(sponsoredLabel)
        nativeAdView.addSubview(adChoicesView)
        nativeAdView.addSubview(iconView)
        nativeAdView.addSubview(headlineLabel)
        nativeAdView.addSubview(bodyLabel)
        nativeAdView.adChoicesView = adChoicesView
        nativeAdView.iconView = iconView
        nativeAdView.headlineView = headlineLabel
        nativeAdView.bodyView = bodyLabel

        NSLayoutConstraint.activate([
            sponsoredLabel.topAnchor.constraint(equalTo: nativeAdView.topAnchor, constant: 12),
            sponsoredLabel.leadingAnchor.constraint(equalTo: nativeAdView.leadingAnchor, constant: 12),
            sponsoredLabel.trailingAnchor.constraint(lessThanOrEqualTo: adChoicesView.leadingAnchor, constant: -8),

            adChoicesView.topAnchor.constraint(equalTo: nativeAdView.topAnchor, constant: 8),
            adChoicesView.trailingAnchor.constraint(equalTo: nativeAdView.trailingAnchor, constant: -8),
            adChoicesView.widthAnchor.constraint(equalToConstant: 15),
            adChoicesView.heightAnchor.constraint(equalToConstant: 15),

            iconView.topAnchor.constraint(equalTo: sponsoredLabel.bottomAnchor, constant: 8),
            iconView.leadingAnchor.constraint(equalTo: nativeAdView.leadingAnchor, constant: 12),
            iconView.widthAnchor.constraint(equalToConstant: 80),
            iconView.heightAnchor.constraint(equalToConstant: 80),
            iconView.bottomAnchor.constraint(lessThanOrEqualTo: nativeAdView.bottomAnchor, constant: -12),

            headlineLabel.topAnchor.constraint(equalTo: iconView.topAnchor),
            headlineLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 12),
            headlineLabel.trailingAnchor.constraint(equalTo: nativeAdView.trailingAnchor, constant: -12),

            bodyLabel.topAnchor.constraint(equalTo: headlineLabel.bottomAnchor, constant: 4),
            bodyLabel.leadingAnchor.constraint(equalTo: headlineLabel.leadingAnchor),
            bodyLabel.trailingAnchor.constraint(equalTo: headlineLabel.trailingAnchor),
            bodyLabel.bottomAnchor.constraint(lessThanOrEqualTo: nativeAdView.bottomAnchor, constant: -12),
        ])

        // Yield to the trailing constraint before expanding text width.
        headlineLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        bodyLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
    }

    // MARK: - Layout: heroCard

    /// MediaView spans the full card width with height driven by the
    /// creative's `mediaContent.aspectRatio`; headline and body stack
    /// vertically below.
    ///
    /// The aspect-ratio constraint mirrors AdMob's documented native-ad
    /// pattern (`width = aspectRatio * height`). When `aspectRatio` is
    /// reported as 0 (e.g. a creative without media metadata), we fall
    /// back to 1.0 so the constraint stays well-formed.
    private func buildHeroCardChrome(in nativeAdView: GADNativeAdView) {
        let sponsoredLabel = makeSponsoredLabel()
        let adChoicesView = makeAdChoicesView()
        let mediaView = makeMediaView()
        let headlineLabel = makeHeadlineLabel(font: .systemFont(ofSize: 17, weight: .semibold))
        let bodyLabel = makeBodyLabel(font: .systemFont(ofSize: 14))

        nativeAdView.addSubview(sponsoredLabel)
        nativeAdView.addSubview(adChoicesView)
        nativeAdView.addSubview(mediaView)
        nativeAdView.addSubview(headlineLabel)
        nativeAdView.addSubview(bodyLabel)
        nativeAdView.adChoicesView = adChoicesView
        nativeAdView.mediaView = mediaView
        nativeAdView.headlineView = headlineLabel
        nativeAdView.bodyView = bodyLabel

        let aspectRatio = nativeAd.mediaContent.aspectRatio > 0
            ? CGFloat(nativeAd.mediaContent.aspectRatio)
            : 1.0
        let mediaAspectConstraint = NSLayoutConstraint(
            item: mediaView, attribute: .width, relatedBy: .equal,
            toItem: mediaView, attribute: .height,
            multiplier: aspectRatio, constant: 0
        )

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
            mediaView.trailingAnchor.constraint(equalTo: nativeAdView.trailingAnchor, constant: -12),
            mediaAspectConstraint,

            headlineLabel.topAnchor.constraint(equalTo: mediaView.bottomAnchor, constant: 12),
            headlineLabel.leadingAnchor.constraint(equalTo: nativeAdView.leadingAnchor, constant: 12),
            headlineLabel.trailingAnchor.constraint(equalTo: nativeAdView.trailingAnchor, constant: -12),

            bodyLabel.topAnchor.constraint(equalTo: headlineLabel.bottomAnchor, constant: 6),
            bodyLabel.leadingAnchor.constraint(equalTo: headlineLabel.leadingAnchor),
            bodyLabel.trailingAnchor.constraint(equalTo: headlineLabel.trailingAnchor),
            bodyLabel.bottomAnchor.constraint(equalTo: nativeAdView.bottomAnchor, constant: -12),
        ])

        headlineLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        bodyLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
    }

    // MARK: - Shared subview factories

    private func makeSponsoredLabel() -> UILabel {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "📢 Sponsored"
        label.font = .preferredFont(forTextStyle: .caption2)
        label.textColor = style.badgeColor ?? .secondaryLabel
        return label
    }

    private func makeAdChoicesView() -> GADAdChoicesView {
        let view = GADAdChoicesView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }

    private func makeMediaView() -> GADMediaView {
        let view = GADMediaView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.contentMode = .scaleAspectFill
        view.clipsToBounds = true
        view.layer.cornerRadius = 8
        view.layer.cornerCurve = .continuous
        view.backgroundColor = .tertiarySystemBackground
        return view
    }

    private func makeIconView() -> UIImageView {
        let view = UIImageView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.contentMode = .scaleAspectFit
        view.clipsToBounds = true
        view.layer.cornerRadius = 8
        view.layer.cornerCurve = .continuous
        view.backgroundColor = .tertiarySystemBackground
        return view
    }

    /// Place registered asset views as direct subviews of `GADNativeAdView`.
    /// AdMob's native-ad validator flags assets that aren't direct children
    /// as "Advertiser assets outside native ad view," even when the frames
    /// are mathematically inside the native ad view's bounds.
    ///
    /// `WrappingLabel` re-computes its intrinsic content size once the
    /// frame width is known — a free-standing `UILabel` with
    /// `numberOfLines = 0` reports its intrinsic size against the full
    /// unwrapped text and never rewraps inside auto-layout.
    private func makeHeadlineLabel(font: UIFont) -> WrappingLabel {
        let label = WrappingLabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = font
        label.numberOfLines = 0
        label.lineBreakMode = .byWordWrapping
        label.textColor = style.titleColor ?? .label
        return label
    }

    private func makeBodyLabel(font: UIFont) -> WrappingLabel {
        let label = WrappingLabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = font
        label.numberOfLines = 0
        label.lineBreakMode = .byWordWrapping
        label.textColor = style.descriptionColor ?? .secondaryLabel
        return label
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
