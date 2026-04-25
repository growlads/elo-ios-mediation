# Growl Mediation Adapter Author Guide

This guide describes the v1 contract for building a client-side mediation adapter for `GrowlIosSdk`.

## Scope

- Adapters participate in Growl's built-in parallel first-price auction.
- The SDK chooses the mediator implementation internally. Publishers register adapters, but they do not swap in custom waterfall or hybrid mediators in v1.
- v1 is native-format only. Format-specific adapters can be added later without changing the core auction contract.

## Adapter checklist

1. Conform to `AdNetworkAdapter`.
2. Expose a stable `networkId`.
3. Implement `start()` if your SDK needs one-time initialization.
4. Implement `bid(_:)` and return:
   - `AdBid` when you have a creative and a price.
   - `nil` for no-fill.
   - `throw AdAdapterError` when the adapter could not participate.
5. Return a `GrowlAd` whose tracker knows how to fire that network's render, impression, and click telemetry.

## Lifecycle

The mediator calls `start()` once before the adapter joins its first auction. Use it for SDK-level startup such as `MobileAds.start(...)`.

- Keep `start()` idempotent.
- Treat slow startup as part of the adapter's auction budget.
- Throw `AdAdapterError.notStarted` or `AdAdapterError.invalidConfiguration(...)` when the SDK cannot become ready.

Adapters that do not need explicit startup can rely on the default no-op implementation.

## Request contract

Every adapter receives the same `AdBidRequest`:

- `messages` and `context` for Growl's contextual targeting surface.
- `adUnitId` for the publisher's Growl placement.
- `consent` as a per-request privacy snapshot.
- `timeout` as the adapter's budget within the overall auction.

Do not re-read consent from global app state inside the adapter. Use `request.consent` so all networks evaluate the same snapshot.

## Consent forwarding

`AdConsent` contains:

- `coppa`
- `tfua`
- `gdprApplies`
- `tcfString`
- `addtlConsent`
- `gppString`
- `gppSid`

Forward the fields your network SDK accepts directly. If a network needs a host-side CMP or its own consent API for some signals, document that clearly in the adapter README.

## Error taxonomy

Use `AdAdapterError` for failures that are not no-fill:

- `notStarted`
- `invalidConfiguration(String)`
- `invalidRequest(String)`
- `network(String)`
- `invalidCreative(String)`
- `timeout`
- `cancelled`
- `underlying(String)`

This keeps mediator logging structured and lets future observability work build on stable categories.

## Creative mapping

Map the network-native ad object into `GrowlAd` as close to the adapter boundary as possible.

- Reject malformed creatives by returning `nil` or throwing `AdAdapterError.invalidCreative(...)`.
- Keep mapping logic isolated and testable without requiring the full third-party SDK whenever possible.
- Put network-specific tracking in the `AdTracker` implementation, not in the mediator or view layer.

## Packaging closed-source SDKs (xcframework)

Some networks ship as a closed-source `.xcframework` rather than an SPM-compatible source package. Bundle these via `binaryTarget` so the adapter remains a pure Swift target without dragging dynamic CocoaPods into the host.

```swift
// Package.swift (adapter author's package)
.binaryTarget(
    name: "VendorSDK",
    path: "Frameworks/VendorSDK.xcframework"
),
.target(
    name: "GrowlAdsMediationVendor",
    dependencies: ["GrowlCore", "VendorSDK"],
    path: "Sources/GrowlAdsMediationVendor"
),
```

Notes:

- Commit the `.xcframework` to the repo or fetch it from a stable URL via `binaryTarget(name:url:checksum:)`.
- Match the vendor's privacy manifest (`PrivacyInfo.xcprivacy`) requirements; include it as a `resources:` entry on the adapter target so App Store review picks it up.
- Forward `requiredSKAdNetworkIds` from the vendor's documented list. The startup validator will warn the publisher if the host `Info.plist` is missing entries.
- Mark the adapter's deployment target ≥ the vendor's documented minimum.

## Testing expectations

Each adapter should ship with tests for:

- `start()` behavior when the SDK is ready vs. misconfigured.
- Creative mapping.
- No-fill handling.
- Error translation into `AdAdapterError`.
- Any consent forwarding you implement directly.

The `ParallelAuctionMediator` itself owns timeout, floor, and winner-selection tests. Adapters should focus on their own edge handling and mapping decisions.
