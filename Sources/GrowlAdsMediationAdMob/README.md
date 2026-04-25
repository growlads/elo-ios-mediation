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

AdMob only counts impressions and clicks for native ads displayed inside a
registered `GADNativeAdView`. The adapter therefore always attaches an
`AdRenderer` that embeds `GADNativeAdView` (AdMob-owned MediaView + headline
+ body) inside `GrowlAdView`, so every successful AdMob fill is billable.

`GrowlBadgeAdView` and `GrowlChatAdView` draw Growl's SwiftUI card layout
and do not honor the renderer. They are safe surfaces for Growl-sourced
creatives but **must not** be used for AdMob bids — showing the same
`GADNativeAd` in non-registered views breaks tracking and violates AdMob
policy. Branch on `ad.requiresCustomRendering` in host code to choose
which surfaces to present:

```swift
GrowlAdView(ad: ad)

if !ad.requiresCustomRendering {
    GrowlBadgeAdView(ad: ad)
    GrowlChatAdView(ad: ad)
}
```

Implications for host apps:

- Do not wrap `GrowlAdView` in your own tap handler when the ad requires
  custom rendering; AdMob owns click attribution.
- Ensure `GADApplicationIdentifier` is present before startup.
- Expect the AdMob-owned native layout (taller than Growl's compact card) to
  control presentation for AdMob fills.
- Display a single `GrowlAdView` per auction result; a `GADNativeAd` can
  only be registered against one `GADNativeAdView` at a time.

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
                priceTiers: [
                    AdMobPriceTier(adUnitId: "ca-app-pub-XXXXXXXXXXXXXXXX/HIGH",  eCpm: 5.00),
                    AdMobPriceTier(adUnitId: "ca-app-pub-XXXXXXXXXXXXXXXX/MID",   eCpm: 2.00),
                    AdMobPriceTier(adUnitId: "ca-app-pub-XXXXXXXXXXXXXXXX/FLOOR", eCpm: 0.50),
                ],
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

### Price tiers

`GADNativeAd` does not expose a programmatic bid price. To make AdMob fills
compete fairly in Growl's auction, configure AdMob ad units at fixed eCPM
floors in the AdMob console (e.g. `$5`, `$2`, `$0.50`) and pass them as
`priceTiers` ordered highest-first.

The adapter loads tiers sequentially. The first tier that fills wins, and that
tier's `eCpm` is the bid value reported to the mediator. *Which tier fills* is
driven by AdMob's actual demand at each floor — high-eCPM tiers no-fill more
often than low-eCPM tiers, so the waterfall naturally finds the best
real-world price.

A single-tier setup (one ad unit) is fine for getting started; add more tiers
once you have AdMob historical eCPM data to set realistic floors.

## Test IDs

Google's public iOS test IDs are useful for local verification:

- Test app ID: `ca-app-pub-3940256099942544~1458002511`
- Test native ad unit: `ca-app-pub-3940256099942544/3986624511`

Use these only for development and testing.

## Consent Forwarding

The adapter forwards the per-request `AdConsent` snapshot into the Google Mobile Ads request configuration for:

- COPPA via `tagForChildDirectedTreatment`
- TFUA via `tagForUnderAgeOfConsent`

These two flags are everything the Google Mobile Ads SDK accepts directly on
`GADRequestConfiguration`. The remaining consent signals are **not** carried
through this adapter and are the host app's responsibility:

- **TCF v2 (IAB)** — `tcfString` / `addtlConsent` must be written to
  `NSUserDefaults` under the standard IAB keys (`IABTCF_*`) by your CMP.
  Google's SDK reads them from there directly.
- **GPP (Global Privacy Platform)** — `gppString` / `gppSid` must likewise be
  written to `NSUserDefaults` under `IABGPP_*` keys by your CMP.
- **Google UMP** (`GoogleUserMessagingPlatform`) — if you use Google's own CMP,
  present its form before calling `Growl.configure(with:)` so `gppString` and
  `tcfString` are in place before the first auction.

If any of those signals are required for a given region, the `AdMobNetworkAdapter`
will still bid — but the resulting request may be treated as non-personalized
by AdMob. Surface this through your app's CMP, not through `AdConsent`.

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
