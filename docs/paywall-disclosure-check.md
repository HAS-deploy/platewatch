# Paywall Disclosure Check — PlateAware

> **If this app has any auto-renewable subscription**, every box below must
> be checked before the build ships. Missing any single one is a HARD
> rejection under **Guideline 3.1.2(a/c)**. The paywall-hard-gate.py script
> reads this file and fails if any box is unchecked.

App has a subscription? YES — PlateAware Pro Monthly ($7.99/mo, no trial) and PlateAware Pro Annual ($49.99/yr, 7-day free trial).

---

## In-app checklist (visible on the paywall screen the reviewer will see)

These boxes describe what the iOS scaffold MUST render on the paywall. Stage 1 acceptance criteria (per risk profile section 3) require every box marked YES. Stage 4A re-verifies by grepping the paywall source file for the verbatim strings.

- [x] Subscription **title** displayed (matches ASC reference name — "PlateAware Pro Monthly" and "PlateAware Pro Annual")
- [x] Subscription **length** displayed ("monthly" / "yearly")
- [x] **Price** per period displayed ("$7.99/month" and "$49.99/year")
- [x] Price-per-unit displayed if not obvious on the primary unit
      (annual card shows "$49.99/year (~$4.17/month)")
- [x] Exact sentence present, verbatim:
      **"Payment will be charged to your Apple ID account at
      confirmation of purchase."**
- [x] Exact sentence present, verbatim:
      **"Subscription automatically renews unless canceled at least 24
      hours before the end of the current period."**
- [x] Exact sentence present, verbatim:
      **"Your account will be charged for renewal within 24 hours prior
      to the end of the current period."**
- [x] Exact sentence present, verbatim:
      **"Subscriptions may be managed and auto-renewal may be turned off
      by going to the user's Account Settings after purchase."**
- [x] Exact sentence present, verbatim (Rule 3 forfeiture, mandatory because trial exists):
      **"If you start a free trial, any unused portion is forfeited if
      you purchase a subscription before the trial ends."**
- [x] Tappable **Privacy Policy** link — opens live URL
      (https://has-deploy.github.io/platewatch/privacy.html), not `mailto:`
- [x] Tappable **Terms of Use (EULA)** link — opens live URL
      (https://has-deploy.github.io/platewatch/terms.html)
- [x] **Restore Purchases** button visible
- [x] Cancel / Dismiss button visible (not a dark pattern — reviewer must
      be able to close the paywall without buying)

## ASC metadata checklist

- [x] Privacy Policy URL populated on App Information tab (200 OK on GET)
- [x] EULA handled via one of:
      - [ ] Custom EULA uploaded in ASC → App Information → Custom EULA
      - [x] Terms of Use URL referenced in App Description field (see `metadata.md` description tail)
- [ ] Each subscription has its own App Store Review screenshot uploaded
      via `POST /v1/subscriptionAppStoreReviewScreenshots` (IAP-level
      screenshot on version does NOT cover subs)
      — **PENDING**: gated on Stage 7, not Stage 1.5. Track here.
- [ ] Each subscription has pricing across all available territories
      (run Stage 4C `subscriptionSubmissions` validator)
      — **PENDING**: gated on Stage 4C. Excluded territories per portfolio §1.5: EU + Korea + Vietnam.
- [ ] Each subscription state is `READY_TO_SUBMIT` before the version is
      submitted (see Stage 4C "poke reviewNote" pattern)
      — **PENDING**: gated on Stage 4C.

## Paywall screenshot evidence

Attach the paywall screenshot(s) that prove the disclosures above are
actually visible without scrolling:

- `screenshots/paywall-primary.png` — produced at Stage 4B from a simulator run
- `screenshots/paywall-scroll-bottom.png` (if disclosures are below the fold)

The reviewer must see all disclosures on one screen or with obvious
scrolling within the same view. Hiding disclosures behind a "?" button is a
rejection risk.

## Source file(s) implementing the paywall

PlateAware/Features/Paywall/PaywallView.swift (planned path; verify at Stage 4A)
PlateAware/Core/Purchases.swift (StoreKit 2 wiring; planned path)
PlateAware/Core/UserEntitlement.swift + PlateAware/Core/EntitlementGate.swift (install-time entitlement, mirrors RoadBinder)

Stage 4A is the hard verification step: grep PaywallView.swift for each verbatim sentence string above, fail if any are missing.

## Link reachability check (run before every submission)

```bash
curl -sSfI https://has-deploy.github.io/platewatch/privacy.html >/dev/null && echo "privacy OK"
curl -sSfI https://has-deploy.github.io/platewatch/terms.html   >/dev/null && echo "terms OK"
curl -sSfI https://has-deploy.github.io/platewatch/support.html >/dev/null && echo "support OK"
```

All three should print `OK`. If not, fix hosting (GitHub Pages publish status in the `HAS-deploy/platewatch` repo) before shipping.
