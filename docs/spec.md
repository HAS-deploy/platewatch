# PlateAware — Source Spec

> Verbatim copy of the inline spec provided by Tony 2026-06-11. This is the
> kickoff intent. Ground truth after Stage 0.5 is
> `docs/apple-review-risk-profile.md`.

---

You are my senior iOS + backend architect and build agent.

Build an API-first privacy/safety driver-awareness platform called PlateAware.

Goal:
Create an iOS app plus backend that maps public roadway surveillance/infrastructure points such as ALPR/Flock-style cameras, red light cameras, traffic cameras, toll readers, school zones, and road-risk points using public/open datasets. Position this as "privacy, safety, and infrastructure awareness," not evasion or interference.

Core business model:
Freemium install.
Premium subscription after initial use.
Consumer Pro: $7.99/mo or $49.99/yr.
Fleet/API tiers:
- Developer API: $29/mo
- Business API: $99/mo
- Fleet: $199/mo+
- Enterprise custom

Do not build anything involving jamming, disabling, hacking, bypassing, or interfering with cameras or networks.

Architecture:
iOS:
- SwiftUI
- MapKit
- CoreLocation
- SQLite or CoreData local cache
- StoreKit 2 subscriptions
- Background refresh
- Local notification alerts
- Route scanner

Backend:
- Cloudflare Workers or Node/Fastify
- Supabase Postgres with PostGIS
- Redis/cache if needed
- Public API endpoints
- Admin moderation dashboard
- Dataset versioning and delta sync
- Rate limiting and API keys

Data sources:
- OpenStreetMap / Overpass for surveillance/ALPR tags
- Other lawful open/public datasets where available
- User-submitted reports with moderation
- Manual admin verification
- Store source, confidence, last_seen, and verification status for every record

Required database tables:
- cameras
- camera_sources
- camera_reports
- users
- subscriptions
- api_keys
- sync_versions
- route_queries
- audit_logs

Camera fields:
id
lat
lon
type
subtype
brand
direction
road_name
city
state
country
source
source_url
confidence_score
verified_status
first_seen
last_seen
updated_at
tags_json

API endpoints:
GET /health
GET /v1/cameras/nearby?lat=&lon=&radius=
GET /v1/cameras/bbox?south=&west=&north=&east=
GET /v1/cameras/route-risk
GET /v1/cameras/state/:state
GET /v1/sync/version
GET /v1/sync/delta?since_version=
POST /v1/reports
POST /v1/api-keys
GET /v1/account/subscription

iOS free features:
- Map view
- Current location
- Nearby camera pins
- Limited searches
- Basic camera details

Premium features:
- Route scan before driving
- "Camera ahead" alerts
- Offline state download
- Advanced filters
- Camera density score
- Saved routes
- Faster sync
- Report history

Fleet/API features:
- API key dashboard
- Bulk route risk scoring
- CSV export
- Webhooks for new verified cameras in region
- Team/fleet account support

Important sync design:
Use dataset versioning.
App starts → checks latest sync version → downloads delta only.
Do not redownload full database every time.
Allow state-level offline packs, starting with Texas.

App Store-safe positioning:
Use terms:
- roadway awareness
- privacy awareness
- infrastructure transparency
- public data map
- safety alerts

Avoid terms:
- evade police
- beat cameras
- avoid detection
- disable
- jam
- bypass

Build order:
1. Create backend schema and seed sample data.
2. Implement camera nearby and bbox APIs.
3. Implement iOS SwiftUI MapKit app.
4. Add local cache and sync versioning.
5. Add subscriptions with StoreKit 2.
6. Add route-risk scan.
7. Add report camera flow.
8. Add admin moderation.
9. Add API key billing tier scaffold.
10. Produce App Store metadata and privacy policy draft.

Deliverables:
- Full repo structure
- Backend code
- iOS app code
- SQL migrations
- .env examples
- README setup
- Deployment instructions
- App Store description
- Privacy policy draft
- Test checklist
- Revenue/pricing notes

## Build decisions (Tony, 2026-06-11)

- App name: PlateAware (renamed from RoadAware 2026-06-11 to align with trendier ALPR-aware framing)
- Bundle ID: `com.platewatch.app`
- Sequencing: backend + iOS in parallel (two agents)
- Initial data scope: US-wide OSM Overpass extract for first seed
- Apple Team ID: `NH2XFPC9KN` (personal)
- Apple ID: `tony@medbillresolve.com`

### Strategic pivot 2026-06-11 (Tony): Business-first / data-company-from-day-one

**PlateAware is a data company. The iOS app is a lead generator + data collection platform + subscription funnel + user acquisition engine — not the primary product.**

Long-term products (in order):
1. **API Platform** ($29-$199/mo tiers)
2. **Fleet Intelligence** (fleet dashboards, recurring scans)
3. **Data Licensing** (CSV/GeoJSON/JSON exports)
4. **Enterprise Integrations** (SSO, audit logs, webhooks, custom)

All architecture decisions support those goals. Specific design directives that govern every future commit:

#### Multi-tenant from day one
Every user-created or tenant-owned record carries `tenant_id`. Public read-only data (cameras from OSM/DeFlock) is global (no tenant_id). Tenant types: `consumer | business | fleet | enterprise`. Tables that MUST carry tenant_id: `users`, `reports`, `api_keys`, `alerts`, `saved_routes`, `billing`, `subscriptions`, `audit_logs`, `fleet_*`. Tables that do NOT carry tenant_id: `cameras`, `camera_sources`, `sync_versions` (public dataset).

#### API-first
The iOS app consumes the same public APIs as external customers — no direct DB access, no app-specific endpoints. Everything goes through versioned `/v1/...` routes. This unblocks future Android, web, fleet dashboard, and third-party customers without rebuilding.

#### Data licensing-ready
Export pipelines from day one (even if locked to admin-only in v1): CSV / GeoJSON / JSON. Scopes: state, county, city, route, bounding box. Licensing controls = source attribution preserved on every record, opt-in flags on user-submitted records, audit log of every export.

#### Fleet schema (forward-only, not MVP)
Tables created in schema but not populated in v1: `fleet_accounts`, `fleet_users`, `fleet_vehicles`, `fleet_routes`, `fleet_alerts`. Features that consume them (route analysis, vehicle assignments, compliance reports, density reports, recurring route scans) ship later — but the schema supports them without migration.

#### Recurring revenue
Two payment paths, two providers:
- **Consumer iOS subscription** (PlateAware app) → Apple StoreKit (Pro Monthly $7.99, Pro Annual $49.99 w/ 7-day trial). Per Apple 3.1.1.
- **Developer/Business/Fleet/Enterprise API tiers** → Stripe, sold off-app at `api.platewatch.app`. Per Apple 3.1.3(b) Multiplatform Services carve-out. Not advertised inside the iOS app per current risk profile fence.

Feature gating must be **server-side** for all paid features beyond StoreKit's entitlement — the iOS app reads its current tier from the API, never decides locally.

#### API metering (per account)
Every API call increments per-tenant counters: `api_calls`, `camera_queries`, `route_queries`, `exports`, `sync_usage`. Stored in DDB with TTL (rolling 90-day window). Drives future usage-based billing + soft quotas.

#### Data moat
Every camera record stores `source_type`, `source_url`, `source_confidence`, `verification_status`. Reports table stores `user_reports`, `verification_history`, `moderator_actions`. Goal: proprietary verified dataset over time that's worth licensing.

#### Enterprise features (forward-only)
Designed but not in MVP: SSO (SAML/OIDC), team accounts, audit logs (every admin/moderator/API-key action recorded), webhooks (new-verified-camera-in-region delivery to subscribers).

#### Analytics
Server-side counters for: most-viewed cameras (by geohash), most-scanned routes (anonymized), most-active regions, user retention cohorts, subscription conversions. NOT scraped from PostHog — first-party data, queryable by tenant.

#### MVP vs forward — what ships in v1.0 iOS

MVP (v1.0 TestFlight):
- iOS app per current scope (map, RouteScan w/ Privacy route, paywall, reports submission, settings)
- Backend: cameras + reports + subscriptions tables, OSM + DeFlock ingestion, sync delta API
- Server-side entitlement check on premium routes
- Per-tenant `tenant_id` field present on user-scoped tables (even if v1 only creates one tenant per user)
- Stripe API tier scaffolded (route returns 501 — `POST /v1/api-keys`)

Forward (v1.1+):
- Fleet tables + fleet routes
- Stripe live billing for API tiers
- Data export pipelines (admin-only first)
- Audit logs + webhooks
- SSO
- Team accounts
- API metering counters

The v1 schema MUST accommodate all forward items without migration. Field names and table partitions chosen with forward fit in mind.

#### Privacy implication for v1 iOS (load-bearing for App Review)
User-submitted camera reports may be **included in aggregated camera datasets** that PlateAware publishes / licenses. This was always true conceptually (reports go to a public dataset) but the business-first framing makes it explicit. Required disclosures:
- ReportSubmitView consent line: "By submitting, I consent to this report being added to the public PlateAware dataset, which may be shared with third parties in anonymized form (location + camera type only — never personal data)."
- `privacy.html`: explicit data-sharing section for user-submitted reports
- `app-privacy-answers.md` nutrition label: flip "Data shared with third parties" from NO to YES for the User Content / Other User Content category — specifically: camera location reports may be shared in aggregate.
- Photos attached to reports are NEVER part of the public dataset — they're internal moderation only. This must be in the consent line.

### Feature addition 2026-06-11 (Tony): OSM/Overpass as second primary data source

Backend ingests from TWO public datasets in parallel, both open-data with documented licenses (ODbL for OSM, DeFlock follows OSM upstream):

1. **DeFlock community map** (`maps.deflock.org`) — community ALPR/surveillance dataset, weekly pull
2. **OpenStreetMap via Overpass API** — direct query for 5 tag families:
   - **ALPR/ANPR**: `surveillance:type=ALPR|ANPR` on `man_made=surveillance` nodes/ways
   - **General surveillance cameras**: `man_made=surveillance` + `surveillance=public|traffic` + `camera:type=*`
   - **Speed cameras**: `highway=speed_camera`, `enforcement=speed`, `relation[type=enforcement]`
   - **Enforcement relations**: `type=enforcement` with `enforcement=speed|traffic_signals|maxspeed|check`
   - **Traffic signals with cameras**: `highway=traffic_signals` + `traffic_signals:camera=*`

OSM records carry `osm_id`, `osm_type` (`node|way|relation`), and `source="osm_overpass"` for provenance. Raw tags preserved in `tags_json`. 25-meter dedupe applied across both sources (DeFlock pulls FROM OSM so overlap is expected; the dedupe step picks the higher-confidence record). Records not seen in two consecutive refresh cycles get `verified_status="stale"` (soft-delete, not removed — keeps history queryable).

Admin dashboard exposes a manual region-refresh endpoint scoped by US state for ad-hoc updates between scheduled cycles.

### Feature addition 2026-06-11 (Tony): MapKit routing + privacy-preferring route option

- **Real MKDirections-based routing** — the RouteScan feature must call `MKDirections.calculate(...)` with `requestsAlternateRoutes = true` and render the alternatives. The scaffold's polyline-and-count approach is a stub; route generation must be real.
- **Privacy-preferring route mode (premium)** — when the user picks "Privacy route" from the route picker, PlateAware scores each `MKRoute` alternative by total ALPR camera intersections (cameras within 50m of the polyline), then highlights the lowest-ALPR-score route as the recommended choice. The default mode shows the fastest route. The user makes the final pick.
- **Required user-facing copy** — must read as privacy/civil-liberties framing, never enforcement-evasion. Use: "Privacy route", "Privacy-preferring", "Low-surveillance route". NEVER use in UI copy or App Store metadata: "avoid", "evade", "beat", "bypass", "detect police", "around the camera", "ticket".
- **Map filter is separate** — keep the existing `MapFilterBar` ALPR-pin toggle as a display preference. Privacy routing operates regardless of which pin types are currently shown.

### Stage 0.5 answer set 2026-06-11 (Tony):

- **Free/premium feature split** — as drawn: free = map + nearby pins + basic details + limited searches/day; premium = proximity alerts ("Camera Ahead"), route scan, offline state packs, advanced filters, density score, saved routes, faster sync, report history.
- **Identity model** — anonymous device-id default; optional Sign in with Apple for cloud-sync of saved routes (premium feature only). SIWA is the only login option, so 4.8 parity is trivially satisfied.
- **Data source pivot** — pull from **`maps.deflock.org`** (the community ALPR/surveillance dataset built on OpenStreetMap), NOT a raw OSM Overpass extract. Full pull from launch ("from go"), refreshed **weekly** server-side via EventBridge → Lambda. iOS app queries the **local SQLite DB** for every map render — never hits the API on user actions. API only carries the delta-sync payload + report submissions.
- **Analytics** — PostHog enabled with the portfolio-shared key per `reference_posthog_portfolio` memory. Disclosed in privacy policy + nutrition label as anonymized analytics.
- **GDPR / availability** — EU + Korea + Vietnam excluded per the standard portfolio §1.5 territory list. PlateAware ships to the 146-territory portfolio default.

### Backend pivot 2026-06-11 (Tony):

> "use existing home armor for the backend. in aws. keep it light"

Override the spec's "Cloudflare Workers or Node/Fastify + Supabase Postgres with PostGIS" line. Backend lives in the existing HAS AWS account (`HAS-deploy/homearmor-platform` monorepo, AWS profile `has`). "Light" = minimal new infrastructure: piggyback on what's there, no new Postgres cluster, no PostGIS unless trivially available. Specific choice (Lambda + DynamoDB GeoIndex vs reusing an existing RDS vs minimal Fargate) decided after the HAS infrastructure audit lands.
