# Growl iOS Mediation Adapters

First-party mediation adapters for the [Growl iOS SDK](https://github.com/growlads/growl-ios-sdk).

Each adapter wraps a third-party ad network SDK and conforms to the
`AdNetworkAdapter` contract from `GrowlAds`. Adapters participate in
Growl's parallel first-price auction.

## Available adapters

| Adapter | Module | Network | README |
| --- | --- | --- | --- |
| AdMob | `GrowlAdsMediationAdMob` | GoogleMobileAds 11.x | [Sources/GrowlAdsMediationAdMob/README.md](Sources/GrowlAdsMediationAdMob/README.md) |

## Integration

Add this repo as a SwiftPM dependency alongside `growl-ios-sdk`:

```swift
dependencies: [
    .package(url: "https://github.com/growlads/growl-ios-sdk", from: "0.0.1"),
    .package(url: "https://github.com/growlads/elo-ios-mediation", from: "0.0.1"),
],
targets: [
    .target(
        name: "MyApp",
        dependencies: [
            .product(name: "GrowlAds", package: "growl-ios-sdk"),
            .product(name: "GrowlAdsMediationAdMob", package: "elo-ios-mediation"),
        ]
    ),
],
```

Then register the adapter at app startup. See the per-adapter README for details.

## Compatibility matrix

| `elo-ios-mediation` | `GrowlAdsMediationAdMob` runtime | `GoogleMobileAds` | `GrowlAds` core |
| --- | --- | --- | --- |
| 0.0.1 | 11.10.0.0 | 11.10.0+ | 0.0.1+ |

`GrowlAdsMediationAdMob` runtime version is exposed at runtime as
`AdMobAdapter.version` (added in a follow-up task). Bumped per-adapter on each
behavioral change, independent of the repo tag.

## Authoring a new adapter

See [ADAPTER_AUTHOR_GUIDE.md](ADAPTER_AUTHOR_GUIDE.md).

## License

MIT. See [LICENSE](LICENSE).
