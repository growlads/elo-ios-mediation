import Foundation
import GrowlCore

#if canImport(GoogleMobileAds) && canImport(UIKit)
import UIKit
@preconcurrency import GoogleMobileAds

/// Builds a `GADNativeAdView` and registers it for AdMob-native tracking.
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
        nativeAdView.clipsToBounds = true

        let contentView = UIView()
        contentView.translatesAutoresizingMaskIntoConstraints = false
        nativeAdView.addSubview(contentView)

        let mediaContainerView = UIView()
        mediaContainerView.translatesAutoresizingMaskIntoConstraints = false
        mediaContainerView.layer.cornerRadius = 6
        mediaContainerView.clipsToBounds = true
        contentView.addSubview(mediaContainerView)

        let mediaView = GADMediaView()
        mediaView.translatesAutoresizingMaskIntoConstraints = false
        mediaView.contentMode = .scaleAspectFill
        mediaView.isHidden = nativeAd.mediaContent.hasVideoContent == false && nativeAd.images?.first == nil
        mediaContainerView.isHidden = mediaView.isHidden
        mediaContainerView.addSubview(mediaView)
        nativeAdView.mediaView = mediaView

        let headlineLabel = UILabel()
        headlineLabel.translatesAutoresizingMaskIntoConstraints = false
        headlineLabel.font = .systemFont(ofSize: 15, weight: .bold)
        headlineLabel.numberOfLines = 0
        headlineLabel.text = nativeAd.headline
        contentView.addSubview(headlineLabel)
        nativeAdView.headlineView = headlineLabel

        let bodyLabel = UILabel()
        bodyLabel.translatesAutoresizingMaskIntoConstraints = false
        bodyLabel.font = .systemFont(ofSize: 12)
        bodyLabel.numberOfLines = 0
        bodyLabel.textColor = .secondaryLabel
        bodyLabel.text = nativeAd.body
        bodyLabel.isHidden = nativeAd.body == nil
        contentView.addSubview(bodyLabel)
        nativeAdView.bodyView = bodyLabel

        NSLayoutConstraint.activate([
            contentView.topAnchor.constraint(equalTo: nativeAdView.topAnchor, constant: 12),
            contentView.leadingAnchor.constraint(equalTo: nativeAdView.leadingAnchor, constant: 12),
            contentView.trailingAnchor.constraint(equalTo: nativeAdView.trailingAnchor, constant: -12),
            contentView.bottomAnchor.constraint(equalTo: nativeAdView.bottomAnchor, constant: -12),

            mediaContainerView.topAnchor.constraint(equalTo: contentView.topAnchor),
            mediaContainerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            mediaContainerView.widthAnchor.constraint(equalToConstant: 72),
            mediaContainerView.heightAnchor.constraint(equalToConstant: 72),

            mediaView.topAnchor.constraint(equalTo: mediaContainerView.topAnchor),
            mediaView.leadingAnchor.constraint(equalTo: mediaContainerView.leadingAnchor),
            mediaView.trailingAnchor.constraint(equalTo: mediaContainerView.trailingAnchor),
            mediaView.bottomAnchor.constraint(equalTo: mediaContainerView.bottomAnchor),

            headlineLabel.topAnchor.constraint(equalTo: contentView.topAnchor),
            headlineLabel.leadingAnchor.constraint(
                equalTo: mediaView.isHidden ? contentView.leadingAnchor : mediaContainerView.trailingAnchor,
                constant: 12
            ),
            headlineLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),

            bodyLabel.topAnchor.constraint(equalTo: headlineLabel.bottomAnchor, constant: 4),
            bodyLabel.leadingAnchor.constraint(equalTo: headlineLabel.leadingAnchor),
            bodyLabel.trailingAnchor.constraint(equalTo: headlineLabel.trailingAnchor),
            bodyLabel.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor),

            contentView.bottomAnchor.constraint(greaterThanOrEqualTo: mediaContainerView.bottomAnchor),
            nativeAdView.heightAnchor.constraint(greaterThanOrEqualToConstant: 96),
        ])

        nativeAd.delegate = delegateBridge
        nativeAdView.nativeAd = nativeAd

        return nativeAdView
    }
}
#endif
