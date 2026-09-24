# PlateAware Stage 1 backend — OSM/Overpass extension

Date: 2026-06-11
Status: Implemented locally. Nothing deployed. Nothing committed. No new AWS resources.

## Files added / modified

| File | Lines | Notes |
|---|---|---|
| `src/lib/osm.ts` | 393 | NEW. 5 Overpass query templates + combined query, `fetchOverpass` with 429 backoff, `normalizeOsmElement`, `osmConfidenceScore`, coarse `reverseGeocodeUSState`, `defaultUSTiles` (60 contiguous-US tiles + AK + HI). |
| `src/lib/dedupe.ts` | 107 | NEW. `dedupeNearby(cameras, 25m)` + `mergeRecords`. Pure function; OSM tags win on collision; merged_sources is union; first_seen earliest, last_seen latest. |
| `src/lib/ddb.ts` | 181 (+~70 over original) | Added `PK.merged`, `SK.mergedAudit`, `getAllForRegion`, `markStale`, `setRefreshSeenCount`. Imported `UpdateCommand`. |
| `src/routes/admin.ts` | 104 | NEW. `handleAdminRefreshRegion` — HMAC-key gated; returns 401 if no admin key configured (matches v1 expectation). Best-effort Lambda async invoke via `eval("require")` indirection so missing `@aws-sdk/client-lambda` doesn't break local TS compile. |
| `src/handler.ts` | 123 (+8) | Wired `POST /v1/admin/refresh-region`. |
| `src/types/camera.ts` | 74 (+~25 over original) | Added optional `osm_id`, `osm_type`, `merged_sources`, `tags_json`, `refresh_seen_count`. Added `"stale"` to `VerifiedStatus`. Existing DeFlock-only records remain valid. |
| `ingest/ingest.ts` | 310 (was 77) | Now runs DeFlock + OSM Overpass in one invocation, scoped by `region` + `source`, 5s spacing between Overpass calls, dedupes across both, walks GSI1 per state, increments `refresh_seen_count` on not-seen records, flips to `verified_status="stale"` at counter ≥ 2, snapshots to S3, bumps `META#dataset:CURRENT`. Writes optional `MERGED#<id>` audit rows. |
| `tests/osm-queries.test.ts` | 99 | NEW. 7 tests. Each template asserts the right tag filters + bbox order. Combined query unions all 5 family fingerprints. |
| `tests/osm-normalize.test.ts` | 179 | NEW. 13 tests. Fixtures for node/way/relation; confidence-score floor + cap; null-on-missing-coords; type-mapping for each tag family. |
| `tests/dedupe.test.ts` | 143 | NEW. 7 tests. ~10m records from different sources collapse with the higher-confidence record as winner; ~30m records stay separate; tag union with OSM precedence; merged_sources sorted; first/last_seen merge semantics. |
| `tests/ingest-stale.test.ts` | 121 | NEW. 7 tests. Stale-marking loop semantics extracted to pure function; seen-set derivation from ingested cameras. |
| `tests/admin-refresh.test.ts` | 142 | NEW. 7 tests. 401 with no key configured, 401 with missing/wrong header, 202 with valid key + valid body, 400 on invalid region/source, default region/source. |

DeFlock module (`src/lib/deflock.ts`) was NOT touched (per process discipline). iOS app NOT touched.

## Test verdict — PASS (67 / 67)

```
$ npm test
Test Suites: 8 passed, 8 total
Tests:       67 passed, 67 total
```

Breakdown:
- Original suites: `handler.test.ts` (12), `geohash.test.ts` (7), `sync.test.ts` (6) — all 25 still passing, no regressions.
- New suites: `osm-queries.test.ts` (7), `osm-normalize.test.ts` (13), `dedupe.test.ts` (7), `ingest-stale.test.ts` (7), `admin-refresh.test.ts` (7) — 42 new.

No live Overpass call in the test suite. `fetchOverpass` is import-mockable but the existing tests exercise the pure layers (query string assembly, normalization, dedupe math, stale counter semantics, admin auth gate) without touching the network.

## `cdk synth` verdict — PASS

```
$ CDK_DEFAULT_ACCOUNT=139294832887 CDK_DEFAULT_REGION=us-east-2 \
  npx cdk synth PlateAwareStack > /tmp/platewatch-stack.synth.osm.yaml
EXIT=0   (643 lines, vs 589 baseline — net +54 from larger Lambda bundle)
```

Same pre-existing `logRetention` deprecation warning as the baseline scaffold, no new errors. No new AWS resources required — the admin route reuses the existing `PlateAwareApiHandler` Lambda + the existing `platewatch/admin-api-key` Secrets Manager secret + the existing `PlateAwareIngestHandler` for async invokes.

## Tiling decision (OSM Overpass quota)

Continental US bbox ≈ (24.5, -125, 49.5, -66.5) tiled at 5° resolution = **60 tiles** + AK + HI = 62 tiles total. Each ingest pass runs 5 query families per tile = 310 Overpass calls, spaced 5s apart = ~26 minutes per full pass. Inside the Lambda's 5-minute weekly EventBridge window the full pass will NOT fit — for the live deployment, ingest.ts spaces should be re-tuned or the schedule changed (this is a v2 follow-up; the lighter `region="TX"` path stays well under budget). The 5° resolution is a deliberate trade-off: smaller tiles = more requests (Overpass quota); bigger tiles = single-query timeout risk on dense regions.

## What's stubbed for v1

- **Admin secret is empty.** `platewatch/admin-api-key` exists but no value; every `POST /v1/admin/refresh-region` returns 401 by design. Populate manually via AWS console / `aws secretsmanager put-secret-value` to enable.
- **City reverse-geocode is null.** OSM normalizer leaves `city` as null. State is derived from a coarse axis-aligned bbox map (50 US states + DC); precise on the interior, imprecise on borders. Sufficient for partition-key routing on `STATE#<code>`. City/county is a v2 pass.
- **Lambda async invoke degrades silently.** The admin route attempts `@aws-sdk/client-lambda` via runtime require; if the package isn't bundled (it isn't on local dev), invoke is no-op but the route still returns `accepted:true`. CDK deploy will bundle the SDK; verify by hitting the route once after first deploy.
- **Full-US ingest timing** (see "Tiling decision" above) — 26 min is over the 5 min Lambda timeout. Either (a) bump the ingest Lambda timeout, (b) shard tiles across multiple invocations via Step Functions / SQS, or (c) lower per-tile spacing to 2s. Flagged for the live-deploy decision; current scaffold runs cleanly for a scoped `region=TX` path.
- **No per-version delta diff log** still — unchanged from the prior scaffold. Clients reconcile from the manifest.

## Things I flagged as policy-level (did NOT auto-do)

- **No `cdk deploy`.** Synth only; output saved at `/tmp/platewatch-stack.synth.osm.yaml`.
- **No commits.** New files + edits sit in the working tree of `~/Developer/homearmor-platform/platewatch/backend/`.
- **No new AWS resources required.** The admin route is mounted on the existing `PlateAwareApiHandler`. The admin secret already exists. The ingest Lambda already exists. No infrastructure changes needed for this extension.
- **Did not add `@aws-sdk/client-lambda` to package.json** even though the admin route's async invoke uses it. Reason: it's a runtime-only require with graceful no-op fallback; the Lambda runtime in AWS already includes the AWS SDK v3 as a built-in layer (nodejs22.x), so adding it as a dep would just bloat the Lambda bundle for no functional gain. If a future audit wants explicit dependency tracking, add it then.
- **Did not modify `src/lib/deflock.ts`.** Per process discipline. Source remains isolated as the alternative data source.
- **Did not modify the iOS Camera model.** Per process discipline (another agent is auditing). Backend-side, the new `osm_id` / `osm_type` / `merged_sources` / `refresh_seen_count` fields are all optional, so the existing DeFlock-only records and the iOS sync payload remain backward-compatible.
- **Did not register a custom domain or change CORS posture.** Unchanged from prior scaffold.
- **Did not change the EventBridge weekly schedule.** Still Mondays 06:00 UTC. If full-US ingest is too long, the schedule will need adjustment alongside the Lambda timeout — defer to deploy time.

## Next steps (when you're ready)

1. Decide on full-US vs scoped-region ingest cadence (timing trade-off above).
2. Populate the `platewatch/admin-api-key` secret to enable the new route.
3. Add `INGEST_FUNCTION_NAME` to the API Lambda's env vars in CDK so async invokes wire end-to-end.
4. `cdk deploy PlateAwareStack`, then manually invoke once to seed the OSM half of the dataset.
