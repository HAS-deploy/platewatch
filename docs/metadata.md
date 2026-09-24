# ASC Metadata — PlateAware

> Source of truth for what Stage 7 (`asc_metadata.py`) will push to App
> Store Connect. Keep this file synchronized with what's actually in ASC.
> Discrepancies between this file and ASC are a Stage 4A hard finding.

## App info (App Information tab)

| Field | Value |
|---|---|
| Name | PlateAware |
| Subtitle (30 chars max) | Public-roadway camera map |
| Primary category | Navigation |
| Secondary category | Travel |
| Privacy policy URL | https://has-deploy.github.io/platewatch/privacy.html |
| Privacy choices URL | https://has-deploy.github.io/platewatch/privacy.html |

> **Why Navigation + Travel (not Utilities):** Navigation is the honest
> primary because the core surface is a MapKit map with location + route
> scan + proximity alerts — that is the Navigation category Apple
> defines. Travel is the safest secondary because it's the same category
> Waze, Roadtrippers, and similar "driver-context" apps sit in and it
> reinforces the public-roadway / driver-information framing. Utilities
> was considered and rejected because it would invite a 4.2-minimum-
> functionality misread (a "utility" with one map view) and it loses the
> contextual cover provided by the Navigation/Travel pairing.

## Version info (per build)

| Field | Value |
|---|---|
| Version (MARKETING_VERSION) | 1.0.0 |
| Build (CURRENT_PROJECT_VERSION) | 1 |

## Version localization (en-US)

### Promotional text (170 chars, editable without new build)

See where fixed ALPR, red-light, traffic, and toll cameras already are on the public roads you drive. Sourced from open public datasets.

### Description (≤4,000 chars)

PlateAware is a public-roadway infrastructure transparency map. It shows where fixed, permanent cameras already exist on public roads — automatic license-plate readers (ALPR), red-light cameras, traffic-enforcement cameras, toll readers, and school zones — using the DeFlock community map (built on OpenStreetMap) and other open public datasets.

The same information is publicly mapped today by Waze, Apple Maps, Google Maps, and the open OpenStreetMap project itself. PlateAware is a focused, privacy-and-civil-liberties-oriented view of that public infrastructure, so drivers can know which roads they travel are under fixed surveillance.

PlateAware does not detect, identify, locate, or alert on any individual person, including law-enforcement officers. It does not jam, disable, bypass, or interfere with any camera, network, or enforcement system. It is a read-only map of public, fixed installations.

FREE
• Map view with your current location
• Nearby camera pins
• Basic camera details (type, source, last_seen, confidence, verified status)
• Up to 5 searches per day

PLATEWATCH PRO
• Camera Ahead proximity alerts before you reach a known fixed camera
• Pre-drive route scan — see camera types and counts along your route
• Offline state packs for use without a network
• Advanced filters by camera type, brand, and confidence
• Density score for the area you are viewing
• Saved routes with optional cloud sync
• Faster delta sync
• Full report history

DATA SOURCE
Camera locations come from the DeFlock community map at maps.deflock.org, which is built on OpenStreetMap and distributed under the ODbL open-data license. PlateAware ingests the dataset on a weekly schedule on our server. The iOS app reads from a local cache plus a bundled US-wide seed dataset, so the map renders fast and keeps working offline.

PRIVACY
PlateAware is designed to work without an account. We use an anonymous device identifier (not your Apple ID, not IDFA). Approximate location is sent only with map requests. Background location is used only if you turn on the premium Camera Ahead alerts. We use PostHog for anonymized product analytics and do not use any advertising network. Full details: https://has-deploy.github.io/platewatch/privacy.html

CROWD-SOURCED REPORTS
You can submit a camera report from inside the app. Reports go through moderation before they are visible to other users. The Terms of Use prohibit submitting content that identifies or targets any individual person.

SUBSCRIPTION
PlateAware Pro is offered as an auto-renewable subscription:
• PlateAware Pro Monthly — $7.99 per month (no free trial)
• PlateAware Pro Annual — $49.99 per year (7-day free trial for new subscribers)

Payment will be charged to your Apple ID account at confirmation of purchase. Subscription automatically renews unless canceled at least 24 hours before the end of the current period. Your account will be charged for renewal within 24 hours prior to the end of the current period. Subscriptions may be managed and auto-renewal may be turned off by going to the user's Account Settings after purchase. If you start a free trial, any unused portion is forfeited if you purchase a subscription before the trial ends.

Terms of Use: https://has-deploy.github.io/platewatch/terms.html
Privacy Policy: https://has-deploy.github.io/platewatch/privacy.html

SUPPORT
Email support@plateaware.app or visit https://has-deploy.github.io/platewatch/support.html

> Guideline 2.3.1: description must accurately describe what the app does.
> Every feature claimed here must actually work in the build. Do not claim
> "unlimited" / "fully offline" / competitor-better phrasing unless you can
> back it up in the app. If the app has a subscription AND the EULA is
> Apple's standard one (no custom EULA uploaded), include a line like:
> "Terms of Use (EULA): https://www.apple.com/legal/internet-services/itunes/dev/stdeula/"

### Keywords (100 chars, comma-separated, no spaces)

alpr,redlight,traffic,toll,camera,map,privacy,roadway,navigation,driver,school zone,commute,route,osm

### Support URL

https://has-deploy.github.io/platewatch/support.html

### Marketing URL (optional)

(none v1)

### What's New (release notes, per version)

Initial release. Public-roadway camera transparency map sourced from DeFlock + OpenStreetMap. Free map, nearby pins, and basic details. PlateAware Pro adds Camera Ahead, route scan, offline state packs, and saved routes.

## Review information

| Field | Value |
|---|---|
| Contact first name | Tony |
| Contact last name | McMurtrey |
| Contact email | tony@medbillresolve.com |
| Contact phone | (on file in ASC, Tony's personal number) |
| Demo required | No (anonymous primary path; SIWA fallback documented) |
| Demo username | (n/a — no demo required) |
| Demo password | (n/a — no demo required) |
| Review notes | (see `docs/app-review-notes.md` — paste into ASC Notes field) |

## Age rating

Answers set by `asc_metadata.py` — Apple's API wants literal booleans for
some and strings for others. Defaults:

- Cartoon/fantasy violence: `NONE`
- Realistic violence: `NONE`
- Prolonged graphic / sadistic violence: `NONE`
- Profanity / crude humor: `NONE`
- Sexual content or nudity: `NONE`
- Horror/fear themes: `NONE`
- Alcohol, tobacco, drug use: `NONE`
- Mature/suggestive themes: `NONE`
- Simulated gambling: `NONE`
- Medical/treatment information: `NONE`
- Unrestricted web access: `False`
- Gambling and contests: `False`
- Gambling (simulated): `NONE`
- Contests (user-generated): `False`

Override only when the app actually matches — e.g. AI content apps
typically bump to 17+. PlateAware ships at 4+.

## Content rights

`DOES_NOT_USE_THIRD_PARTY_CONTENT` — the displayed camera locations are
derived from open public datasets (DeFlock / OpenStreetMap, ODbL). ODbL
attribution is rendered inside the app (Settings → About → Data
Attribution) and in the privacy policy. No copyrighted third-party
material is bundled.

## Pricing

| Tier | Territory |
|---|---|
| Free (app itself) | All 146 territories per portfolio §1.5 (EU + Korea + Vietnam excluded) |

See Subscriptions playbook in `~/Documents/app-factory-workflow.md` for
setting per-territory prices when subs exist.

## IAP metadata (if any)

| Product ID | Reference name | Price | Subscription? |
|---|---|---|---|
| com.platewatch.app.monthly | PlateAware Pro Monthly | $7.99 / month | Auto-renewable, no trial |
| com.platewatch.app.yearly | PlateAware Pro Annual | $49.99 / year | Auto-renewable, 7-day free trial (P1W) for new subscribers |

Both products live in a single Subscription Group ("PlateAware Pro") so users can switch between monthly and annual. Annual includes a P1W introductory offer of `FREE_TRIAL` for `NEW` subscribers per the trial-determination model in the Subscriptions playbook §1.5. Install-time entitlement is granted client-side via `UserEntitlement` / `EntitlementGate` (mirroring RoadBinder) using `UserDefaults` key `platewatch.firstLaunchAt`; the StoreKit intro offer is the separate billing-side benefit.

Availability: 146 territories (US + portfolio default minus EU + Korea + Vietnam) per portfolio §1.5.

## Screenshots

Place PNGs in `~/Developer/platewatch/screenshots/` in the following
structure:

```
screenshots/
  iphone-6.9/  3-10 PNGs, 1320×2868 or 2868×1320
  ipad-13/     3-10 PNGs, 2064×2752 or 2752×2064
```

Stage 7 uploads them via `POST /v1/appScreenshotSets`.

Planned screenshot order (5 per device, per risk profile section 12):

1. **Map view with camera pins** — dense urban area, pins color-coded by camera type. Caption: "See where fixed cameras already are on public roads."
2. **Camera detail sheet** — type, source attribution (DeFlock / OpenStreetMap), last_seen, confidence, verified_status. Caption: "Every pin sourced from public open data."
3. **Settings / Premium upgrade card** — monthly + annual options, 7-day free trial copy, full 3.1.2(a) disclosure block visible. Caption: "7-day free trial, cancel anytime."
4. **Route scan result** — route line with camera counts by type. Caption: "Know your route before you drive."
5. **Submit-a-report screen** — type selector, optional photo, free-text note, consent line. Caption: "Crowd-sourced and moderator-verified."

Hard exclusions on screenshot content (per risk profile section 12): NO imagery of police officers, NO enforcement screenshots, NO "you got out of a ticket" / "beat a camera" copy, NO copy mentioning evasion / avoidance / detection of officers.
