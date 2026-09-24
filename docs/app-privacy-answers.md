# App Privacy (nutrition label) answers — PlateAware

> The App Privacy nutrition label is the ONE thing Apple still makes you
> click through by hand (Stage 8). This file is the answer sheet — when
> you're clicking, this is what to type. Reviewers compare these answers
> to the code, the privacy policy, and the risk profile. Mismatches =
> rejection.

## Top-level question

**Do you or your third-party partners collect data from this app?**

- [ ] **No, we do not collect data from this app.**
      Choose this if and only if:
      - The app has no accounts + no signed-in users
      - No analytics SDK (no Firebase, no PostHog, no Mixpanel, no Amplitude)
      - No crash-reporting SDK (no Sentry, no Crashlytics)
      - No third-party ad networks
      - No user-generated content sent to any server
      - OAuth tokens stored locally for BYOK use do not count as "collected"

- [x] **Yes, we or our partners collect data.**
      Answer the data-type matrix below.

For PlateAware: **Yes.** PlateAware ships with PostHog product analytics enabled (portfolio-shared key, US host, anonymized), uses an anonymous device identifier, processes user-submitted camera reports server-side, sends approximate location with each map request, and stores SIWA-relay email + saved-route waypoints server-side for users who choose to sign in. All disclosed in `docs/privacy.html`.

---

## If "Yes" — data type matrix

For every data type below, answer:
1. Is it collected? (yes/no)
2. Is it **linked** to the user's identity? (yes/no)
3. Is it used for **tracking** (cross-app/website tracking per ATT)? (yes/no)
4. What purposes? (analytics, app functionality, product personalization, etc.)

### Contact info
| Type | Collected | Linked | Tracking | Purposes |
|---|---|---|---|---|
| Name | No | — | — | — |
| Email | Yes (SIWA users only — Apple's private relay address) | Yes | No | App Functionality (account-deletion communication for SIWA users) |
| Phone | No | — | — | — |
| Physical address | No | — | — | — |

### Health & fitness
| Type | Collected | Linked | Tracking | Purposes |
|---|---|---|---|---|
| Health (HealthKit) | No | — | — | — |
| Fitness (motion/activity) | No | — | — | — |

### Financial
| Type | Collected | Linked | Tracking | Purposes |
|---|---|---|---|---|
| Payment info | No (Apple StoreKit handles all payment; we never see card data) | — | — | — |
| Credit info | No | — | — | — |

### Location
| Type | Collected | Linked | Tracking | Purposes |
|---|---|---|---|---|
| Precise location | No (we never persist precise location; reports + saved routes store coarse coordinates only) | — | — | — |
| Coarse location | Yes (approximate lat/lon passed as a request parameter with each map/route-risk request; coarse coordinates stored for user-submitted reports and saved routes) | Yes (linked to anonymous device-id, or to SIWA id for saved routes) | No | App Functionality (return nearby cameras; render saved routes; deliver Camera Ahead alerts) |

### Sensitive info
| Type | Collected | Linked | Tracking | Purposes |
|---|---|---|---|---|
| Sensitive info (e.g. ethnicity, orientation, health) | No | — | — | — |

### Contacts
| Type | Collected | Linked | Tracking | Purposes |
|---|---|---|---|---|
| Contacts | No | — | — | — |

### User content
| Type | Collected | Linked | Tracking | Purposes |
|---|---|---|---|---|
| Emails or text messages | No | — | — | — |
| Photos or videos | Yes (optional — only photos a user attaches to a camera report) | Yes (linked to anonymous device-id, or to SIWA id) | No | App Functionality (display in moderation queue and, once verified, on the public map) |
| Audio | No | — | — | — |
| Gameplay content | No | — | — | — |
| Customer support | Yes (free-text note + report metadata submitted as part of a camera report; treated as customer-support/UGC) | Yes | No | App Functionality (route the report through moderation) |
| Other user content | Yes (the camera report itself: type, coarse coordinates, optional note) | Yes | No | App Functionality |

### Browsing history
| Type | Collected | Linked | Tracking | Purposes |
|---|---|---|---|---|
| Browsing history | No | — | — | — |

### Search history
| Type | Collected | Linked | Tracking | Purposes |
|---|---|---|---|---|
| Search history | No (PlateAware's own in-app camera lookups are not persisted server-side) | — | — | — |

### Identifiers
| Type | Collected | Linked | Tracking | Purposes |
|---|---|---|---|---|
| User ID | Yes (SIWA `sub` for users who choose to sign in) | Yes | No | App Functionality (saved-routes cloud sync; Delete Account) |
| Device ID | Yes (anonymous UUID we generate on first launch, stored in Keychain — NOT IDFA, NOT IDFV) | Yes | No | App Functionality (entitlement attribution; report attribution); Analytics (anonymous PostHog distinct_id) |
| Advertising ID (IDFA) | No | — | — | — |

### Purchases
| Type | Collected | Linked | Tracking | Purposes |
|---|---|---|---|---|
| Purchase history | Yes (StoreKit transaction id + subscription status) | Yes | No | App Functionality (entitlement validation; Restore Purchases) |

### Usage data
| Type | Collected | Linked | Tracking | Purposes |
|---|---|---|---|---|
| Product interaction | Yes (anonymized PostHog events — screen views, feature taps, paywall views) | No (not linked to identity beyond the anonymous PostHog distinct_id which is the device-id; no PII) | No | Analytics |
| Advertising data | No | — | — | — |
| Other usage data | No | — | — | — |

### Diagnostics
| Type | Collected | Linked | Tracking | Purposes |
|---|---|---|---|---|
| Crash data | Apple-default crash reporting only (Apple's data policy applies; user opt-in at iOS level) | Per Apple | No | App Functionality |
| Performance data | No | — | — | — |
| Other diagnostic data | No | — | — | — |

### Surroundings / body
| Type | Collected | Linked | Tracking | Purposes |
|---|---|---|---|---|
| Environment scanning | No | — | — | — |
| Hands | No | — | — | — |
| Head | No | — | — | — |

### Other
| Type | Collected | Linked | Tracking | Purposes |
|---|---|---|---|---|
| Other | No | — | — | — |

---

## Used for tracking? (ATT)

**No.** PlateAware does not use any data for cross-app or cross-website tracking. No IDFA. No advertising network. The ATT prompt is not requested.

## Data shared with third parties

- **AWS** (Lambda + DynamoDB + S3, us-east-2): acts as our data processor for everything we collect server-side. Not a separate "sharing" disclosure in ASC's model.
- **PostHog** (US cloud): acts as our analytics processor under DPA. Receives anonymized product-interaction events only.
- **Apple** (StoreKit + Sign in with Apple): receives subscription receipts and SIWA assertions per Apple's own data policy.
- No advertising network, no data broker, no other third party.

---

## Consistency self-check

Apple's reviewer will cross-reference these answers against:

1. `docs/apple-review-risk-profile.md` section 5 (data table) — they must match. Verified 2026-06-11: matches.
2. `docs/privacy.html` — "What the app collects" section must match. Verified 2026-06-11: matches (anonymous device-id, approximate location only-while-map-open, optional background location for Camera Ahead, optional report uploads, PostHog, optional SIWA email).
3. `privacy-sdk-audit.py` output — declared SDK privacy manifests must match. PENDING Stage 1 / Stage 4A; PostHog xcprivacy must declare its Required Reasons APIs.
4. Code — `grep -r` for analytics calls, keychain access, URLSession to external hosts. Every `POST` / `PUT` / `PATCH` off the device is a "yes" for *some* data type. PENDING Stage 1 / Stage 4A — expected hosts are `api.platewatch.app` and `us.i.posthog.com` only.

If any of the four disagrees with the matrix above, fix the matrix first,
then propagate the fix.
