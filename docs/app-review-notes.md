# App Review Information → Notes — PlateAware

> Paste the section between the `---` markers below into
> **App Store Connect → App → Version → App Review Information → Notes**
> at submission. Target length: under 1,500 characters. Keep the framing
> in the first sentence — reviewers default to suspicion in this category
> (Trapster delisting precedent, 2020 "police lookout" removals), and the
> public-infrastructure-transparency framing is what clears the 4.2.6
> misread risk.
>
> This file is regenerated from `docs/apple-review-risk-profile.md`
> section 8 (flags) and section 11 (reviewer-notes draft). If the risk
> profile changes, re-scaffold this file or edit in place to match.

---

PlateAware maps PUBLIC fixed infrastructure from PUBLIC datasets. It does NOT detect, evade, or interfere with enforcement and does NOT identify or geolocate officers or any individual. Same category as Waze + Apple/Google Maps fixed-camera layers.

DATA. Fixed ALPR/red-light/traffic/toll/school-zone cameras from DeFlock (https://maps.deflock.org), built on OpenStreetMap, ODbL. Weekly server-side ingest; iOS reads local SQLite + bundled US seed.

DEMO (no login). Launch, grant Location While Using — pins appear in Cupertino. Tap pin: type/source/last_seen/confidence/verified_status. Overflow menu (top-right of detail sheet) surfaces 1.2 UGC controls: "Report this pin as inaccurate" + "Report objectionable content." Settings → Premium: $7.99/mo (no trial) + $49.99/yr (7-day trial) with full 3.1.2(a) disclosures, Privacy/Terms links, Restore. Install-time entitlement grants 7 days Pro without subscribing. Route Scan + Submit-a-Report (moderation queue). Settings → Delete All Data wipes local state.

PERMISSIONS. WhenInUse for map center. Always only after opting into Camera Ahead. Camera/Photos only when attaching a report.

PRE-EMPTS. 4.2.6: fixed installations only. 4.2: US seed = pins on first launch. 4.10: MapKit not monetized; premium = our data. 1.2/5.1.2: reports moderated; pin overflow-menu surfaces "Report this pin as inaccurate" + "Report objectionable content"; Report History → Reports from other drivers section surfaces "Block reporter" (beta — community reports surfaced in v1.1). 5.1.1(v): Delete All Data (anon) + Delete Account (SIWA — wipes local + opens appleid.apple.com/account/manage for grant revocation; full /v1/account server wipe lands in v1.1). 3.1.2(a): five sentences + forfeiture verbatim in disclosures block; install-trial copy rendered as separate banner above cards; trial annual only. SDK: PostHog (anonymous, US). No IDFA, no ATT. Separate B2B API at api.platewatch.app sold off-app via Stripe, not advertised here.

Contact: Tony McMurtrey, tony@medbillresolve.com.

---

## Demo credentials

No demo account required — the reviewer exercises the entire primary review path without login. See `docs/reviewer-demo-credentials.md` for the SIWA fallback if the reviewer wants to test saved-routes sync or the Delete Account flow.

## Known limitations we want to acknowledge

- Rural / low-coverage map areas may show few pins. That reflects ground truth in the open dataset, not a defect — denser urban areas have more contributions to OpenStreetMap / DeFlock.
- No remote push notifications v1. Camera Ahead uses local notifications only.
- iPad universal build; no macOS, no Apple Watch, no CarPlay v1.

## Contact during review

- Name: Tony McMurtrey
- Email: tony@medbillresolve.com
- Phone: (on file in ASC App Information)

---

_Last edited: 2026-06-11_
