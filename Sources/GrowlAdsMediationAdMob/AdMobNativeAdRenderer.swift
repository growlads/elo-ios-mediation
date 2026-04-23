import Foundation
import GrowlCore

#if canImport(GoogleMobileAds) && canImport(UIKit)
import UIKit
@preconcurrency import GoogleMobileAds

/// Builds a `GADNativeAdView` that follows AdMob's standard vertical layout
/// for native ads: sponsored badge at top, full-width `GADMediaView` sized
/// to the creative's aspect ratio (with a minimum 120pt height per AdMob
/// policy), full-width headline and body below.
///
/// Why vertical and full-width, not the 72×72 horizontal card that matches
/// ``GrowlAdView``'s SwiftUI layout:
///
/// - `GADMediaView` is Google-owned. When forced into a 72×72 frame, its
///   internal content drawing can exceed that frame if the creative's
///   aspect ratio differs, which AdMob's validator flags as "assets outside
///   native ad view."
/// - AdMob policy requires MediaView ≥ 120×120 so video creatives have
///   room to render. Our 72×72 layout always triggered
///   "MediaView is too small for video," regardless of the current creative.
///
/// Publishers who want Growl's tight 72×72 card for AdMob would need the
/// overlay-on-SwiftUI approach (render SwiftUI, position invisible UIKit
/// asset views on top, register those). That pattern is fragile and out of
/// scope for v1. For now, AdMob creatives use this AdMob-standard layout
/// and ``GrowlAdView`` is the billable surface for the AdMob adapter.
///
/// Not yet responsive to SwiftUI's `\.growlAdStyle` environment — defaults
/// match Growl's card colors so styled and unstyled apps look close.
@MainActor
final class AdMobNativeAdRenderer: AdRenderer, @unchecked Sendable {
    private let nativeAd: GADNativeAd
    private let delegateBridge: AdMobNativeAdDelegateBridge

    init(
        nativeAd: GADNativeAd,
        delegateBridge: AdMobNativeAdDelegateBridge
    ) {
        self.nativeAd = nativeAd
        self.delegateBridge = delegateBridge
    }

    func makeView() -> AnyObject {
        let nativeAdView = GADNativeAdView()
        nativeAdView.translatesAutoresizingMaskIntoConstraints = false
        nativeAdView.backgroundColor = .secondarySystemBackground
        nativeAdView.layer.cornerRadius = 12
        nativeAdView.layer.cornerCurve = .continuous
        nativeAdView.clipsToBounds = true

        let sponsoredLabel = UILabel()
        sponsoredLabel.translatesAutoresizingMaskIntoConstraints = false
        sponsoredLabel.text = "📢 Sponsored"
        sponsoredLabel.font = .preferredFont(forTextStyle: .caption2)
        sponsoredLabel.textColor = .secondaryLabel
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

        let headlineLabel = UILabel()
        headlineLabel.translatesAutoresizingMaskIntoConstraints = false
        headlineLabel.font = .systemFont(ofSize: 16, weight: .bold)
        headlineLabel.numberOfLines = 0
        headlineLabel.textColor = .label
        headlineLabel.text = nativeAd.headline
        nativeAdView.addSubview(headlineLabel)
        nativeAdView.headlineView = headlineLabel

        let bodyLabel = UILabel()
        bodyLabel.translatesAutoresizingMaskIntoConstraints = false
        bodyLabel.font = .systemFont(ofSize: 13)
        bodyLabel.numberOfLines = 0
        bodyLabel.textColor = .secondaryLabel
        bodyLabel.text = nativeAd.body
        bodyLabel.isHidden = (nativeAd.body?.isEmpty ?? true)
        nativeAdView.addSubview(bodyLabel)
        nativeAdView.bodyView = bodyLabel

        // MediaView sizing: respect the creative's aspect ratio, but enforce
        // AdMob's 120pt minimum so the "MediaView is too small for video"
        // warning is cleared. A `lessThanOrEqualTo` ceiling keeps very-tall
        // creatives from dominating the feed.
        let aspectRatio = nativeAd.mediaContent.aspectRatio > 0
            ? nativeAd.mediaContent.aspectRatio
            : 1
        let aspectHeightConstraint = mediaView.heightAnchor.constraint(
            equalTo: mediaView.widthAnchor,
            multiplier: 1 / CGFloat(aspectRatio)
        )
        // Allow auto-layout to relax the aspect ratio if it conflicts with
        // the min/max height bounds.
        aspectHeightConstraint.priority = .defaultHigh

        NSLayoutConstraint.activate([
            sponsoredLabel.topAnchor.constraint(equalTo: nativeAdView.topAnchor, constant: 12),
            sponsoredLabel.leadingAnchor.constraint(equalTo: nativeAdView.leadingAnchor, constant: 12),
            sponsoredLabel.trailingAnchor.constraint(lessThanOrEqualTo: adChoicesView.leadingAnchor, constant: -8),

            adChoicesView.topAnchor.constraint(equalTo: nativeAdView.topAnchor, constant: 8),
            adChoicesView.trailingAnchor.constraint(equalTo: nativeAdView.trailingAnchor, constant: -8),
            adChoicesView.widthAnchor.constraint(lessThanOrEqualToConstant: 15),
            adChoicesView.heightAnchor.constraint(lessThanOrEqualToConstant: 15),

            mediaView.topAnchor.constraint(equalTo: sponsoredLabel.bottomAnchor, constant: 8),
            mediaView.leadingAnchor.constraint(equalTo: nativeAdView.leadingAnchor, constant: 12),
            mediaView.trailingAnchor.constraint(equalTo: nativeAdView.trailingAnchor, constant: -12),
            aspectHeightConstraint,
            mediaView.heightAnchor.constraint(greaterThanOrEqualToConstant: 120),
            mediaView.heightAnchor.constraint(lessThanOrEqualToConstant: 240),

            headlineLabel.topAnchor.constraint(equalTo: mediaView.bottomAnchor, constant: 10),
            headlineLabel.leadingAnchor.constraint(equalTo: nativeAdView.leadingAnchor, constant: 12),
            headlineLabel.trailingAnchor.constraint(equalTo: nativeAdView.trailingAnchor, constant: -12),

            bodyLabel.topAnchor.constraint(equalTo: headlineLabel.bottomAnchor, constant: 6),
            bodyLabel.leadingAnchor.constraint(equalTo: nativeAdView.leadingAnchor, constant: 12),
            bodyLabel.trailingAnchor.constraint(equalTo: nativeAdView.trailingAnchor, constant: -12),
            bodyLabel.bottomAnchor.constraint(lessThanOrEqualTo: nativeAdView.bottomAnchor, constant: -12),
        ])

        headlineLabel.setContentCompressionResistancePriority(.required, for: .vertical)
        bodyLabel.setContentCompressionResistancePriority(.required, for: .vertical)

        // Wire tracking last: delegate before `nativeAd` assignment so the
        // impression callback that fires on view-attachment isn't missed.
        // Assigning `nativeAd` arms AdMob's click tracking on the registered
        // subviews.
        nativeAd.delegate = delegateBridge
        nativeAdView.nativeAd = nativeAd

        return nativeAdView
    }
}
#endif
