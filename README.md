# PlateAware — iOS app

Stage 1 scaffold of the PlateAware iOS app. Status, intent, and risk profile
live under `docs/`.

## Quick run

```bash
brew install xcodegen          # one-time, if missing
cd ~/Developer/platewatch
xcodegen generate              # writes PlateAware.xcodeproj
open PlateAware.xcodeproj
```

Run on iPhone 17 Pro Max (or any iOS 17+ simulator).

From CLI:

```bash
xcodebuild -project PlateAware.xcodeproj \
  -scheme PlateAware \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' \
  build

xcodebuild -project PlateAware.xcodeproj \
  -scheme PlateAware \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' \
  test
```

## Where the API base URL is set

`Info.plist → APIBaseURL` (`PlateAware/Resources/Info.plist`). Default is
`https://api.plateaware.app`. To point at a local dev server, edit that key
or override it via `xcrun simctl spawn booted launchctl setenv APIBaseURL …`.

The iOS app **never hits the API for nearby/bbox queries** — it reads from
the local cache. The API only carries `/v1/sync/version`, `/v1/sync/delta`,
`/v1/reports`, and `/v1/account/subscription`.

## Seed dataset for offline dev

`PlateAware/Resources/seed-cameras.json` ships in the IPA. On first launch
the `SeedLoader` populates an empty `CameraStore` from this file so the
map renders pins without any network call. Coverage: ~1,275 pins across
Cupertino, SF, San Jose, LA, NYC, Austin, Houston, Dallas, Chicago,
Seattle, Miami, Phoenix, Denver, Atlanta, Boston, DC, Philadelphia,
Detroit, Las Vegas, Portland. Apple Park (37.3349, -122.0090) has ~90
pins within a few miles for the reviewer's first launch.

To rebuild the seed dataset later, see the Python generator embedded in
the Stage 1 PR transcript (`scripts/gen_seed.py` is on the v1.1 backlog).

## Install-trial pattern (mirrors RoadBinder)

`Core/Entitlement/UserEntitlement.swift` + `Core/Entitlement/EntitlementGate.swift`
mirror RoadBinder's pattern but use UserDefaults instead of SwiftData. The
canonical key is `platewatch.firstLaunchAt`. Every gate / limit calls
`entitlement.isEntitled(now:)` — never `isPremium` directly. During the
7-day install trial all premium features are unlocked.

`Core/Purchases/PurchaseManager.swift` writes `entitlement.applyPaidEntitlement(...)`
when a verified StoreKit transaction lands; a paid sub permanently consumes
the trial (`installTrialConsumed = true`) so a refund + clock backdate can't
reopen the window.

## Analytics

`Core/Analytics/PortfolioAnalytics.swift` is the canonical drop-in from
`~/Developer/app-factory/swift/PortfolioAnalytics.swift`. App start calls
`PortfolioAnalytics.shared.start(appName: "platewatch")` from
`PlateAwareApp.init`. Every `paywall.purchase_failed` event flows through
`PurchaseManager.trackPaywallFailure(...)` so the `reason` property is
always populated (memory `feedback_portfolio_analytics_must_fix`).

## Permissions

All NS\*UsageDescription requests are JIT — none fire at launch.

- WhenInUse location: requested when the user taps "Allow While Using" on
  the onboarding location step OR taps the Center-on-me button on the map.
- Always location: requested ONLY when the user toggles on Camera Ahead
  alerts in Settings (premium-only).
- Camera / Photos: only when the user taps "Add Photo" inside the Report
  Submit form.

## What's intentionally stubbed in this scaffold

- Sign in with Apple wires the button + SwiftUI flow but doesn't yet POST
  to `/v1/account` on success. v1.1.
- Offline state pack installs flip a UserDefaults flag — the actual
  downloader + per-state JSON ingest is v1.1.
- Saved-routes view shows a placeholder list. Saved-route persistence is
  v1.1.
- Report submit sends to `/v1/reports` but the optional photo attachment
  is wired only client-side (multipart upload lives in v1.1).
- The proximity-alert service uses `CLCircularRegion` monitoring; the
  20-region OS limit per app is respected by taking the nearest 20.
