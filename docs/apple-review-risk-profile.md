# Apple Review Risk Profile — PlateAware

> Produced by Stage 0.5 of the app factory. This file is the single source of
> truth for every later stage. If anything changes (new payment model, new
> permissions, new third-party SDK), update this file first and re-run the
> downstream validators.

- **App name (marketing):** PlateAware
- **Bundle ID:** com.platewatch.app
- **ASC App ID:** (set after Stage 5)
- **Profile created:** 2026-06-11
- **Last updated:** 2026-06-11
- **Primary owner:** Tony McMurtrey

---

## 0. CATEGORY RISK CALLOUT — read before anything else

PlateAware sits next to a **known Apple-rejection cluster**. Camera-mapping / "police lookout" apps have been delisted in the past (Trapster shut down 2014 after sustained pressure; multiple "police lookout" apps were removed during the 2020 protest cycle; Waze's red-light-camera reporting drew formal letters from law enforcement). The category is not a banned category — Waze, Apple Maps, and Google Maps all display fixed traffic / red-light cameras today — but it is **adversarially-reviewed**. Reviewers default to suspicion. Every framing decision in this document is calibrated to that bias.

The honest read on the guideline numbers most likely to be cited against us:

- **4.2.6 — "Apps created from a commercialized template or app generation service":** not directly applicable, but the historical reviewer-extension of 4.2-family clauses against "enforcement-evasion" apps lives here. The technical reading is clear: PlateAware maps PUBLIC fixed infrastructure from PUBLIC datasets and does not detect, evade, or interfere with active enforcement. A cautious reviewer may still misread the category. **Mitigation:** every metadata surface (App Store description, screenshots, in-app copy, reviewer notes) leads with "public infrastructure transparency" framing and explicitly disclaims evasion / detection of officers / interference with enforcement.
- **4.2 — Minimum Functionality:** real risk. If the US-wide OSM seed dataset is sparse in a reviewer's simulator location (default Apple Park, Cupertino), the map will look empty and trip 4.2. **Mitigation:** Stage 1 must verify the bundled seed dataset contains thousands of pins nationwide AND verify the Cupertino / 1 Infinite Loop area has at least a handful of visible pins out of the box. Reviewer demo path explicitly points the reviewer at a known-dense region as a backup.
- **4.10 — Monetizing Built-In Capabilities:** the MapKit map itself is Apple's. We monetize OUR data layer (camera dataset, density score, route scan, offline state packs, proximity alerts), NOT the map. Free tier still shows the MapKit map and nearby camera pins with no payment wall. Premium adds VALUE THAT IS OURS, not value that Apple ships for free. This distinction must be visible in the paywall copy and the reviewer notes.
- **5.1.2 — Data Use and Sharing:** user-submitted camera reports are crowd-sourced user-generated content. We require explicit consent at report time, run every report through moderation before it becomes visible to other users, and never publish a report without a verified_status flip. This must be documented in the privacy policy and the reviewer notes.
- **3.1.2 — Auto-renewable subscriptions:** standard trial-determination model risk. Verbatim 3.1.2(a) disclosure sentences must render on the paywall (six sentences plus Privacy / Terms / Restore Purchases). Trial is 7-day P1W on the annual product only; monthly carries no trial. Install-time entitlement (`UserEntitlement` / `EntitlementGate` mirroring RoadBinder) plus the StoreKit intro offer on annual.
- **1.2 — Safety / User-Generated Content:** report flow needs the standard UGC protections — report-this-content path, block-a-reporter path, EULA prohibiting objectionable content, moderation queue. All four must exist before submission even though report volume will be near-zero at launch.
- **5.1.1(v) — Account deletion:** anonymous users get a Reset App Data path; SIWA users get an in-app Delete Account path that triggers SIWA token revocation. Both paths complete without an email round-trip.

**Stage 4A and 4D will read this section as the brief. Do not soften it later.**

### Privacy-preferring route mode (added 2026-06-11)

PlateAware ships a premium **Privacy route** mode that uses `MKDirections.calculate(requestsAlternateRoutes: true)` to fetch route alternatives between two points and scores each alternative by the number of ALPR camera intersections along its polyline (cameras within 50m). The route with the **lowest** ALPR-intersection count is highlighted as the recommended choice. The user makes the final selection — the app does not auto-route.

This is the single highest-risk feature for the 4.2.6 / enforcement-evasion misread. The mitigation is **framing discipline at every layer**:

- **User-facing copy** uses only privacy/civil-liberties language: "Privacy route", "Privacy-preferring", "Low-surveillance route", "Choose how much your plate is read". The words "avoid", "evade", "beat", "bypass", "around", "ticket", "police", "officer", "detect" MUST NOT appear in any user-facing string in the iOS app, App Store metadata, or marketing site.
- **App Store description** explicitly frames this as a civil-liberties feature: "For drivers who prefer routes with less automated plate surveillance, [PlateAware] highlights lower-surveillance alternatives among the routes Apple Maps would already suggest. PlateAware never alters where you go — only adds an information layer about which surveillance you'll pass through."
- **Reviewer notes** cite specific public-interest documentation of ALPR overreach (ACLU "You Are Being Tracked" report 2013, EFF "Street-Level Surveillance: ALPR" 2024) to ground the legitimate civil-liberties use case. The reviewer notes state explicitly: "This feature operates only on **fixed** infrastructure already mapped publicly. It does NOT identify or geolocate police, ICE officers, or any individual person. It does NOT detect active enforcement. It does NOT interfere with any camera. It is an additional **informational filter** on top of MKDirections' standard route alternatives."
- **MapKit is doing the routing.** PlateAware does not implement custom navigation, does not modify routes, and does not bypass any Apple framework. It scores alternatives that Apple already returns. This keeps the 4.10 line clean.
- **Premium-gated and consent-based.** The user must explicitly tap "Privacy route" to score routes by ALPR density — it is not the default behavior. Free tier users see the standard fastest route only.

The single biggest residual risk: a reviewer reading "avoid LPR cameras" in a marketing email / press summary and assuming the iOS app implements enforcement evasion. Pre-empt by including a paragraph in `app-review-notes.md` (Stage 7) that names this feature explicitly and points to the civil-liberties framing.

---

## 1. App purpose (one sentence)

PlateAware is a public-roadway infrastructure transparency map that shows where fixed ALPR cameras, red-light cameras, traffic cameras, toll readers, and school zones already exist on public roads, using the DeFlock community map (built on OpenStreetMap) and other open public datasets.

> Must be accurate, concrete, and match the eventual App Store description
> almost verbatim. "A calorie tracker with barcode scanning" is good. "The
> last fitness app you'll ever need" is not — it trips 2.3 (accurate
> metadata) and 4.2 (minimum functionality).

## 2. Account / login model

- [x] **Optional login** (guest + signed-in) — reviewer exercises guest path; demo creds provided for signed-in path
- [ ] **No accounts, no login** — nothing to provision for reviewer
- [ ] **Required login** — MUST provide working demo credentials (Stage 5)
- [x] **Sign in with Apple required?** Sign in with Apple parity rule (4.8) trivially satisfied — SIWA is the ONLY login option offered. No Google / Facebook / OAuth alternatives v1.

Login providers in use: Anonymous device-id default for the free tier; optional Sign in with Apple for cloud-sync of saved routes (premium-only sync). No third-party login providers v1. Sign in with Apple parity rule (4.8) trivially satisfied since SIWA is the only login option.

Demo creds stored at: `docs/reviewer-demo-credentials.md` (reviewer can exercise the entire primary review path WITHOUT logging in; SIWA demo credentials are provided only as a fallback for reviewers who insist on testing the saved-routes sync path).

## 3. Payment model

Pick exactly one primary classification:

- [x] **Free + auto-renewable subscription** → triggers **3.1.2 HARD disclosures** (Stage 4C + paywall gate)
- [ ] **Free, no payments anywhere** — cleanest path
- [ ] **Free + non-consumable IAP** (lifetime unlock)
- [ ] **Free + consumable IAP** (credits / packs)
- [ ] **Free + subscription + lifetime** (mixed)
- [ ] **Paid up-front** (just price tier, no IAP)
- [ ] **External Stripe / web checkout** — ONLY valid if selling physical goods or a real-world service outside the app (**3.1.3**); digital goods consumed in-app MUST use IAP (**3.1.1**)
- [ ] **SaaS with external sign-up** — reader-app exception (**3.1.3(a)**) may apply; user must be able to sign up / pay outside the app

Payment model in use: Auto-renewable subscription via Apple StoreKit 2. Trial-determination model per Subscriptions playbook §1.5: **monthly $7.99 (no trial)** + **annual $49.99 with 7-day free trial (P1W)**. Trial duration is 7-day because PlateAware is a daily-use driver-aid app — drivers exercise the map on every commute, so the habit-formation window is one week (playbook Rule 2 daily-use cadence). Trial is install-time entitlement (NOT just a StoreKit intro offer) per playbook Rule 4 — mirror RoadBinder's `UserEntitlement` / `EntitlementGate` pattern with `UserDefaults` key `platewatch.firstLaunchAt`. Free tier shows nearby cameras + map + basic details. Premium adds proximity alerts, pre-drive route scan, offline state packs, density score, saved routes, faster sync. The API tier (Developer/Business/Fleet at api.platewatch.app) is sold separately via Stripe off-app and is OUT OF SCOPE for the iOS submission — it is not mentioned in any iOS metadata.

### Subscription disclosures required (only if subs) — all mandatory on the paywall

- [x] Subscription title (matches IAP name)
- [x] Subscription length (monthly / yearly / etc.)
- [x] Price per period (and price-per-unit if not obvious)
- [x] "Payment will be charged to your Apple ID account at confirmation of purchase"
- [x] "Subscription automatically renews unless canceled at least 24 hours before the end of the current period"
- [x] "Your account will be charged for renewal within 24 hours prior to the end of the current period"
- [x] "Subscriptions may be managed and auto-renewal may be turned off by going to the user's Account Settings after purchase"
- [x] "If you start a free trial, any unused portion is forfeited if you purchase a subscription before the trial ends." (Rule 3 forfeiture sentence, mandatory because trial exists)
- [x] Tappable Privacy Policy link (live URL, not mailto)
- [x] Tappable Terms of Use / EULA link (live URL)
- [x] Restore Purchases action visible

## 4. What the app sells / provides

- [x] Digital goods consumed in-app (unlock, feature, credit, content)
- [ ] Physical goods (shipped)
- [ ] Real-world service (disputes, legal, printing, delivery)
- [ ] SaaS (primarily web, iOS is a thin client)
- [ ] None (free utility)

Checked here: Digital service — premium app functionality (proximity alerts, route scan, offline packs, density score, saved-route cloud sync). No physical goods. No external SaaS is sold from the iOS app — the API tier is a separately-sold Stripe-billed product that lives off-app at api.platewatch.app and is not advertised or linked from the iOS build.

## 5. Data collected / stored / shared

Fill the table with each data type the app touches. If you can't fill this
without lying, stop and trace it from the code before continuing.

| Data type | Collected? | Stored where | Transmitted to whom | Linked to user? | Used to track? |
|---|---|---|---|---|---|
| Name | No | — | — | — | No |
| Email | Only if user signs in with SIWA (relay address stored server-side for account-deletion notifications only) | DynamoDB `PlateAwareTable` | Anthropic AWS account 139294832887, us-east-2 only | Yes (SIWA users only) | No |
| Password / auth token | SIWA token only | Keychain (client), DynamoDB (server-side hashed) | AWS only | Yes (SIWA users only) | No |
| Contacts | No | — | — | — | No |
| Location | Yes — approximate location for nearby/bbox queries (passed as request parameter, NOT stored beyond request). Precise location passed only at the user's explicit moment of submitting a camera report. Background location only if user opts into "Camera Ahead" premium alerts. | Not stored beyond request lifetime on the server. Saved routes (premium SIWA users only) are stored as user-defined waypoints, not as real-time location traces. | AWS only | Yes for saved routes (SIWA users); No for nearby/bbox queries | No |
| Photos | Optional — only if user attaches a photo to a camera report | S3 `platewatch-reports-<acct>-us-east-2` (private) | AWS only | Linked to anonymous device-id or SIWA id | No |
| Audio | No | — | — | — | No |
| Health / fitness | No | — | — | — | No |
| Financial | No (Apple handles all payment; we receive only the IAP transaction id) | — | Apple StoreKit (we do not see card data) | Yes (IAP transaction id linked to device-id or SIWA id for entitlement validation) | No |
| User-entered text / documents | Yes — user-submitted camera report free-text note and the lat/lon of the report | DynamoDB | AWS only | Linked to anonymous device-id or SIWA id | No |
| Purchase history | Yes — IAP transaction id and subscription status | DynamoDB | AWS only | Yes | No |
| Device ID / advertising ID | Anonymous device-id (UUID we generate on first launch, NOT IDFA, NOT IDFV directly — a hashed identifier kept in Keychain). NO advertising id. | Keychain (client), DynamoDB (server) | AWS only | Yes (the device-id IS the anonymous identifier) | No |
| Usage analytics | PostHog portfolio analytics (shared `phc_zsZ6K…` key) — anonymous event stream tagged with `app=platewatch`. No precise location, no PII. | PostHog US cloud | PostHog | Linked to anonymous PostHog distinct_id (the device-id) | No (PostHog is product analytics, not advertising tracking) |
| Crash logs | Apple-default crash reporting only (user opt-in at iOS level) | Apple | Apple | Per Apple's data policy | No |

Nutrition label target (what Stage 8 will click through in ASC → App Privacy):
**Data collected and linked to the user:** Anonymous device identifier (Identifiers → Device ID), IAP transaction id (Purchases → Purchase History), submitted camera reports including coarse lat/lon + optional photo + free-text note (User Content → Customer Support / Other User Content; Location → Coarse Location), saved-route waypoints if the user enables SIWA cloud sync (Location → Coarse Location), email address for SIWA users only (Contact Info → Email Address, via Apple's relay address). **Data collected but NOT linked to the user:** PostHog product-analytics events (Usage Data → Product Interaction; Diagnostics → Crash Data). **Data NOT collected:** precise location stored, advertising identifier, contact info beyond SIWA email, browsing history, search history outside of the user's own camera lookups, name, payment info (Apple handles all payment). **Data shared with third parties:** none for advertising; PostHog is the only third-party processor and acts as our analytics processor under DPA. **Used for tracking:** No.

## 6. Account deletion (5.1.1(v))

- [x] **Required** — in-app path exists at: Settings → **Delete All Data** for anonymous users (wipes the install-trial stamp, onboarding state, and local entitlement; v1 does not call the server because anonymous accounts have no persistent server row beyond the optional moderated report rows, which carry no PII). Settings → **Delete Account** for SIWA users (clears all PlateAware data on the device and opens Apple's Sign in with Apple manager at `https://appleid.apple.com/account/manage` so the user can revoke the Apple ID grant directly via Apple's UI — the honest answer per 5.1.1(v) since the `/v1/account` REST endpoint is stubbed at 501 until API v1.1 ships server-side row wipe + Apple-side token revocation). Both paths complete without an email round-trip and both are reachable in two taps from the main map view.
- [ ] **Not applicable** (no accounts)
- [x] **Required** — reviewer demo account can exercise it (reviewer can exercise the anonymous Reset App Data path with no login; a SIWA demo account is also provided for the Delete Account path).

Missing this on an accounts-based app is an instant **5.1.1(v)** rejection.

## 7. Permissions needed (`NS*UsageDescription`)

For each permission, list the `NS*UsageDescription` string planned. Strings
must be user-readable and specific to what the app actually does with the
data — "Used for photos" is a soft reject; "Scan a barcode on food
packaging to look up nutrition info" is a pass.

| Permission | NS key | Planned string |
|---|---|---|
| Camera | `NSCameraUsageDescription` | PlateAware can attach a photo to a camera report you submit. The camera is only used when you tap the Add Photo button on a report. |
| Microphone | `NSMicrophoneUsageDescription` | Not requested. |
| Photos (read) | `NSPhotoLibraryUsageDescription` | PlateAware can attach a photo from your library to a camera report you submit. We only access photos you pick. |
| Photos (add) | `NSPhotoLibraryAddUsageDescription` | Not requested. |
| Location (when-in-use) | `NSLocationWhenInUseUsageDescription` | PlateAware uses your location to center the map on roads near you and show nearby public surveillance infrastructure. Used only while the app is open. |
| Location (always) | `NSLocationAlwaysAndWhenInUseUsageDescription` | PlateAware uses your location in the background only when you've turned on Camera Ahead alerts, so we can notify you before you reach a known public camera. You can turn this off any time. |
| Contacts | `NSContactsUsageDescription` | Not requested. |
| HealthKit read | `NSHealthShareUsageDescription` | Not requested. |
| HealthKit write | `NSHealthUpdateUsageDescription` | Not requested. |
| Motion | `NSMotionUsageDescription` | Not requested. |
| Bluetooth | `NSBluetoothAlwaysUsageDescription` | Not requested. |
| ATT | `NSUserTrackingUsageDescription` | Not requested. |
| Face ID / Touch ID | `NSFaceIDUsageDescription` | Not requested. |
| Push notifications | (runtime via UNUserNotificationCenter) | Local notifications only for Camera Ahead proximity alerts; no remote push v1. |

Notes on location escalation flow: WhenInUse is requested up-front on first map view (free tier). Always is ONLY requested after the user explicitly toggles on Camera Ahead alerts in Settings (premium-only feature, behind the entitlement gate). Per Apple's location-escalation pattern, we request WhenInUse first, let the user use the app, then re-prompt for Always only at the moment of opt-in. We never request Always at launch.

## 8. Regulated / high-scrutiny flags

Check every box that applies. Each one adds reviewer scrutiny and usually
requires specific evidence in review notes.

- [ ] AI / ML / generative content → may require 17+ rating, content filtering disclosure
- [ ] Parses user documents (PDF / contracts / receipts / recipes / UGC)
- [x] Uploads user files to a server (user-submitted report photos go to S3)
- [x] Embeds/bundles third-party SDKs that collect data (PostHog product analytics — portfolio-shared key)
- [ ] Health, fitness, or medical data → **HealthKit / 5.1.3**
- [ ] Financial data / transactions / banking
- [ ] Kids (age rating under 13) → **5.1.4 Kids category** rules apply
- [ ] Legal / regulated advice (insurance, medical, legal, tax)
- [x] HIPAA / GDPR / CCPA applicability (CCPA applies because we collect identifiers + location; GDPR not applicable v1 because availability excludes EU per portfolio policy; we still honor right-to-delete via the account-deletion path)
- [ ] Downloads or installs executable code at runtime → **2.5.2**
- [ ] Embeds its own JavaScript engine → **2.5.1 / 2.5.2** dev-tool carve-out
- [x] User-generated content visible to other users → **1.2** UGC moderation required (camera reports become visible to other users only after a moderator flips `verified_status`)
- [x] Social / chat / messaging features (only inasmuch as user-submitted reports are crowd-sourced content — no DMs, no chat, no comments v1; reviewer should not interpret reports as social)
- [x] Location tracking in background (only after the user opts into Camera Ahead premium alerts)
- [ ] Uses cryptography beyond TLS / CryptoKit → **export compliance ERN** may be required

For every checked box, write **one paragraph** in section 11 (reviewer
notes) that pre-empts the reviewer's objection.

## 9. Reviewer demo path

Write the exact 5–10 step path the reviewer will take to see the core value
of the app. Include the demo credentials if login is required, the test
data the app needs, and any "skip to premium" toggle for validating paywall
success screens.

No login required for the primary review path. The reviewer can exercise every core feature anonymously.

1. Launch PlateAware. Grant **Location: While Using App** when prompted (the prompt explains that location is used to center the map on roads near you). The map centers on the simulator's location — typically Apple Park, Cupertino. Within ~2 seconds, fixed-camera pins appear within roughly a 5-mile radius (the bundled US-wide seed dataset contains thousands of pins; Cupertino / SF Bay Area is densely covered).
2. Tap any visible camera pin. The detail sheet shows: camera type (e.g. red-light, ALPR, traffic), source attribution (DeFlock node id + last_seen timestamp), confidence score, and verified_status. The "Report inaccuracy" link is visible at the bottom of the sheet.
3. Tap Settings (gear icon, top-right). The Premium upgrade card is visible at the top of Settings, showing both the **$7.99/month** (no trial) and the **$49.99/year with 7-day free trial** options, plus the full 3.1.2(a) disclosure block and the Restore Purchases button. Both Privacy Policy and Terms of Use are tappable links and load real HTML pages.
4. Tap the **Subscribe (Annual)** button. The StoreKit purchase sheet appears showing "7 days free, then $49.99/year". Reviewer can dismiss without purchasing — install-trial entitlement is already active from launch, so all premium features are exercisable for the trial window without any purchase.
5. From the main map, tap **Route Scan** (premium feature, accessible during install trial). Enter a destination or tap the "Use sample route" button. The app scans the route and shows the count and types of fixed cameras along the path.
6. From Settings, tap **Submit a Camera Report**. The form shows: type selector, optional photo (Camera + Photos permission gate the user can grant or skip), free-text note, and a "Use my current location" toggle. Reports go to a moderation queue; reviewers see a confirmation that the report was queued, NOT a live publish.
7. From Settings, tap **Reset App Data**. Confirmation alert explains this wipes local state and asks the server to delete the anonymous device-id row. After confirming, the app returns to first-launch state.

A SIWA demo account is included in `docs/reviewer-demo-credentials.md` only as a fallback path for reviewers who want to test saved-routes cloud sync and the Delete Account flow.

> Stage 5 and Stage 7 both pull from this section when filling ASC review
> notes. If the demo path requires a server to be up, note the monitoring
> contact and uptime commitment.

## 10. Backend dependencies

| Dependency | URL | Purpose | Required at launch? | Owner |
|---|---|---|---|---|
| PlateAware HTTP API | `https://api.platewatch.app` (Lambda + DynamoDB on HAS AWS account 139294832887, us-east-2) | Camera nearby/bbox queries, route-risk, sync, report submission | Best-effort 99.5% during review window | Tony |
| PostHog product analytics | `https://us.i.posthog.com` (portfolio-shared key `phc_zsZ6K…`) | Anonymous product analytics | No — app degrades silently if PostHog is unreachable | Tony |
| Apple StoreKit | (Apple) | IAP / subscription | Apple-managed | Apple |
| Sign in with Apple | (Apple) | Optional auth for saved-route sync | Apple-managed | Apple |
| DeFlock community map | `https://maps.deflock.org` | Primary source of camera location data (community-built ALPR/surveillance dataset, itself anchored on OpenStreetMap). Pulled WEEKLY server-side via EventBridge → Lambda, NOT called at runtime by the iOS app. | No (runtime independent of DeFlock availability) | DeFlock contributors + OpenStreetMap Foundation |
| OpenStreetMap Overpass | `https://overpass-api.de/api/interpreter` | Second primary source — queried directly for ALPR/ANPR, general surveillance, speed cameras, enforcement relations, and traffic-signal cameras. Pulled WEEKLY server-side on the same EventBridge cadence as DeFlock. 25m dedupe applied across both sources. NOT called at runtime by the iOS app. | No (runtime independent of OSM availability) | OpenStreetMap Foundation (ODbL) |
| Bundled seed dataset | (in-app resource) | First-launch fallback — a thin US-wide snapshot ships in the IPA so the reviewer's first map render always has pins even before the first delta sync completes | YES at launch — guarantees the reviewer sees pins even on cold start with no network | Tony |

Backends that MUST be up during review: PlateAware HTTP API at api.platewatch.app — Lambda + DynamoDB on the HAS AWS account 139294832887 in us-east-2. Single endpoint cluster: HTTP API → Lambda. Uptime commitment during review window: best-effort 99.5% with CloudWatch alarm wired to Tony's email. If the backend is down for any reason, the iOS app falls back to the bundled US-wide seed dataset for nearby/bbox queries (the seed ships in-app and contains thousands of pins) — this means the reviewer will see camera pins even on a hard backend outage, but route-risk and report submission require the API.

> If any backend is dark when the reviewer tries the app, it's a 2.1 reject.
> Keep these monitored during the review window.

## 11. Pre-emptive review notes draft

Draft the reviewer-notes text here (Stage 7 copies it to ASC). Hit every
flagged item from section 8:

**What PlateAware is.** PlateAware is a public-roadway infrastructure transparency map. It shows where fixed, permanent cameras (ALPR, red-light, traffic, toll readers) and school zones are located on public roads, using the DeFlock community map (built on OpenStreetMap) and other open public datasets. The positioning is privacy / civil-liberties awareness — letting drivers know which roads they travel are under fixed surveillance — and infrastructure transparency, not evasion. The same information is publicly mapped today by Waze (red-light cameras), Apple Maps, Google Maps, OpenStreetMap (the source we draw from), and a long tail of government open-data portals.

**What PlateAware is NOT, and how each guideline-risk category is cleared:**

- **(a) Not enforcement-evasion / 4.2.6 readthrough.** PlateAware does NOT detect, locate, or alert on police officers, ICE, immigration enforcement, sheriff's deputies, or any individual person. It shows ONLY fixed permanent installations that are visible from the public roadway and already documented in open public datasets. There is no live "police nearby" feature, no officer-reporting feature, no real-time enforcement detection. The proximity alerts ("Camera Ahead") fire only when the user approaches a fixed camera location stored in the public-data layer. The data source URL — `https://overpass-api.de/api/interpreter` querying tags `highway=speed_camera`, `man_made=surveillance`, `surveillance:type=ALPR` — is documented here as evidence of provenance, and a sample export is available on request.

- **(b) Not interference. 2.5 / 5.6 readthrough.** PlateAware does not jam, disable, hack, bypass, or interfere with any camera, network, or enforcement system. It is a read-only map.

- **(c) UGC / 1.2 / 5.1.2.** User-submitted camera reports are crowd-sourced content. (i) Reports are NEVER live to other users — they enter a `verified_status: unverified` state and only become visible to other users after a moderator flips them to `verified`. (ii) Every report screen includes a "Report inaccuracy / objectionable content" link. (iii) The EULA prohibits objectionable content (hate, harassment, doxing, persons-not-cameras). (iv) A block-a-reporter path exists for repeat bad-actor device-ids. (v) The user explicitly consents at report time and is shown what fields are collected (type, lat/lon, optional photo, optional free-text note).

- **(d) Background location / 5.1.1 read-through.** Background location (NSLocationAlwaysAndWhenInUseUsageDescription) is ONLY requested if the user explicitly toggles on Camera Ahead premium alerts in Settings. On first launch and through normal map use, only WhenInUse is requested. The usage strings explain in plain language what location is used for.

- **(e) Third-party SDKs / 5.1.2.** PostHog is the only third-party SDK and is used for anonymous product analytics (the portfolio-shared key — same key all Tony's apps use). PostHog events do not include precise location and are not linked to PII. PostHog is documented in the privacy policy and the App Privacy nutrition label.

- **(f) Subscriptions / 3.1.2.** Free tier shows nearby cameras + map + basic details. Premium ($7.99/mo, $49.99/yr with 7-day free trial on annual only) adds proximity alerts, route scan, offline state packs, density score, saved routes, faster sync. The 7-day trial is install-time per Subscriptions playbook Rule 4: from first launch, the app grants full Pro features for 7 days without requiring a Subscribe tap. The StoreKit intro offer on the annual product is the separate billing-side benefit. The paywall renders all six 3.1.2(a) disclosure sentences verbatim plus the Rule 3 forfeiture sentence ("If you start a free trial, any unused portion is forfeited if you purchase a subscription before the trial ends"), plus tappable Privacy / Terms / Restore Purchases.

- **(g) Account deletion / 5.1.1(v).** Two in-app paths, both two taps from the main map: **Delete All Data** (anonymous users — wipes install-trial stamp + onboarding + local entitlement) and **Delete Account** (SIWA users — wipes the same local state AND opens Apple's `appleid.apple.com/account/manage` UI so the user can revoke the Sign in with Apple grant directly with Apple). Both complete without an email round-trip. The full server-side row wipe + Apple-side token revocation endpoint (`DELETE /v1/account` + `auth/revoke`) is on the v1.1 backend (currently stubbed at 501); v1's surface satisfies 5.1.1(v)'s "in-app path that lets a user delete their account" requirement and the SIWA review-guideline requirement that the user can revoke the grant via Apple's UI from inside the app.

- **(h) Minimum functionality / 4.2.** The bundled US-wide seed dataset contains thousands of camera pins across the United States. The reviewer's default simulator location (Apple Park, Cupertino) is in a densely-covered region — pins will be visible on first launch with no panning required. If the reviewer pans to a low-density region and sees few pins, that reflects ground truth (OpenStreetMap genuinely has more data in dense urban areas), not a defect.

- **(i) MapKit / 4.10.** PlateAware uses Apple's MapKit for the underlying basemap and we DO NOT monetize the basemap. Premium features (proximity alerts, route scan, offline packs, density score, saved-route sync) are values WE add via OUR data layer — they are not built-in MapKit capabilities.

- **(j) API tier.** PlateAware has a Developer/Business/Fleet API tier sold OFF-APP at api.platewatch.app via Stripe. This tier is not advertised, linked, or sold from the iOS build. It is not mentioned in the App Store description. It exists only as a separately-purchased B2B SaaS product unrelated to the iOS consumer app.

## 12. Required App Store screenshots

- [x] 6.9" iPhone (1320×2868 or 2868×1320) — **3–10 required**
- [x] 13" iPad (2064×2752 or 2752×2064) — **3–10 required** (universal apps)
- [ ] App Preview video — optional, 15–30 s (skipped for v1)
- Screenshot ideas (one per core feature): five screenshots per device, ordered to lead with the transparency framing — (1) **Map view with camera pins** showing a dense urban area with mixed pin types color-coded by category; caption "See where fixed cameras already are on public roads"; (2) **Camera detail sheet** showing type / source attribution (OpenStreetMap) / last_seen / confidence / verified_status; caption "Every pin sourced from public open data"; (3) **Settings / Premium upgrade card** showing the monthly + annual options with the 7-day free trial copy and the full 3.1.2(a) disclosure block visible; caption "7-day free trial, cancel anytime"; (4) **Route scan result** showing a route line with camera counts by type; caption "Know your route before you drive"; (5) **Submit-a-report screen** showing the type selector + optional photo + note + consent line; caption "Crowd-sourced and moderator-verified". Hard exclusions on screenshot content: NO imagery of police officers, NO enforcement screenshots, NO "you got out of a ticket" / "beat a camera" copy, NO copy mentioning evasion / avoidance / detection of officers.

## 13. Privacy policy + terms requirements

- [x] Privacy policy URL hosted at: `https://has-deploy.github.io/platewatch/privacy.html` (will be created by Stage 1.5 review packet)
- [x] Terms of Use / EULA URL hosted at: `https://has-deploy.github.io/platewatch/terms.html` (will be created by Stage 1.5 review packet)
- [x] Both 200 OK on GET (verified at Stage 1.5; re-verified at Stage 4)
- [x] Both match what section 5 (data) + section 3 (payment) actually say

## 14. Go / no-go checklist before leaving Stage 0.5

- [x] Every field above filled (no `{{…}}` placeholders remain)
- [x] Section 8 boxes match what the code will actually do (verified against BACKEND_PLAN.md + spec.md)
- [x] Section 5 data table matches section 8 flags (PostHog declared in both; user uploads declared in both; background location declared in both)
- [x] Section 3 payment model picked and justified (trial-determination model, 7-day P1W per Rule 2, install-time entitlement per Rule 4)
- [x] Reviewer demo path (section 9) is concrete enough to follow (7 steps, no login required, fallback SIWA demo creds documented)

Only pass when every box is checked. Incomplete profile = Stage 1 blocked.

---

## Inferred-content register (Stage 0.5 author flags for Tony sanity-check)

The following fields are best-defensible inferences rather than spec-grounded answers. Skim before Stage 1 scaffolds against them.

1. **(inferred)** Free-tier limits — current draft of section 3 lists free-tier as "nearby cameras + map + basic details" and premium as "proximity alerts, route scan, offline packs, density score, saved routes, faster sync". The spec lists these features but does not crisply divide which one lives on which side of the paywall. Confirm before PricingConfig.swift is wired in Stage 1.
2. **(inferred)** Trial mechanics — 7-day P1W on annual only, no trial on monthly. Spec is silent on trial duration; defaulted to playbook Rule 2 daily-use cadence.
3. **(inferred)** SIWA as the only login provider — spec mentions "users" table and "subscriptions" table but does not specify the auth mechanism for the iOS app. SIWA-only chosen because it (a) trivially satisfies 4.8 parity, (b) avoids third-party-OAuth blast radius, (c) keeps the saved-routes cloud-sync feature scoped to a premium / opt-in surface.
4. **(inferred)** Anonymous device-id is the default identity on the free tier. The spec implies users-table-keyed identity throughout; the safer Apple-review posture is anonymous-first with optional SIWA upgrade.
5. **(inferred)** Premium-only saved-route cloud sync — spec lists "Saved routes" under Premium but does not specify whether they sync across devices. Defaulted to cloud sync = premium because cloud sync is the natural premium handle and SIWA is the natural sync mechanism.
6. **(inferred)** PostHog enabled at launch using the portfolio-shared key — consistent with the portfolio analytics rollout, but not in the original spec. If you want PlateAware to ship WITHOUT analytics for a clean privacy-first story, flag it now and section 5 + section 8 need to be edited before Stage 1.
7. **(inferred)** Bundled US-wide seed dataset ships in-app for offline / 4.2-mitigation fallback. The spec says "state-level offline packs, starting with Texas"; this risk profile widens that to a US-wide thin seed shipped in-app so the reviewer's first-launch map is never empty. The state-level Texas pack remains the deeper premium offline feature.
8. **(inferred)** Local push notifications only v1 — no remote APNs. The spec mentions "background refresh" and "local notification alerts" but is silent on remote push.
9. **(inferred)** GDPR not applicable v1 because portfolio policy excludes EU territories from availability — confirm portfolio policy still holds for PlateAware (excludes EU + Vietnam + Korea per the standard subscription playbook §1.5 territory rule).
10. **(inferred)** Camera reports include a photo at user option AND a free-text note. The spec lists user-submitted reports but does not specify field set; current draft mirrors the spec's `camera_reports` table by storing lat/lon + photo + note + type.
