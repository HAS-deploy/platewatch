# PlateAware Backend Plan — Reuse HAS AWS

Date: 2026-06-11
Directive: "Use existing Home Armor for the backend. In AWS. Keep it light."
Mode: discovery / planning only. No resources created.

---

## Caveat: local repo not found

`~/Developer/HAS-deploy/` does not exist on this Mac. The marketing-site memory note (`reference_homearmor_site_deploy.md`) points to that path, but the actual code lives in GitHub at `HAS-deploy/homearmor-platform` (confirmed via `aws amplify list-apps` — both Amplify apps have that repo URL). The live AWS inventory is enough to design from; cloning the repo is a prerequisite for actual implementation.

---

## What HAS has today (AWS account 139294832887)

| Service | Region | What it does |
|---|---|---|
| Amplify app `d2nngkcuez2bvn` (homearmor-platform) | us-east-2 | homearmorservices.com marketing site, Next 16 static export |
| Amplify app `d1pjfpijyjct6t` (HAS Homeowner Portal) | us-east-2 | app.homearmorservices.com portal frontend |
| CloudFormation stack `HasPortalV2Stack` | us-east-2 | Active portal backend (CDK) |
| CloudFormation stack `HasPortalBackendStack` | us-east-2 | Older portal backend (CDK, still up) |
| CloudFormation stack `DepositResolve-prod` / `-staging` | us-east-2 | Sibling product on the same account, same CDK pattern |
| API Gateway HTTP API `PortalHttpApi` (`q85j04l6ll`) | us-east-2 | Portal V2 REST surface, CORS-locked to homearmorservices.com + app subdomain |
| Lambda `HasPortalV2Stack-PortalApiHandler…` | us-east-2 | nodejs22.x, 512 MB, 30s, x86_64, env vars include TABLE_NAME / USER_POOL_ID / ANTHROPIC_API_KEY |
| Lambda `HasPortalV2Stack-PortalReminderHandler…` | us-east-2 | scheduled reminder worker |
| DynamoDB `HasPortalV2Stack-PortalTable…` | us-east-2 | Single-table, PAY_PER_REQUEST, PK/SK + GSI1 + GSI2 |
| Cognito user pool `us-east-2_9yZLngGRR` (PortalUserPoolF6EA700C) | us-east-2 | Portal V2 auth, has `admin` and `vendor` groups |
| Cognito user pools `us-east-2_5eSXRHnxS`, `RqPhlbAtU` | us-east-2 | Older portal pools (V1 / dev) |
| S3 `cdk-hasp-assets-139294832887-us-east-2` | us-east-2 | CDK asset bucket — reused automatically |
| S3 `hasportalv2stack-vendordocsbucket…` | us-east-2 | Portal vendor doc uploads |
| Secrets Manager | us-east-2 | Only DepositResolve secrets so far; HAS portal uses Lambda env vars |
| RDS | — | NONE in us-east-2. (us-east-1 has `rentospro-prod` Postgres but that is a different product on a different region — do NOT reuse.) |

**Pattern lock:** CDK (TypeScript) → HTTP API v2 → Lambda nodejs22 → DynamoDB single-table → Cognito for human auth. No RDS, no Fargate, no SAM, no Serverless Framework. Mirror this exactly.

---

## Lightest path for PlateAware

**Stack:** new CDK stack `PlateAwareStack` in the existing `homearmor-platform` repo, in us-east-2, same account.

- **API:** new API Gateway **HTTP API** `PlateAwareHttpApi` (CORS open to `*` since the client is an iOS app, not a browser). Custom domain optional v2 (`api.platewatch.app` via ACM + Route53 — defer until launch).
- **Compute:** one Lambda `PlateAwareApiHandler` (nodejs22, 512 MB, 30s, x86_64) routing all paths via a tiny Hono or lambda-api router. Mirror Portal's `index.handler` shape.
- **DB:** one new DynamoDB table `PlateAwareTable`, PAY_PER_REQUEST, single-table PK/SK + GSI1 (geohash lookups) + GSI2 (datasetVersion / moderation queue). Geohash partition key (`GH#<7-char>`) for nearby/bbox; route-risk = client splits the route into geohash cells and we batch-get. PostGIS deferred to v2.
- **Auth:** **no Cognito on v1.** iOS client signs requests with an API key + per-install device token stored in DynamoDB (`APIKEY#…` items with HMAC). When SaaS tier ships, add a Cognito app client on the *existing* `us-east-2_9yZLngGRR` pool — same pool, new client id, no new pool needed.
- **Rate limiting:** HTTP API stage-level throttling (built-in, free) at 50 rps / 100 burst per route. Per-API-key throttling = usage plan on a REST API or DIY token-bucket in DynamoDB. Start with stage-level + DIY counter; promote to REST API only if Tony wants real per-tenant quotas.
- **Dataset versioning:** S3 bucket `platewatch-datasets-<acct>-us-east-2` with `v=YYYYMMDD-HHMM/` prefixes; one DynamoDB item `META#dataset` carries the current pointer. The Lambda reads the pointer at cold-start. No new database; sync endpoint returns `{version, manifestUrl}`.
- **Admin moderation:** an admin-only route group (`/admin/*`) gated by a static admin API key in Lambda env. Upgrade to Cognito admin group when web admin UI ships.
- **Logs/alarms:** CloudWatch defaults; reuse Portal's `LogRetention` custom resource pattern (already in the stack).

Why this is the lightest: zero new always-on resources (Lambda + DDB + HTTP API are all per-request), zero new IAM patterns, no new runtime, no PostGIS / RDS, no Cognito provisioning, and one new CDK stack inside the existing app means deploy = `cdk deploy PlateAwareStack` from CI that already exists.

---

## Repo layout

Inside the existing monorepo `HAS-deploy/homearmor-platform`:

```
homearmor-platform/
  infra/                      # existing CDK app
    lib/
      has-portal-v2-stack.ts
      deposit-resolve-stack.ts
      platewatch-stack.ts      # NEW
    bin/app.ts                # add new PlateAwareStack(app, 'PlateAwareStack', {env: usEast2})
  services/
    platewatch-api/            # NEW — Lambda source
      src/
        index.ts              # router entrypoint
        routes/{nearby,bbox,routeRisk,sync,admin}.ts
        lib/{geohash,ddb,apikey}.ts
      package.json
      tsconfig.json
```

Recommendation: **single monorepo** (do not start a sibling repo). Reusing the existing CDK app, GitHub Actions, and Amplify build pipeline is the point of "keep it light." A sibling repo means a second CDK bootstrap relationship, second CI secret set, second deploy story — pure overhead.

---

## Estimated incremental AWS cost (first 1000 active users, ~5 req/user/day = 150k req/mo)

| Resource | Monthly |
|---|---|
| HTTP API (1M free tier shared, 150k well under) | $0.00 |
| Lambda (150k × 100ms × 512MB ≈ 7,500 GB-s, free tier 400k GB-s) | $0.00 |
| DynamoDB PAY_PER_REQUEST (~300k WRU, ~600k RRU) | ~$0.50 |
| S3 dataset bucket (5 GB stored, 50k GETs) | ~$0.15 |
| CloudWatch logs (under free tier) | $0.00 |
| Data transfer out (estimate 5 GB) | ~$0.45 |
| **Total** | **~$1–2 / mo** |

Custom domain + ACM cert = $0 (DNS only). Route53 hosted zone if new = $0.50/mo.

---

## What Tony has to approve before any `cdk deploy`

1. **New stack name** `PlateAwareStack` — okay to add to the existing CDK app in `homearmor-platform`?
2. **New DynamoDB table** (`PlateAwareTable`) — pay-per-request, single-table.
3. **New S3 bucket** `platewatch-datasets-139294832887-us-east-2` (private, versioned, lifecycle: keep latest 5 versions).
4. **New Lambda function + new HTTP API** (no Cognito attachment in v1).
5. **One new Lambda env var: `ADMIN_API_KEY`** stored in Secrets Manager at `/platewatch/prod/admin-api-key`. Approve secret creation.
6. **Optional v1.0:** custom domain `api.platewatch.app` — ACM cert in us-east-2, Route53 record. Skip if domain not registered yet.
7. **CORS:** confirm `*` is acceptable for the API (iOS client only, no browser). If a web admin lands later, narrow to that origin.
8. **Deploy pipeline:** mirror DepositResolve's GitHub Actions workflow (assumes `homearmor-platform` repo already has a CDK deploy action — verify after cloning the repo).

---

## What I held back (policy-level, did not auto-do)

- **Did not clone `HAS-deploy/homearmor-platform`.** Cloning a private GitHub repo into `~/Developer/` is a workspace change; ask before doing it.
- **Did not propose reusing `HasPortalV2Stack`'s DynamoDB table** with a `ROADAWARE#…` PK prefix. Technically lighter (zero new resources), but blast-radius coupling between two products is a bad call without Tony's sign-off. Flagged as a v0.5 option if cost matters more than isolation.
- **Did not propose Cognito reuse on v1.** Portal pool has `admin` / `vendor` groups; adding a `platewatch-user` group would work, but mixing consumer auth (PlateAware) with B2B portal auth (HAS) inside one pool risks security-blast accidents (password reset emails branded "Home Armor" going to PlateAware users). Defer until SaaS tier.
- **Did not propose adding PostGIS** even as a "needs Tony's nod" path, because no RDS exists in us-east-2 and standing one up violates "keep it light." Geohash on DynamoDB covers v1; revisit if route-risk polygon ops outgrow client-side splitting.
- **Did not touch us-east-1** (`rentospro-prod` RDS, `mcm-portfolio-prod` DDB / Cognito). Different product surfaces, different blast radius.
- **Did not enumerate IAM roles, KMS keys, VPCs.** Read-only audit was scoped to the services in the brief; deeper IAM/network mapping is a separate pass before first deploy.
