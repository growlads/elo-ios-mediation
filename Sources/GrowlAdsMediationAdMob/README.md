# Growl AdMob Mediation Adapter

`GrowlAdsMediationAdMob` adds Google AdMob native demand to the Growl iOS SDK's client-side mediation auction.

## Scope

- Native ads only
- iOS only
- Built on top of `GoogleMobileAds`

Banner, interstitial, rewarded, and rewarded interstitial support are not part
of this adapter today because Growl's current mediation UI surface is
native-only.

## Rendering Model

AdMob creatives are rendered by the adapter itself using `GADNativeAdView`,
not by Growl's generic SwiftUI ad card. At bid time the adapter attaches an
`AdRenderer` to the returned `GrowlAd`; `GrowlAdView` detects that renderer and
embeds the AdMob-owned `UIView` directly.

This is required because AdMob only counts impressions and clicks for native
ads displayed inside a registered `GADNativeAdView`.

Implications for host apps:

- Do not wrap `GrowlAdView` in your own tap handler when targeting AdMob.
- Ensure `GADApplicationIdentifier` is present before startup.
- Expect the adapter-owned native layout to control AdMob presentation and
  tracking behavior.

## Installation

Add both products to your app target:

```swift
.product(name: "GrowlAds", package: "GrowlAds"),
.product(name: "GrowlAdsMediationAdMob", package: "GrowlAds"),
```

## Required App Configuration

Set the AdMob application ID in your app's `Info.plist`:

```xml
<key>GADApplicationIdentifier</key>
<string>ca-app-pub-XXXXXXXXXXXXXXXX~YYYYYYYYYY</string>
```

Without this key, the Google Mobile Ads SDK fails during startup.

## Example Setup

```swift
import GrowlAds
import GrowlAdsMediationAdMob

Growl.configure(
    with: .init(
        publisherId: "YOUR_GROWL_PUBLISHER_ID",
        adUnitId: "YOUR_GROWL_AD_UNIT_ID",
        adapters: [
            AdMobNetworkAdapter(
                adUnitId: "ca-app-pub-XXXXXXXXXXXXXXXX/ZZZZZZZZZZ",
                assumedECpm: 2.0,
                rootViewController: { @MainActor in
                    UIApplication.shared.connectedScenes
                        .compactMap { $0 as? UIWindowScene }
                        .flatMap(\.windows)
                        .first(where: \.isKeyWindow)?
                        .rootViewController
                }
            )
        ]
    )
)
```

## Test IDs

Google's public iOS test IDs are useful for local verification:

- Test app ID: `ca-app-pub-3940256099942544~1458002511`
- Test native ad unit: `ca-app-pub-3940256099942544/3986624511`

Use these only for development and testing.

## Consent Forwarding

The adapter forwards the per-request `AdConsent` snapshot into the Google Mobile Ads request configuration for:

- COPPA via `tagForChildDirectedTreatment`
- TFUA via `tagForUnderAgeOfConsent`

Signals such as TCF strings, GPP strings, and UMP-managed consent flows still need to be handled by the host app / CMP where Google expects them.

## Version Compatibility

This adapter is currently verified against:

- `GoogleMobileAds` 11.x

If you upgrade the Google SDK major version, rebuild the example app and rerun package tests before shipping.

## Troubleshooting

If AdMob does not participate in auctions:

1. Verify `GADApplicationIdentifier` is present in `Info.plist`.
2. Verify the app links `GrowlAdsMediationAdMob`.
3. Verify the app is using a native AdMob ad unit, not a banner unit.
4. Verify the request is using a test ad unit or a configured test device.
5. Inspect `Growl.mediationDebugSnapshot()` or the example app's mediation debug panel to distinguish:
   - adapter startup failure
   - timeout
   - explicit no-fill
   - creative rejection
