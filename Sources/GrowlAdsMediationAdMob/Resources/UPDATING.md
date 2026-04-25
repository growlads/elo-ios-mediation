# Refreshing `AdMobSKAdNetworkItems.plist`

Google publishes the canonical AdMob iOS SKAdNetwork list as part of the
[iOS quick-start guide](https://developers.google.com/admob/ios/quick-start).

Refresh this file when Google updates the published list (typically once per
quarter, or whenever a new mediated network is added).

## Procedure

1. Open https://developers.google.com/admob/ios/quick-start.
2. Locate the `SKAdNetworkItems` block in the page (it appears under
   "Update your Info.plist").
3. Replace the contents of `AdMobSKAdNetworkItems.plist` with Google's
   array. The bundled file's root must be the `<array>` of `<dict>`s — no
   surrounding `SKAdNetworkItems` key, since we ship it as a standalone
   resource that the parser reads directly.
4. Run the package tests:
   ```sh
   swift test --filter AdMobNetworkAdapterTests
   ```
   The SKAN coverage test asserts the parsed list contains
   `cstr6suwn9.skadnetwork` and has more than 30 entries.
5. Commit with a `chore(admob): refresh SKAdNetwork ID list (YYYY-MM-DD)`
   message; include the source URL in the commit body.

## Why a bundled plist?

The list is inert configuration — codegen would be over-engineered for ~50
strings, and a runtime download would be a privacy footgun. A bundled plist
is the right shape: one file, one source of truth, refreshable without code
changes.

The `Package.swift` resource declaration uses `.process(...)` so SwiftPM
copies the plist into the module bundle; `AdMobSKAdNetworkIDs.shared` reads
it from `Bundle.module` at first access.
