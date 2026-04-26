import Foundation
import GrowlCore

#if canImport(GoogleMobileAds) && canImport(UIKit)
import UIKit
@preconcurrency import GoogleMobileAds

/// Builds a compact horizontal `GADNativeAdView` that visually matches
/// ``GrowlAdView``'s Growl-sourced card: "📢 Sponsored" badge on top, a
/// 120×120 `GADMediaView` on the leading edge, headline + body stacked to
/// its trailing side, `GADAdChoicesView` in the top-right corner.
///
/// Why 120×120 square for MediaView:
///
/// - AdMob's validator warns "MediaView is too small for video" whenever
///   the registered MediaView is smaller than 120×120, independent of the
///   current creative's content type — the check is preemptive to cover
///   future video fills on the same ad unit. 120pt is the floor.
/// - A fixed square (rather than aspect-ratio-driven) keeps the card height
///   stable across creatives — SwiftUI feeds sent through a `LazyVStack`
///   don't jitter when the next auction delivers an ad with a different
///   aspect ratio.
/// - Text column width on iPhone-SE-class devices (343pt container) is
///   ~187pt after paddings, which wraps a typical body into 2–3 lines.
///   Larger phones (390pt+) fit most bodies in 2 lines.
///
/// Why two-phase rendering (`makeView` builds chrome, `update` binds data):
///
/// Mirrors AdMob's official SwiftUI sample. Each SwiftUI host gets a fresh
/// `GADNativeAdView` (sharing one across hosts breaks UIKit's "one
/// superview per view" invariant — e.g. switching from Chat to Formats
/// would yank the cached view out of Chat's hierarchy). Asset binding —
/// especially `nativeAdView.mediaView?.mediaContent = …` and the final
/// `nativeAdView.nativeAd = …` registration — is deferred to `update(_:)`
/// so it runs *after* SwiftUI has placed the view in its window. That
/// timing matters: `GADMediaView` lazily resolves its image based on the
/// registered subview's frame, and frames are zero before the host attaches.
///
/// Not yet responsive to SwiftUI's `\.growlAdStyle` environment — defaults
/// match Growl's card colors so styled and unstyled apps look close.
@MainActor
final class AdMobNativeAdRenderer: AdRenderer, @unchecked Sendable {
    private let nativeAd: GADNativeAd
    private let delegateBridge: AdMobNativeAdDelegateBridge
    private let style: AdMobNativeStyle

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
        nativeAdView.addSubview(headlineLabel)
        nativeAdView.headlineView = headlineLabel

        let bodyLabel = WrappingLabel()
        bodyLabel.translatesAutoresizingMaskIntoConstraints = false
        bodyLabel.font = .systemFont(ofSize: 13)
        bodyLabel.numberOfLines = 0
        bodyLabel.lineBreakMode = .byWordWrapping
        bodyLabel.textColor = style.descriptionColor ?? .secondaryLabel
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
            mediaView.heightAnchor.constraint(equalToConstant: 120),
            mediaView.bottomAnchor.constraint(lessThanOrEqualTo: nativeAdView.bottomAnchor, constant: -12),

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
    /// `GADMediaView` to actually render the `mediaContent` we just put
    /// on it. Reversing the order means registration runs against an
    /// empty mediaView and the asset never makes it onto screen.
    ///
    /// Re-binding on every SwiftUI invalidation matches the sample and is
    /// idempotent for AdMob — the SDK detects same-reference re-assignment
    /// and skips re-arming the tracking.
    func update(_ view: AnyObject) {
        guard let nativeAdView = view as? GADNativeAdView else { return }

        (nativeAdView.headlineView as? UILabel)?.text = nativeAd.headline
        nativeAdView.mediaView?.mediaContent = nativeAd.mediaContent
        if let bodyLabel = nativeAdView.bodyView as? UILabel {
            bodyLabel.text = nativeAd.body
            bodyLabel.isHidden = (nativeAd.body?.isEmpty ?? true)
        }

        // Required to make the ad clickable. Must be the final binding step.
        nativeAdView.nativeAd = nativeAd
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
