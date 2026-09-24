# Stage 4A — Guideline / code audit — PlateAware

Reviewer posture: adversarial App Store reviewer trying to reject. Source of truth: `docs/apple-review-risk-profile.md` §0 (category callout) + §0 Privacy-preferring route mode subsection. Run date: 2026-06-11.

---

## HARD findings (MUST fix before submission)

### 1. Settings → Delete Account is a stub. No server DELETE, no SIWA token revocation.

- Guideline: **5.1.1(v)** — "Apps that support account creation must also offer account deletion within the app." Sign in with Apple Review Guidelines additionally require apps to call Apple's token-revocation endpoint when a SIWA user deletes their account.
- Evidence: `PlateAware/Features/Settings/SettingsView.swift:134-140`
  ```swift
  Button(role: .destructive) {
      // SIWA delete account — wipes server-side row + revokes the token.
      // v1 stub; v1.1 wires the actual DELETE /v1/account call.
      hasSiwaCredential = false
  } label: { Label("Delete Account", systemImage: "trash") }
  ```
  No call to `apiClient.deleteAccount()`, no `ASAuthorizationAppleIDProvider.getCredentialState(...)` follow-up, no SIWA token revocation. Just flips a local `@State` bool. The user thinks their account was deleted; nothing happens server-side.
- Risk profile §6 commits to "calls authenticated `DELETE /v1/account` which wipes server records and triggers Apple's SIWA token revocation flow." `app-review-notes.md` line 25 promises the same to the reviewer ("Delete Account (SIWA, Apple revocation)"). If a reviewer signs in with SIWA, taps Delete Account, then re-signs-in with SIWA, the existing server row will still be there (or rather, no server row was ever created because the SettingsView SIWA path is also a stub — but that surfaces as the row still existing in their test account, or as ambiguity over what was deleted).
- Minimum fix: implement the real `DELETE /v1/account` request authenticated with the SIWA identity token, call Apple's SIWA token-revocation endpoint (`https://appleid.apple.com/auth/revoke`) server-side with the refresh token, clear local Keychain/UserDefaults, then flip `hasSiwaCredential = false`. Until that ships, do NOT enable SIWA login in production (remove the SignInWithAppleButton block or DEBUG-gate the whole `cloudSyncSection`) so the Delete Account path is never reachable. If SIWA stays in v1, the reviewer notes must drop the SIWA / Delete Account claim and the risk profile § 2/§6 needs revising.

### 2. Reset App Data does NOT wipe the install-trial stamp in Release builds.

- Guideline: **5.1.1(v)** (account deletion must actually delete) + 2.3.1 (accurate representation). The Settings UI tells the user this wipes "anonymous device-id, install trial stamp, onboarding state" (`SettingsView.swift:211`). The code only wipes those things in DEBUG.
- Evidence: `PlateAware/App/AppState.swift:73-84`
  ```swift
  func resetAppData() {
      entitlement.revokePaidEntitlement()
      #if DEBUG
      entitlement.debugReset()
      #endif
      UserDefaults.standard.removeObject(forKey: "platewatch.onboarding.complete")
      ...
  }
  ```
  `entitlement.debugReset()` is the ONLY code that clears `platewatch.firstLaunchAt`, `platewatch.firstLaunchAt.highWater`, `platewatch.installTrial.consumed`, `platewatch.isPremium`, `platewatch.subscription.productId`, `platewatch.subscription.expiresAt` (see `UserEntitlement.swift:162-169`) — and it's `#if DEBUG`. In a Release build, `resetAppData` flips three onboarding UserDefaults bools and revokes paid premium, but the install-trial stamp survives. A user who exhausted their trial cannot get a fresh trial by tapping Reset (functionally fine for trial integrity, but the user-facing copy "Wipes anonymous device-id, install trial stamp" is now a lie under 2.3.1).
  Worse, neither path posts `DELETE /v1/account/anonymous` against the server — risk profile §6 says it does. Reviewer notes say "Reset App Data wipes local + server."
- Minimum fix: extract the `debugReset()` body into a non-DEBUG method (e.g. `wipeForAccountDeletion()`) called from `resetAppData()`. Add the `apiClient.deleteAnonymousAccount(deviceId:)` call so the server row actually clears. Verified by the simulator audit (Stage 4B) by: launching, observing trial-active, tapping Reset, force-quitting, relaunching, asserting that the trial window is NOT re-granted (otherwise refund-resets become possible — keep `installTrialConsumed` semantics).

### 3. User-visible string contains the forbidden word "evasion" (twice).

- Guideline: Per risk profile §0 Privacy-preferring route mode subsection — a hard project rule: "The words 'avoid', 'evade', 'beat', 'bypass', 'around', 'ticket', 'police', 'officer', 'detect' MUST NOT appear in any user-facing string in the iOS app, App Store metadata, or marketing site." This is the single highest-risk mitigation for the 4.2.6 enforcement-evasion misread. "Evasion" derives from "evade" and a hostile reviewer scanning the binary for `evade*` will hit both. The defensive framing ("never evasion") makes it WORSE — it makes the app explicitly engage with the concept reviewers are looking to reject on.
- Evidence:
  - `PlateAware/Features/Settings/AboutView.swift:9` — `Text("A public-roadway infrastructure transparency map. … Privacy and awareness, never evasion.")`
  - `PlateAware/Features/Onboarding/OnboardingFlowView.swift:52` — welcome subhead: `"PlateAware maps fixed cameras — … Privacy and infrastructure transparency, never evasion."`
- Minimum fix: drop the negation entirely. Replace with positive framing — "Privacy, awareness, and public-data transparency." or "Public-data transparency for the roads you already drive." Do NOT replace with "never about avoiding police" or any synonym; the rule is the lexical category is forbidden. Add a unit test that greps user-visible strings for the forbidden vocabulary list to keep this from regressing (the code already contemplates this — `RouteScanView.swift:27` comments cite `RouteScanTests.testForbiddenWordsAbsentFromUserStrings` but neither AboutView nor OnboardingFlowView is covered).

---

## SIGNIFICANT findings

### 4. In-app "report objectionable content" + "block a reporter" affordances are missing.

- Guideline: **1.2 — Safety / User-Generated Content** — Apple requires: (i) a method for filtering objectionable material from being posted, (ii) a mechanism to report offensive content and timely responses to concerns, (iii) the ability to block abusive users, (iv) published contact information so users can reach the developer. Risk profile §0 explicitly lists "report-this-content path, block-a-reporter path, EULA prohibiting objectionable content, moderation queue. All four must exist before submission even though report volume will be near-zero at launch."
- Evidence: terms.html lines 86-99 cover the EULA + moderation-queue + abuse-reporting promise on the web, but the iOS code has no in-app UI for either:
  - `grep -rn -i "block.*report\|report.*objection" PlateAware/` returns nothing.
  - `CameraDetailSheet.swift:104-114` has a "Report inaccuracy" link, but that's about the camera record, NOT about the user-submitted report content (note/photo) — and reports never become user-visible until verified, so there is no surface a reviewer can tap from to flag bad UGC.
  - The defensive read: nothing user-submitted is shown to other users until a moderator verifies it, so there's "nothing to report yet." A hostile reviewer doesn't accept "the surface doesn't exist yet" as a 1.2 defense — they ask for the mechanism in the IPA today.
- Minimum fix: either (a) add a "Report content / block user" button on every visible UGC element + an in-app contact-developer link (mailto:support@…), OR (b) hide all visible UGC surfaces for v1 (already the case) AND state explicitly in `app-review-notes.md` that no user-submitted content is ever rendered to other users in v1 — and add an in-app "Contact support / report a problem" link from Settings that satisfies the "method to report" rule generically. Option (b) is the lower-effort defensible answer. Add the `mailto:support@platewatch.app` Link in `AboutView.swift:15-17` is good, but it lives behind two nav taps; raise it to Settings root or Help.

### 5. Annual paywall card surfaces an extra "free trial" statement not in the metadata description; risk of 3.1.2(a)/2.3 inconsistency.

- Guideline: **3.1.2(a)** + 2.3.1. The metadata description (`metadata.md:77`) and risk profile commit to "Annual — $49.99/year (7-day free trial)" disclosed verbatim. The paywall renders six required sentences (PASS). It ALSO renders the extra string from `PricingConfig.Disclosures.freeTrial`:
  > "On first install, new users get full Pro access free for 7 days. Trial ends automatically; no card required during trial."
- Evidence: `PaywallView.swift:229` renders `PricingConfig.Disclosures.freeTrial` directly in the disclosures block. The string is fine on its own, but it makes a claim that's NOT in the metadata description or the paywall-disclosure-check.md: that the trial is install-time (not subscribe-trial). It also implicitly contradicts the StoreKit intro offer the user sees on the annual card ("7 days free, then $49.99/year") — the StoreKit intro offer IS a subscribe-trial; the install-trial is separate. A reviewer who taps "Start free trial" on the annual card, then reads "no card required during trial" three lines down on the same screen, will be confused — they'll see the App Store sheet ask for confirmation, which contradicts "no card required."
- Minimum fix: move the `freeTrial` install-trial copy OUT of the 3.1.2 disclosures block and into either (a) a separate "Your 7-day free trial is active" banner above the cards (similar to the existing `trialBanner` already used at `PaywallView.swift:22-23`), OR (b) the onboarding trial-page only. The disclosures block should be the six Apple-required sentences only — adding install-trial framing in the same block invites a "misleading subscription presentation" rejection. The Rule 3 forfeiture sentence (`trialForfeit`) belongs in the disclosure block; the `freeTrial` install-trial sentence does not.

### 6. Welcome / mode-picker copy uses "Surveillance-light alternatives" — reviewer-misread risk.

- Guideline: 4.2.6 / 4.2 readthrough. Per risk profile §0 Privacy-preferring route mode subsection, this is the single highest-risk feature. Approved framing list: "Privacy route", "Privacy-preferring", "Low-surveillance route".
- Evidence: `RouteScanView.swift:120-121` — `"Surveillance-light alternatives sorted by plate surveillance. Premium."` The "Surveillance-light" phrasing is new and is NOT on the approved-vocabulary list in §0. "Plate surveillance" is also load-bearing — a reviewer skimming will read it as a synonym for "plate detection" / "avoiding plate readers."
- Minimum fix: replace with one of the §0-approved phrases verbatim — e.g. "Low-surveillance alternatives sorted by plate-reader exposure. Premium." or "Privacy-preferring routes sorted by ALPR exposure. Premium." Add the literal copy strings to a unit test against the §0 approved list.

### 7. Support email address inconsistency — AboutView vs. metadata vs. terms.html.

- Guideline: **2.3.7** (developer information) + 2.3.1 (accurate metadata). Three different support addresses are present:
  - `AboutView.swift:15` — `support@platewatch.app`
  - `metadata.md:85` — `support@medbillresolve.com or visit https://has-deploy.github.io/platewatch/support.html`
  - `app-review-notes.md:27` — `tony@medbillresolve.com`
- A reviewer who emails `support@platewatch.app` and gets a bounce will flag this. If the address isn't yet provisioned, it must not be the in-app contact. The risk profile and review notes commit to `tony@medbillresolve.com`.
- Minimum fix: pick one. Either provision `support@platewatch.app` as a real inbox routed to Tony before submission, or change `AboutView.swift:15` to the medbillresolve address. The portfolio convention is the support page at `has-deploy.github.io/platewatch/support.html` as the canonical contact surface.

---

## MODERATE findings

### 8. Keywords list contains third-party data-source name "deflock".

- Guideline: **Metadata consistency / 2.3.3** — Apple flags keywords that reference brands the app doesn't own when used to leverage the third-party's reach. DeFlock is the data source (legitimately attributed in description + ODbL), but using "deflock" as a keyword is borderline trademark-piggyback. "osm" is in similar territory (OpenStreetMap is open and unbranded, lower risk).
- Evidence: `metadata.md:96` — `alpr,redlight,traffic,toll,camera,map,privacy,roadway,navigation,driver,school zone,deflock,osm`
- Minimum fix: drop `deflock` from keywords. Description-level attribution to "DeFlock community map" is fine because it's content, not search-grabbing. Replace with a generic term — `alpr cameras`, `traffic`, `red light`, `commute`, `route`. Keep `osm` (OpenStreetMap is genuinely open and the project does not aggressively police use of the abbreviation).

### 9. Onboarding location page wording slightly overstates privacy guarantee.

- Guideline: **5.1.1** + 2.3.1. Onboarding location page tells the user: "We only use location to point the map at your road. It never leaves the app unless you opt in to Camera Ahead alerts in Settings." (`OnboardingFlowView.swift:69`)
- Evidence: `apple-review-risk-profile.md:119` is more nuanced — "approximate location for nearby/bbox queries (passed as request parameter, NOT stored beyond request)." Approximate location IS sent server-side with every map nearby/bbox query — that IS leaving the app. The onboarding string promises it never leaves the app outside Camera Ahead opt-in, which contradicts the privacy.html and risk profile.
- Minimum fix: replace with "Approximate location is used to fetch nearby cameras and is not stored after the request. Precise background location is only used if you turn on Camera Ahead alerts."

### 10. PostHog SDK present but no SDK-side PrivacyInfo.xcprivacy verified.

- Guideline: **Third-party SDK manifests** — every SDK on Apple's required-SDK list must bundle its own `PrivacyInfo.xcprivacy`. PostHog is on the list.
- Evidence: `PortfolioAnalytics.swift:43-46` imports PostHog. No verification step in this repo checks that the SwiftPM dependency's xcprivacy is bundled in the IPA. The app's own xcprivacy declares only `UserDefaults / CA92.1` — fine for what the app does. SystemBootTime, FileTimestamp, DiskSpace, ActiveKeyboards required-reason categories are not used by the app code (no `Date.timeIntervalSinceBoot`, no file-attribute reads observed). However, PostHog's SDK historically used SystemBootTime — that's declared in PostHog's own xcprivacy, not the app's, and we should verify it lands in the build.
- Minimum fix: at Stage 4B, verify `PrivacyInfo.xcprivacy` exists inside `Frameworks/PostHog.framework/` after archive. If not, upgrade to the latest posthog-ios that ships one. This is "pending Stage 4A/Stage 1" per `app-privacy-answers.md:152` — verify here that posthog-ios ≥ the version that bundles a manifest.

---

## SOFT findings

### 11. Bundled seed dataset coverage around Apple Park: 53 pins in Cupertino bbox, 290 in SF Bay. PASS.

- `seed-cameras.json` contains 1,275 pins. Custom check around (37.30 < lat < 37.40, -122.10 < lon < -121.95) returns 53 pins; SF Bay broader bbox returns 290. The default simulator launch at Apple Park (37.3349, -122.0090) with the MapView's initial `latitudeDelta: 0.25` will show plenty of pins. PASS on 4.2 minimum-functionality risk.

### 12. ATT not requested. PASS.

- Risk profile §7 declares ATT not requested. `grep -rn "TrackingDescription\|requestTrackingAuthorization" PlateAware/` returns nothing. No `NSUserTrackingUsageDescription` in Info.plist. Consistent with `app-privacy-answers.md:135`. PASS.

### 13. ITSAppUsesNonExemptEncryption = false. PASS.

- `Info.plist:23-24` declares false. App uses CryptoKit / URLSession defaults only, no custom crypto. PASS for Export Compliance.

### 14. 3.1.2(a) six sentences VERBATIM on paywall. PASS.

- `PaywallView.swift:225-231` renders `payment`, `autoRenew`, `renewalCharge`, `manage`, `freeTrial`, `trialForfeit` from `PricingConfig.Disclosures`. Strings are exactly the disclosure check `paywall-disclosure-check.md:21-35` requires (modulo finding #5 — the `freeTrial` sentence is install-trial, not 3.1.2(a) required). Privacy + Terms links via `footerLinks` (`:244-246`), Restore Purchases button at `:204` — all visible without a "?" tap. PASS on 3.1.2(a) verbatim rendering.

### 15. Install-trial entitlement matches RoadBinder pattern. PASS.

- `UserEntitlement.swift` mirrors the RoadBinder pattern: `platewatch.firstLaunchAt` UserDefaults key, `isEntitled = isPremium || installTrialActive`, monotonic high-water clock against device-clock rollback (`:83-90`), `installTrialConsumed` shut-off after paid sub (`:146-148`). `EntitlementGate.swift:29` consults `isEntitled`, not `isPremium`. PASS.

### 16. No modal-on-launch paywall. PASS.

- `ContentView.swift:9-22` shows onboarding when not complete, otherwise RootTabView. The `autoPresentPaywall` sheet at `:16` is gated on `-showPaywall` CLI flag (screenshot pipeline only). Onboarding trial page (`OnboardingFlowView.swift:117-130`) offers "Start exploring" as the primary button and "See pricing" only as the secondary — Continue does not require subscribing. PASS on 3.1.2 no-quick-fire-paywall.

### 17. MapKit owns routing; PlateAware only scores alternatives. PASS on 4.10.

- `RouteRiskService.swift:235-247` — `MKDirectionsProvider.calculate` calls `MKDirections.calculate(...)` with `requestsAlternateRoutes = true`; PlateAware never implements custom navigation. `scoreAlternatives(_:)` only decorates the returned `MKRoute` array. Free tier sees the MapKit basemap with no monetization. Premium ($7.99/mo, $49.99/yr) adds our data layer (proximity alerts, route scan, offline packs, density score, saved routes) — those are NOT system capabilities. PASS on 4.10 monetizing-built-in-capabilities.

### 18. Reviewer notes include civil-liberties framing. PASS.

- `app-review-notes.md` opens with "PlateAware maps PUBLIC fixed infrastructure from PUBLIC datasets. It does NOT detect, evade, or interfere with enforcement…" — note ironically that this very sentence uses the forbidden word "evade" in negation, like findings #3. It's appropriate here in reviewer notes (reviewer-facing context) but should be checked again at Stage 4D against the §0 stricture. App-side strings remain the HARD issue. (Reviewer notes mentioning "evade" in a "does NOT" sentence is the conventional pre-empt and matches the Trapster-precedent defense.) PASS for reviewer notes.

### 19. UGC reports require explicit consent + go to moderation queue. PASS (modulo finding #4).

- `ReportSubmitView.swift:59-65` shows the consent checkbox: "I confirm this report is about fixed public infrastructure visible from a public road, not a person, vehicle, or private property." `:74` disables Submit until consent. Server response copy "Report queued. ID: …. A moderator will review it before it appears on the map." (`:124`) confirms moderation. PASS on 5.1.2 consent + moderation. Finding #4 covers the missing in-app report-bad-content + block path.

### 20. Privacy manifest declares only what code uses. PASS.

- `PrivacyInfo.xcprivacy`: declares ProductInteraction (PostHog), CrashData (Apple-default), CoarseLocation (linked, for app functionality), DeviceID (linked, for app functionality). Required Reason API: only UserDefaults / CA92.1 declared. App code uses UserDefaults heavily (34 references). No SystemBootTime, FileTimestamp, DiskSpace, ActiveKeyboards usage observed in the app. PASS on the app's own manifest (third-party SDK manifest verification = finding #10).

### 21. NS*UsageDescription strings specific and user-readable. PASS.

- `Info.plist:27-34` strings are concrete and match Apple's "name what data is for" rule:
  - Camera: "PlateAware can attach a photo to a camera report you submit…"
  - Photo Library: "PlateAware can attach a photo from your library…"
  - Location WhenInUse: "…to center the map on roads near you and show nearby public surveillance infrastructure."
  - Location Always: "…in the background only when you've turned on Camera Ahead alerts…"
- All four pass the "human gets it in 3 seconds" test. PASS.

### 22. Onboarding sequencing matches no-modal-paywall + JIT location. PASS.

- ContentView → OnboardingFlowView on first launch; OnboardingFlowView page 0 is welcome, page 1 is location-permission CTA (`Allow While Using` button explicitly triggers the WhenInUse prompt), page 2 is trial intro with Start-exploring primary. PASS on the install-trial-without-friction model.

---

## Verdict

- HARD count: **3**
- SIGNIFICANT count: **4**
- MODERATE count: **3**
- SOFT count (PASS-with-context items): **12**
- Ship decision: **BLOCKED**

The three HARD findings are: (a) Delete Account is a non-functional stub, (b) Reset App Data only fully works in DEBUG, (c) two user-visible strings contain "evasion" which is on the §0 forbidden list and is the single highest-risk vocabulary for the 4.2.6 misread. The SIGNIFICANT findings — missing in-app 1.2 UGC controls, install-trial copy mixed into 3.1.2 block, "Surveillance-light" copy off the §0 approved list, and support-email inconsistency — would each be flagged by a thorough reviewer and any one is enough to bounce v1.

## VERDICT: NOT READY

### Required fixes before resubmission (numbered to match):

1. Implement real `apiClient.deleteAccount()` + Apple SIWA token revocation in `SettingsView.swift` Delete Account button; OR remove the SIWA login path from v1 entirely.
2. Move `entitlement.debugReset()` (or its body) out of `#if DEBUG` so `resetAppData()` works in Release; add the server-side `DELETE /v1/account/anonymous` call. Update Settings copy to match actual behavior.
3. Rewrite `AboutView.swift:9` and `OnboardingFlowView.swift:52` to drop the word "evasion". Use positive framing only. Add a regression test that greps user-visible strings against the §0 forbidden list — extending the existing `RouteScanTests.testForbiddenWordsAbsentFromUserStrings` pattern to cover ALL feature targets.
4. Add a Settings → "Report a problem" / contact-support link AND state in reviewer notes that v1 ships no user-visible UGC. Or add explicit per-content report+block buttons on any visible UGC surface.
5. Pull `PricingConfig.Disclosures.freeTrial` out of the disclosures block in `PaywallView.swift`; render it as a separate banner above the cards.
6. Replace "Surveillance-light alternatives sorted by plate surveillance" in `RouteScanView.swift:120-121` with a §0-approved phrase.
7. Pick one support email — `support@platewatch.app` OR `support@medbillresolve.com` OR `tony@medbillresolve.com` — and make AboutView, metadata.md, app-review-notes.md, and terms.html all match.

Re-run Stage 4A after fixes 1–7. If clean, proceed to Stage 4B simulator audit.
