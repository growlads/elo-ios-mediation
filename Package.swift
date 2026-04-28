// swift-tools-version: 5.9
import PackageDescription

let strictConcurrency: [SwiftSetting] = [
    .enableExperimentalFeature("StrictConcurrency"),
]

let package = Package(
    name: "GrowlAdsMediation",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v16),
    ],
    products: [
        .library(name: "GrowlAdsMediationAdMob", targets: ["GrowlAdsMediationAdMob"]),
    ],
    dependencies: [
        .package(
            url: "https://github.com/growlads/growl-ios-sdk.git",
            from: "0.0.1"
        ),
        .package(
            url: "https://github.com/googleads/swift-package-manager-google-mobile-ads.git",
            from: "11.10.0"
        ),
    ],
    targets: [
        .target(
            name: "GrowlAdsMediationAdMob",
            dependencies: [
                .product(name: "GrowlAds", package: "growl-ios-sdk"),
                .product(
                    name: "GoogleMobileAds",
                    package: "swift-package-manager-google-mobile-ads"
                ),
            ],
            path: "Sources/GrowlAdsMediationAdMob",
            exclude: ["README.md", "CHANGELOG.md", "Resources/UPDATING.md"],
            resources: [.process("Resources/AdMobSKAdNetworkItems.plist")],
            swiftSettings: strictConcurrency
        ),
        .target(
            name: "MediationTestKit",
            dependencies: [
                .product(name: "GrowlAds", package: "growl-ios-sdk"),
            ],
            path: "Tests/MediationTestKit",
            swiftSettings: strictConcurrency
        ),
        .testTarget(
            name: "GrowlAdsMediationAdMobTests",
            dependencies: ["GrowlAdsMediationAdMob", "MediationTestKit"],
            path: "Tests/GrowlAdsMediationAdMobTests"
        ),
    ]
)
