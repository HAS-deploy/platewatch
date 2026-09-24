# PlateAware Stage 1 backend — scaffold notes

Date: 2026-06-11
Status: Scaffolded locally. Nothing deployed. Nothing committed.

## Where it landed

Cloned `HAS-deploy/homearmor-platform` to `/Users/tony/Developer/homearmor-platform/`.
The repo has no top-level `package.json` (not a workspaces monorepo); the
convention is `<product>/backend/` + `<product>/frontend/` siblings
(`portal/backend`, `website/`). PlateAware matches that pattern at
`platewatch/backend/`:

```
homearmor-platform/
  portal/backend/                   # existing — HasPortalV2Stack
  platewatch/backend/               # NEW
    package.json                    # nodejs22, esbuild, aws-sdk v3 (DDB/S3/SecretsManager)
    tsconfig.json
    cdk.json                        # qualifier "hasp" — same as Portal
    bin/backend.ts                  # instantiates PlateAwareStack in us-east-2
    lib/platewatch-stack.ts         # the CDK stack
    src/
      handler.ts                    # API Lambda router, all /v1/* routes
      routes/{cameras,sync,reports,apiKeys,account}.ts
      lib/{ddb,geohash,deflock,auth,ratelimit}.ts
      types/camera.ts               # matches iOS Camera fields exactly
    ingest/
      ingest.ts                     # weekly EventBridge Lambda
      README.md
    tests/
      handler.test.ts, geohash.test.ts, sync.test.ts
    docs/DDB_SCHEMA.md
```

PlateAware is a sibling stack — it does NOT mount inside `portal/backend/bin/backend.ts`,
which keeps blast-radius isolated (you can deploy / roll back PlateAware without
touching the Home Armor portal stack). Both use bootstrap qualifier `hasp` and
region `us-east-2`, so they share the existing CDK bootstrap.

## `cdk synth` verdict — PASS

```
cd /Users/tony/Developer/homearmor-platform/platewatch/backend
CDK_DEFAULT_ACCOUNT=139294832887 npx cdk synth PlateAwareStack
```

Template saved to `/tmp/platewatch-stack.synth.yaml` (589 lines).
Both Lambdas bundled cleanly via esbuild. Resources in the template:

- `PlateAwareTable` (PAY_PER_REQUEST, PK/SK, GSI1, GSI2, PITR on, TTL attr `ttl`)
- `PlateAwareDatasetsBucket` (versioned, BLOCK_ALL public, 5-version lifecycle)
- `PlateAwareAdminApiKey` Secrets Manager secret (empty placeholder)
- `PlateAwareApiHandler` (nodejs22, x86_64, 512MB, 30s)
- `PlateAwareIngestHandler` (nodejs22, x86_64, 1024MB, 5min)
- `PlateAwareWeeklyIngest` EventBridge rule (cron `0 6 ? * MON *`, UTC)
- `PlateAwareHttpApi` HTTP API v2 + `$default` stage with 50 rps / 100 burst throttling, CORS `*`
- Routes `ANY /` and `ANY /{proxy+}` → API handler
- `PlateAwareApi5xxAlarm` (CloudWatch, 5xx > 5/min)
- Least-privilege IAM per Lambda (DDB read/write to the table, S3 read to the bucket, Secrets read to the secret; ingest gets bucket read+write)
- Outputs: API URL, table name, bucket name, secret ARN

CDK warns `logRetention` is deprecated — matches Portal stack's usage, so I left
it for consistency. Worth a sweep later across both stacks.

## Test verdict — PASS

`npx jest --runInBand` → **25 / 25 passing** across 3 suites:
- `geohash.test.ts` — 7 tests (encoding stability, haversine sanity, cell coverage)
- `sync.test.ts` — 6 tests (delta envelope, applyDelta idempotency, version contract)
- `handler.test.ts` — 12 tests (smoke every route, OPTIONS preflight, 404, 501, mock-fallback behavior)

`npm install` succeeded (28 vulns reported, none blocking; matches Portal's
posture — no `npm audit fix` run because that's a separate decision).

## What's stubbed for v1 (safe vs. not safe to deploy)

Safe to ship as-is once you approve the AWS resources:

- All read paths (`/health`, `/v1/cameras/*`, `/v1/sync/*`) — return mock data
  if DDB is empty/unreachable, return real data once the ingest Lambda has run.
- `POST /v1/reports` — writes to DDB under `REPORT#<id>:META` w/ `GSI2PK=MODERATION#PENDING`.
  Returns `pending_review` even if DDB write fails (so iOS UX is robust).
- Weekly ingest — pulls deflock.org, normalizes, batch-writes DDB, snapshots S3,
  bumps `META#dataset:CURRENT`. Idempotent on re-run (same version = no-op-ish).

**Stubbed; do NOT treat as live:**

- `POST /v1/api-keys` returns 501. No Stripe live keys, no webhook signature
  verification, no key persistence. `routes/apiKeys.ts` has a `handleStripeWebhook`
  placeholder but no route is mounted.
- `GET /v1/account/subscription` returns `{active:false, productId, expiresAt:null}`
  with a note. iOS StoreKit2 is the source of truth on v1 — server-side Apple
  receipt validation is not implemented.
- HMAC API-key verification in `src/lib/auth.ts` is wired but no SaaS route uses
  it yet. `isAdminApiKey()` checks env `ADMIN_API_KEY` — the Secrets Manager
  secret is created EMPTY; populate manually in the AWS console before any
  admin route is mounted.
- Per-version delta diff log is not yet kept in DDB; `/v1/sync/delta` returns
  empty `additions`/`removals` + the manifest URL, expecting the client to
  reconcile from the manifest. Fine for v1 since the client downloads the
  full snapshot anyway; revisit when payload size becomes an issue.

## What I held back as policy-level

- **Did not `cdk deploy`.** Synth only, output saved to `/tmp/platewatch-stack.synth.yaml`.
- **Did not create any AWS resources.** No DDB table, no S3 bucket, no Secrets
  Manager secret, no Lambdas, no API, no EventBridge rule actually exist in
  account 139294832887 yet.
- **Did not populate the admin API key.** The `platewatch/admin-api-key` secret
  is created empty by the stack; you populate it via the console (or `aws secretsmanager
  put-secret-value`) before mounting any admin route.
- **Did not commit to the monorepo.** `git status` shows the new `platewatch/`
  directory + `package-lock.json` untracked. Review before commit; the
  `node_modules/` dir is git-ignored at the repo root.
- **Did not add Stripe live keys.** The SaaS API tier is fully stubbed —
  `routes/apiKeys.ts` is 501 and no Stripe secret is referenced anywhere.
- **Did not modify the existing Portal stack or `portal/backend/bin/backend.ts`.**
  PlateAware is a sibling CDK app in its own directory; the two stacks are
  independent. If you'd rather mount PlateAware in the same CDK app as Portal
  (`portal/backend/bin/backend.ts`), that's a 3-line change.
- **Did not register a custom domain.** `api.platewatch.app` deferred to v2 per
  the plan.

## Next steps (when you're ready)

1. Review the synth output at `/tmp/platewatch-stack.synth.yaml`.
2. `cd platewatch/backend && CDK_DEFAULT_ACCOUNT=139294832887 npx cdk deploy PlateAwareStack`
   (after `npm install` on a deploy host that has AWS creds).
3. Populate `platewatch/admin-api-key` in Secrets Manager.
4. Manually invoke `PlateAwareIngestHandler` once to seed the dataset before
   the first weekly schedule fires.
5. Wire `PlateAwareApiUrl` into the iOS app's config.
