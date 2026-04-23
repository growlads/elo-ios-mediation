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

        let headlineLabel = UILabel()
        headlineLabel.translatesAutoresizingMaskIntoConstraints = false
        headlineLabel.font = .systemFont(ofSize: 15, weight: .bold)
        headlineLabel.numberOfLines = 0
        headlineLabel.text = nativeAd.headline
        nativeAdView.addSubview(headlineLabel)
        nativeAdView.headlineView = headlineLabel

        let bodyLabel = UILabel()
        bodyLabel.translatesAutoresizingMaskIntoConstraints = false
        bodyLabel.font = .systemFont(ofSize: 12)
        bodyLabel.numberOfLines = 0
        bodyLabel.textColor = .secondaryLabel
        bodyLabel.text = nativeAd.body
        bodyLabel.isHidden = nativeAd.body == nil
        nativeAdView.addSubview(bodyLabel)
        nativeAdView.bodyView = bodyLabel

        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = 6
        imageView.image = nativeAd.images?.first?.image
        imageView.isHidden = nativeAd.images?.first?.image == nil
        nativeAdView.addSubview(imageView)
        nativeAdView.imageView = imageView

        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: nativeAdView.topAnchor, constant: 12),
            imageView.leadingAnchor.constraint(equalTo: nativeAdView.leadingAnchor, constant: 12),
            imageView.widthAnchor.constraint(equalToConstant: 72),
            imageView.heightAnchor.constraint(equalToConstant: 72),

            headlineLabel.topAnchor.constraint(equalTo: nativeAdView.topAnchor, constant: 12),
            headlineLabel.leadingAnchor.constraint(
                equalTo: imageView.image == nil ? nativeAdView.leadingAnchor : imageView.trailingAnchor,
                constant: 12
            ),
            headlineLabel.trailingAnchor.constraint(equalTo: nativeAdView.trailingAnchor, constant: -12),

            bodyLabel.topAnchor.constraint(equalTo: headlineLabel.bottomAnchor, constant: 4),
            bodyLabel.leadingAnchor.constraint(equalTo: headlineLabel.leadingAnchor),
            bodyLabel.trailingAnchor.constraint(equalTo: headlineLabel.trailingAnchor),
            bodyLabel.bottomAnchor.constraint(lessThanOrEqualTo: nativeAdView.bottomAnchor, constant: -12),

            nativeAdView.heightAnchor.constraint(greaterThanOrEqualToConstant: 96),
        ])

        nativeAd.delegate = delegateBridge
        nativeAdView.nativeAd = nativeAd

        return nativeAdView
    }
}
#endif
