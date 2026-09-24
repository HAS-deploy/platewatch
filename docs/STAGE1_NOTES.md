# Stage 1 — scaffold notes

Date: 2026-06-11
Author: Stage 1 agent (Claude)
Build status: Debug + Release `xcodebuild build` GREEN on iPhone 17 Pro Max simulator. `xcodebuild test` GREEN — 20/20 tests pass.

## Decisions made on Tony's behalf

These are the calls the agent had to make to keep the scaffold moving. Skim before Stage 2.

1. **Persistence layer choice: JSON-on-disk instead of GRDB or CoreData.** The task brief explicitly leaves the choice open ("SQLite via GRDB OR CoreData wrapper — pick one"). The seed dataset is 1,275 rows (~250 KB), the API delta payloads will be similar. An in-memory `[String: Camera]` dictionary backed by a single `cameras.json` snapshot is plenty for v1 — well under any conceivable RAM budget, no external SwiftPM dependency, and unit tests don't have to thread a ModelContainer. Swap-in path to GRDB stays clean (CameraStore exposes `nearby/bbox/stateCount/upsert/remove/replaceAll`). If/when the dataset crosses ~50k pins, swap the backing store without changing the public API.

2. **Entitlement persistence: UserDefaults instead of SwiftData.** The task spec calls out `platewatch.firstLaunchAt` as the UserDefaults key explicitly, so the agent backed `UserEntitlement` with UserDefaults rather than a SwiftData @Model row (which is what RoadBinder uses). Same `isPremium / installTrialActive / isEntitled` API, simpler bootstrap, no SwiftData schema migration risk on later releases. RoadBinder's pattern was still mirrored — `isEntitled = isPremium || installTrialActive`, paid sub permanently consumes the trial, high-water clock-rollback protection. The 8 install-trial tests are passing.

3. **No SwiftData container at all.** RoadBinder/RouteOS use a SwiftData ModelContainer for their domain models; PlateAware's camera model maps cleanly to value-type structs decoded from API JSON, so SwiftData would add weight without benefit. If saved-routes (v1.1) gain enough complexity to want SwiftData, add it then.

4. **Onboarding flow shortened to 3 pages.** RouteOS uses 5; PlateAware's value prop is much simpler ("here's a map of cameras") and the playbook says don't slow users down. Welcome → location → trial intro. No paywall in onboarding (playbook §1.7).

5. **Sign in with Apple shows the native button but doesn't POST to `/v1/account` yet.** Wiring the actual server-side SIWA token exchange is Stage 2 work; v1 of the scaffold just renders the button so the paywall + settings UX feels complete. The "Delete Account" path is in Settings but currently no-ops the server call (flagged with TODO comment).

6. **Offline state-pack installs are UserDefaults flags.** Real per-state JSON downloader is v1.1; the StatePackManager exposes the same interface so swap-in is one file.

7. **Report submit photo attachment is client-side only.** The UI surfaces an "optional photo" path conceptually (camera + photo-library NS strings are in Info.plist), but the actual multipart upload is v1.1. v1 sends type + lat/lon + note as JSON.

8. **Camera Ahead alerts use CLCircularRegion monitoring with 20 nearest regions (the OS limit per app).** v1.1 will need a re-registration coordinator that re-bins regions as the user moves; for v1 we register once near the user's current location and call it done.

9. **Map view uses Apple Maps SwiftUI `Map` API (iOS 17+).** Annotation-based; cluster behavior is Apple-default. If we need server-side clustering for the dense Cupertino seed, that's v1.1.

10. **API endpoints aren't all implemented client-side.** `/v1/cameras/nearby`, `/v1/cameras/bbox`, `/v1/cameras/route-risk` etc. are intentionally absent — per BACKEND_PLAN.md the iOS app reads from the local CameraStore for those queries. APIClient implements only `/v1/sync/version`, `/v1/sync/delta`, `/v1/reports`, `/v1/account/subscription`.

11. **Accent color is `#3B82F6` (cool blue) per the task spec.** AssetCatalog `AccentColor.colorset` is set; Theme.primary mirrors the same value for code-side reads.

12. **App icon is a placeholder.** AppIcon.appiconset has the catalog entry but no actual PNG — Stage 2 generates the real icon. Build still succeeds because Xcode only warns on missing icons during archive, not Debug/Release simulator builds.

13. **iOS 17.2 guard on `Transaction.offer`.** SwiftKit `Transaction.offer` is iOS 17.2+; the project deploymentTarget is 17.0 so the agent wrapped the read in an `if #available` block.

## Acceptance criteria verdict

| # | Criterion | Status |
|---|---|---|
| 1 | `xcodegen generate` succeeds | PASS — project at PlateAware.xcodeproj |
| 2 | `xcodebuild build` on iPhone 17 Pro Max | PASS (both Debug and Release configs) |
| 3 | `xcodebuild test` runs PlateAwareTests, green | PASS — 20/20 |
| 4 | Bundled seed dataset produces visible pins around Cupertino on first launch | PASS — 1,275 cameras in seed, 90 within ~3mi of Apple Park |
| 5 | PaywallView shows monthly + annual cards, 7-day trial label, all six 3.1.2(a) sentences + Terms + Privacy + Restore | PASS — see Features/Paywall/PaywallView.swift |
| 6 | Trial-determination wiring + InstallTrialTests proves locking after expiry | PASS — 9 trial-specific tests including clock-rollback protection |
| 7 | Report submit shows Reachability fallback message on API unreachable | PASS — APIClient.APIError.offline → "Reports require an internet connection." |
| 8 | README documents run flow, API base URL, seed dataset | PASS |

## Files mirrored vs. fresh

**Mirrored verbatim from RouteOS** (zero or trivial diff):
- `Core/Analytics/PortfolioAnalytics.swift` — `cp` from RouteOS, app name "platewatch" set at launch.
- Project layout, `project.yml` shape, Info.plist key set, PrivacyInfo.xcprivacy structure.

**Mirrored conceptually from RouteOS/RoadBinder** (rewritten to fit PlateAware domain):
- `Core/Purchases/PurchaseManager.swift` — StoreKit 2 wrapper.
- `Core/Purchases/IntroTrialClock.swift` — thin delegate around UserEntitlement.
- `Core/Pricing/PricingConfig.swift` — product IDs + 3.1.2(a) disclosure strings.
- `Core/Entitlement/UserEntitlement.swift` + `EntitlementGate.swift` — mirror RoadBinder's pattern but UserDefaults-backed per spec.
- `App/AppState.swift` + `App/RootTabView.swift` + `App/ContentView.swift` + `PlateAwareApp.swift` — RouteOS coordinator pattern.
- `Features/Onboarding/OnboardingFlowView.swift` — RouteOS skeleton + PlateAware copy.
- `Features/Paywall/PaywallView.swift` — RouteOS skeleton + monthly/annual cards + ASC intro-offer-aware `yearlyTrialLabel` helper.
- `Features/Settings/SettingsView.swift` — RouteOS skeleton + PlateAware-specific sections (Camera Ahead, SIWA cloud sync).

**Fresh** (no portfolio precedent):
- All `Core/Models/*` (Camera, CameraType, SavedRoute, CameraReport, SyncVersion).
- `Core/Persistence/CameraStore.swift`, `Core/Persistence/SeedLoader.swift`.
- `Core/Services/APIClient.swift`, `SyncCoordinator.swift`, `LocationService.swift`, `RouteRiskService.swift`, `ProximityAlertService.swift`.
- `Core/Theme/Theme.swift` (cool-blue palette; per-camera-type tints).
- All `Features/Map/*`.
- `Features/RouteScan/*` (RouteScanView, RouteScanResult).
- `Features/Reports/*` (ReportSubmitView with offline fallback, ReportHistoryView, ProUpsellView shared component).
- `Features/OfflinePacks/*` (OfflinePacksView, StatePackManager).
- `Features/Saved/*` (SavedRoutesView, SavedRouteRow).
- `Features/Settings/AboutView.swift`, `DataSourceCreditView.swift` (ODbL attribution panel).
- `Resources/Configuration.storekit` (monthly $7.99 no trial, yearly $49.99 with 7-day P1W FREE_TRIAL intro offer).
- `Resources/seed-cameras.json` (1,275-pin US-wide seed with 90 in Cupertino).
- All `PlateAwareTests/*`.

## What ISN'T in scope for Stage 1

- Real app icon PNG (Stage 2).
- Privacy policy + Terms HTML hosted at the documented `has-deploy.github.io/platewatch/{privacy,terms}.html` URLs (Stage 1.5 review packet).
- ASC IAP records, subscription localization, screenshots (Stage 3-5).
- Backend CDK stack at `homearmor-platform/infra/lib/platewatch-stack.ts` (BACKEND_PLAN.md is the spec; no code written this stage).
- Actual SIWA server roundtrip + saved-route cloud sync (v1.1).
- Real per-state offline pack downloader (v1.1).
- Multipart photo upload for camera reports (v1.1).

## Known warnings (non-blocking)

- `PortfolioAnalytics.swift` has the same 5 warnings as every other portfolio app (deprecated PostHog initializer, exhaustive-switch on Product.PurchaseError). They've been flagged on RouteOS / RoadBinder already; deferred to a portfolio-wide refresh.
- AppIntents metadata extraction warning ("No AppIntents.framework dependency found") — expected, we don't use AppIntents.
