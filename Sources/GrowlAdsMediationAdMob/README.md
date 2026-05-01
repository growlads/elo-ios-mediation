# GrowlAdsMediationAdMob

AdMob mediation adapter for the Elo iOS SDK. Wraps `GoogleMobileAds`
11.x and exposes it through Elo's `AdNetworkAdapter` contract.

**Runtime version:** `AdMobAdapter.version` — currently `11.10.0.0`.
(The runtime constant is added in a follow-up task. Until then, treat
the version above as the documented value.)

## Integration

```swift
import GrowlAds
import GrowlAdsMediationAdMob

let adapter = AdMobNetworkAdapter(/* config */)
GrowlAdsClient.shared.register(adapter: adapter)
```

## Resources

This adapter ships an `AdMobSKAdNetworkItems.plist` with the AdMob
SKAdNetwork IDs. Merge into your app's `Info.plist` `SKAdNetworkItems`
key. See [Resources/UPDATING.md](Resources/UPDATING.md) for refresh
instructions when AdMob publishes new IDs.

## Consent forwarding

`AdMobConsent` derives the AdMob `npa` (non-personalized ads) parameter
from the per-request `AdConsent`. No global CMP state is read.

## Changelog

See [CHANGELOG.md](CHANGELOG.md).
