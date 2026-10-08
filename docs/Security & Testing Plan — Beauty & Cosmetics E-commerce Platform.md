# Security & Testing Plan — Beauty & Cosmetics E-commerce Platform

Oct 8, 2026 · @Fatma

## 1. Summary

This plan lists 16 threats to the platform and the control that stops each one, then defines 80 test cases that prove those controls and every Must Have requirement work. Every Must Have requirement in the PRD maps to at least one test case (SM-2), and nothing is called production-ready until the quality gates in section 7 pass.

Most security controls were already decided in the PRD, architecture, database design and API contracts; this document gathers them into one checkable list and marks which are **essential for release 1.0** and which are **later hardening**. The plan was approved on 8 October 2026, including decisions D-132 to D-137 (section 8).

Two principles run through both halves:

1. **Test the failure, not just the success.** A checkout that works is the easy part; the tests that matter are a duplicate webhook, a tampered price, the last unit bought twice, or a Staff member calling an Admin-only endpoint.
2. **Prove controls with automated tests.** A control that isn't tested will quietly break during a later change. Each control in section 2 names the test that proves it.

## 2. Threat assessment

All 16 threats below have an essential control in release 1.0; the highest-impact ones involve money (TH-06 to TH-09) and access to other people's data (TH-04, TH-05, TH-12). Impact is rated for a real client store, even though the demo has no real customers.

| ID | Threat | Example | Impact | Control | Decisions | Proven by |
| --- | --- | --- | --- | --- | --- | --- |
| TH-01 | Password guessing and endpoint abuse | A script tries thousands of passwords, or floods place-order | High | Rate limits stored in the database; staff lockout; Argon2id hashing; common-password check; identical sign-in error messages | D-074, D-129, AD-01 | T-AU-02, T-AU-03, T-AU-06 |
| TH-02 | Session theft | Injected script reads the session cookie | High | HttpOnly `__Host-` cookies; React escapes output; no raw HTML rendering; Content-Security-Policy | D-125, NFR-13 | T-AU-10, T-NF-06 |
| TH-03 | Forged requests (CSRF) | Another site makes a signed-in shopper's browser cancel an order | Medium | SameSite=Lax; JSON-only mutations; Origin check per route group | D-076, D-121 | T-AU-11 |
| TH-04 | Privilege escalation | A Staff member or customer calls an Admin-only endpoint directly | High | Named permission checked on every admin endpoint; admin routes accept only the dashboard's Origin | D-041, D-121, D-126 | T-AZ-01 |
| TH-05 | Viewing other people's records | Changing an ID in a URL to see another customer's order | High | Ownership check on every customer endpoint, returning 404; UUIDs; hashed guest tokens | D-101, D-116, BE-03 | T-AZ-02, T-AZ-03 |
| TH-06 | Forged payment confirmation | Visiting the success URL, or sending a fake webhook | Critical | Signed webhooks only; server-side status lookup; the browser redirect never changes payment status | R-001, D-080 | T-PA-01, T-PA-04 |
| TH-07 | Duplicate charges or orders | Double-click on "Place order"; a webhook delivered twice | High | Idempotency keys; unique webhook event IDs; compare-and-set status updates | D-115, D-127 | T-CO-07, T-PA-02, T-PA-07 |
| TH-08 | Price tampering | Editing the request to pay 1 EGP for a perfume | Critical | Server recalculates every price and total; the client sends only IDs and quantities | R-002, D-128 | T-CO-03, T-CO-04 |
| TH-09 | Overselling | Two shoppers buy the last unit at the same moment | High | Row locks during order placement; database check `stock_quantity >= 0` | D-111, BE-05 | T-CO-06 |
| TH-10 | SQL injection | Search text containing SQL | Critical | Prisma's parameterized queries; raw SQL only through tagged templates with parameters, never string concatenation (enforced by a lint rule) | D-068 | T-CA-05, code review |
| TH-11 | Malicious file upload | A script disguised as an image | High | Staff-only upload; type checked from file content; re-encoded to WebP; size limit; random storage names; bucket read-only for the public | D-086, BE-10 | T-CA-07 |
| TH-12 | Data exposed through Supabase | Calling Supabase's public API with the public key | Critical | Row Level Security on every table with no rules; API roles' privileges revoked; secret keys only in the API app | D-088 | T-SY-05 |
| TH-13 | Leaked secrets | A key committed to Git, printed in logs or bundled into the browser | Critical | Environment variables; no secrets with the `NEXT_PUBLIC_` prefix; secret scanning in CI; log redaction; startup validation | Architecture section 7 | T-SY-04, T-SY-06, T-NF-07 |
| TH-14 | Vulnerable dependencies | A known flaw in an npm package | Medium | Lockfile; dependency scan in CI blocks high and critical issues | NFR-15 | T-NF-07 |
| TH-15 | Staff misuse | A staff member changes prices or issues refunds improperly | Medium | Least privilege (refunds Admin-only); append-only audit log of sensitive actions | D-040, D-044, D-119 | T-AD-06, T-AZ-01 |
| TH-16 | Personal data leaks | Customer data in exports, logs, emails or error reports | High | Exports Admin-only and audited; formula-safe CSV; log and Sentry scrubbing; outbox retention; anonymization on deletion | D-047, D-120, BE-15 | T-AD-05, T-AC-02, T-SY-06 |

## 3. Security checklist

The essential list must be complete before the demo is deployed (D-133); the hardening list is for client launches or later releases. Tick items during the security review in phase 12.

### Essential for release 1.0

**Authentication and sessions**

- [ ] Passwords hashed with Argon2id; never logged or returned
- [ ] Customer passwords at least 8 characters, staff at least 12, both checked against a common-password list
- [ ] Session tokens: 32+ random bytes, only the hash stored, new token at every sign-in
- [ ] Cookies `__Host-` prefixed, HttpOnly, Secure, SameSite=Lax
- [ ] Staff idle (30 min) and absolute (12 h) session limits enforced on the server
- [ ] Password change, reset and staff deactivation end other sessions immediately
- [ ] Reset, verification and invite tokens single-use, hashed, with expiry
- [ ] Identical responses for unknown email and wrong password; reset request always returns 202
- [ ] Rate limits and staff lockout active (section 5 of the API contracts)

**Authorization and request safety**

- [ ] Every admin endpoint declares a permission; an automated test fails if one doesn't
- [ ] Every customer endpoint checks ownership and returns 404 for others' records
- [ ] Origin checked per route group; mutations require JSON
- [ ] Last active Admin can't be deactivated or demoted
- [ ] All input validated with shared Zod schemas; unknown fields rejected
- [ ] No raw SQL built from strings; no rendering of raw HTML from user input

**Money and stock**

- [ ] Server calculates all prices and totals
- [ ] Webhook signatures verified on the raw body; invalid signatures rejected and logged
- [ ] Webhook event IDs unique; idempotency keys on order and money actions
- [ ] Payment amount and currency compared with the order before confirming
- [ ] Stock rows locked during order placement; database rejects negative stock
- [ ] Refunds never exceed the amount paid (locked check)

**Data and infrastructure**

- [ ] Row Level Security on every table; Supabase API roles have no privileges; a CI test checks both
- [ ] Supabase secret keys and payment keys only in the API app's environment
- [ ] All traffic HTTPS; security headers: Content-Security-Policy, HSTS, X-Content-Type-Options, frame protection, Referrer-Policy
- [ ] Uploads: staff-only, content-type sniffed, re-encoded, 4 MB limit, random storage keys
- [ ] Logs and Sentry scrub passwords, tokens, cookies, card data, full emails and phones
- [ ] CSV exports escape formula characters and are audit-logged
- [ ] Dependency scan and secret scan pass in CI
- [ ] Demo marked noindex
- [ ] Backup and restore procedure run once and documented (SM-7)

### Later hardening

| Item | Why it can wait | When |
| --- | --- | --- |
| 2FA required for Admins (AD-16, Should) | Built after Musts; strong passwords and lockout cover 1.0 | Release 1.0 if time allows; required for clients |
| Breached-password check against a public breach database | The common-password list covers the worst cases | Client launch |
| Strict Content-Security-Policy with nonces | A baseline policy is in 1.0; nonces need careful testing with Next.js | Release 1.1 |
| Automated dependency update pull requests | CI scanning already blocks known issues | After launch |
| "Active sessions" list with remote sign-out for customers | Password change already ends all sessions | Later |
| Uptime monitoring and alerting | Demo has no availability target (NFR-05) | Client launch |
| Secret rotation schedule | Few secrets, one developer | Client launch |
| External penetration test | Cost; the threat model and tests cover the main risks | Client with real revenue |
| Web application firewall rules | Platform defaults are enough at demo traffic | Client launch |

## 4. Testing strategy

Most tests are fast integration tests of the API against a real PostgreSQL, because the critical rules (stock, payments, permissions) live in the API and the database together. A small number of end-to-end browser tests cover the journeys a customer and staff member actually take.

### Test layers

| Layer | Covers | Tool | Runs against | When |
| --- | --- | --- | --- | --- |
| Unit | Pure logic: price and shipping calculation, order state machine, permission mapping, money formatting, validation schemas | Vitest | Nothing external | Every push |
| Integration (API) | Each endpoint through its route handler: validation, permissions, business rules, database effects, emails queued | Vitest + HTTP calls to the route handlers | Real PostgreSQL (Supabase CLI locally, a PostgreSQL service in CI) with fake external adapters | Every push |
| Database | Constraints, triggers, Row Level Security, concurrency (the existing 22-check script, extended) | Vitest + `pg` | Real PostgreSQL | Every push |
| Authorization suite | Every admin endpoint × every role, generated from the route list, so a new endpoint without a permission fails the build | Vitest | Real PostgreSQL | Every push |
| Component | Only complex UI logic: variant selector, cart merge, checkout form, RTL layout of key components | Vitest + Testing Library | Browser-like environment | Every push |
| End-to-end | Full journeys in a real browser: guest COD purchase, card purchase, payment failure and retry, staff fulfilment, refund | Playwright | All three apps running locally with the fake payment provider | Merges to `main`, on Chromium; all three browser engines before a release |
| Payment sandbox | Real Paymob test checkout and real webhooks | Playwright + manual | Deployed demo with Paymob test keys | Before each release and after any payment change |
| Accessibility | Automated checks on key pages; keyboard-only and screen-reader checklist | Playwright + axe; manual | Local and demo | Automated on `main`; manual before release |
| Performance | Mobile page speed (Core Web Vitals); API under 50 concurrent users | Lighthouse CI; k6 load tests | Paid-tier-equivalent settings (D-058) | Before release |
| Security checks | Dependency scan, secret scan, security headers, the essential checklist | CI scanners; header check; manual review | Repository and demo | Scans every push; review before release |

### Test design rules

- **Fake adapters in automated tests.** `PaymentProvider`, `EmailSender` and `FileStorage` have in-memory fakes. Tests can then make the "provider" succeed, fail, time out or send a duplicate webhook on demand. The real Paymob is tested only in the sandbox layer.
- **Signed webhook fixtures.** Webhook tests use payloads signed with a test secret, so signature checking is exercised for real.
- **Controllable clock.** Services read the time from an injected clock, so tests can jump 31 minutes ahead to test order expiry without waiting.
- **Isolated data.** Each integration test creates its own data with small factory functions and runs against a freshly migrated test database; tests never depend on each other's data.
- **Concurrency tests use real parallel transactions**, as in the database check script, not mocks.
- **One test per rule, named after it.** For example `places order: rejects when stock is insufficient (OUT_OF_STOCK)`, so a failing test reads like the requirement it protects.

## 5. Test cases

The 80 cases below are grouped by area. Each describes the scenario and the expected behavior, including failure cases; one case usually becomes several automated tests. Layer: U unit, I integration, D database, E end-to-end, S payment sandbox, M manual, P performance.

### Authentication and sessions (11)

| ID | Scenario | Expected | Layer |
| --- | --- | --- | --- |
| T-AU-01 | Customer registers, signs in, signs out | Session cookie set, `/auth/session` returns the customer; after sign-out the session row is gone | I, E |
| T-AU-02 | Sign-in with unknown email vs. wrong password | Same status, code and message | I |
| T-AU-03 | 6 failed sign-ins in 15 minutes; 4 reset requests in an hour | Sixth sign-in and fourth reset get `RATE_LIMITED` with `Retry-After` | I |
| T-AU-04 | Password reset token used twice, or after 1 hour | Second use and expired token get `INVALID_OR_EXPIRED_TOKEN`; a successful reset ends other sessions | I |
| T-AU-05 | Unverified customer orders; customer changes email | Order allowed; email changes only after the new address is verified | I |
| T-AU-06 | Staff fails sign-in 5 times | Account locked 15 minutes (`ACCOUNT_LOCKED`); lockout audit-logged | I |
| T-AU-07 | Staff idle 31 minutes; session older than 12 hours | Both requests get `UNAUTHENTICATED` (controllable clock) | I |
| T-AU-08 | Admin deactivates a signed-in Staff member | That Staff member's next request gets `UNAUTHENTICATED` | I |
| T-AU-09 | Admin with 2FA enabled signs in (Should) | Endpoints return `TWO_FACTOR_REQUIRED` until a valid code; recovery code works once | I |
| T-AU-10 | Inspect session cookies | `__Host-` prefix, HttpOnly, Secure, SameSite=Lax, Path=/ | I, E |
| T-AU-11 | Mutation with a foreign Origin; form-encoded body; admin route from the storefront Origin | All rejected with `ORIGIN_NOT_ALLOWED` before any effect | I |

### Authorization (4)

| ID | Scenario | Expected | Layer |
| --- | --- | --- | --- |
| T-AZ-01 | Every admin endpoint called as anonymous, customer, Staff and Admin | Matches the permission table exactly; generated from the route list | I |
| T-AZ-02 | Customer A requests B's order, address, or cart line | 404 every time; no data from B in the response | I |
| T-AZ-03 | Guest token for order X used on order Y; wrong token | 404 | I |
| T-AZ-04 | Deactivate or demote the last active Admin; two Admins demote each other at once | `LAST_ADMIN`; at least one Admin always remains | I, D |

### Catalog and storefront (10)

| ID | Scenario | Expected | Layer |
| --- | --- | --- | --- |
| T-CA-01 | Activate a product with no image, no enabled variant, or price 0 | `PRODUCT_NOT_ACTIVATABLE` listing each missing item | I |
| T-CA-02 | Duplicate option combination; fourth option; swatch on Size | Rejected | I, D |
| T-CA-03 | Delete a brand with products; a sold product; a never-sold draft | `IN_USE`, `IN_USE`, deleted | I |
| T-CA-04 | Listing with filters, price sort, page past the end | "From" price, any-variant price and stock matching, correct order, page clamped | I |
| T-CA-05 | Search "lip", "LIP", and text with quotes and `%` | Partial, case-insensitive matches; special characters treated as text | I |
| T-CA-06 | Open an archived product and a draft product | 410 with related products; 404 | I, E |
| T-CA-07 | Upload a renamed script, a 5 MB image, a photo with GPS data | First two rejected; third stored as WebP without metadata | I |
| T-SF-01 | Homepage with and without banners or featured products | Sections render; empty sections hidden | E |
| T-SF-02 | Choose shade and size; pick an out-of-stock combination | Price and image update; out-of-stock can't be added | E |
| T-SF-03 | Content pages and checkout return-policy link | All six pages reachable; link present at checkout | E |

### Cart (2)

| ID | Scenario | Expected | Layer |
| --- | --- | --- | --- |
| T-CT-01 | Cart with a changed price, an archived variant, quantity 11 | Notices shown; archived line excluded; quantity capped at 10 | I, E |
| T-CT-02 | Guest cart merged on sign-in with an existing server cart | Quantities added, capped at stock and 10 | I |

### Checkout and orders (10)

| ID | Scenario | Expected | Layer |
| --- | --- | --- | --- |
| T-CO-01 | Guest places a COD order | Confirmed, Unpaid; stock reduced; movement recorded; confirmation email queued; guest link works | I, E |
| T-CO-02 | Customer places a card order and pays | Awaiting payment, then Confirmed and Paid after the webhook | I, E, S |
| T-CO-03 | Request includes a price or total field | Ignored; server totals used | I |
| T-CO-04 | Price changes between quote and order | `PRICE_CHANGED` with a new quote; nothing created | I |
| T-CO-05 | Item sells out during checkout | `OUT_OF_STOCK` naming the variant; no order; no stock change | I, E |
| T-CO-06 | 20 simultaneous orders for the last 5 units | Exactly 5 orders; 15 `OUT_OF_STOCK`; stock 0 (SM-3) | I, D |
| T-CO-07 | Same idempotency key twice; same key with another body | One order, same response; `IDEMPOTENCY_KEY_REUSED` | I |
| T-CO-08 | COD above the maximum; disabled governorate | `COD_NOT_AVAILABLE`; `GOVERNORATE_NOT_AVAILABLE` | I |
| T-CO-09 | Totals around the free-shipping threshold | Fee charged just below, 0 at and above | U |
| T-CO-10 | Product price edited after an order | Old order shows the old price and name | I |

### Payments (7)

| ID | Scenario | Expected | Layer |
| --- | --- | --- | --- |
| T-PA-01 | Webhook with an invalid signature | 401; no change; logged | I |
| T-PA-02 | Same webhook delivered three times | Processed once (SM-4) | I |
| T-PA-03 | Webhook amount differs from the order | Payment recorded; order flagged, not confirmed | I |
| T-PA-04 | Customer opens the success URL without paying | Order stays Awaiting payment; status check asks the provider | I, E |
| T-PA-05 | Payment fails; customer retries, or switches to COD | New payment attempt works; or order becomes Confirmed COD within limits | I, E, S |
| T-PA-06 | No payment for 31 minutes; provider says unpaid / says paid | Cancelled and stock returned / confirmed; late payment with no stock is refunded | I |
| T-PA-07 | Webhook, expiry and customer cancel arrive together | Exactly one wins; others get a conflict; stock correct | I, D |

### Order lifecycle (6)

| ID | Scenario | Expected | Layer |
| --- | --- | --- | --- |
| T-OL-01 | Every status pair | Only the FL-07 transitions allowed; others `INVALID_STATUS_TRANSITION` | U, I |
| T-OL-02 | Customer cancels when Confirmed vs. Processing; Staff cancels after shipping | Allowed vs. refused; paid card order auto-refunded | I |
| T-OL-03 | Ship without tracking; ship with tracking | `VALIDATION_FAILED`; Shipped with email queued | I, E |
| T-OL-04 | Parcel returned to sender | Status Returned to sender; stock back; movement recorded | I |
| T-OL-05 | COD order delivered, then cash recorded | Paid only after recording; revenue counts it only then | I |
| T-OL-06 | Two staff edit one order's address | Second gets `STALE_VERSION`; edits blocked after shipping | I |

### Refunds, returns and inventory (5)

| ID | Scenario | Expected | Layer |
| --- | --- | --- | --- |
| T-RF-01 | Partial refunds summing above the paid amount, including two at once | The excess one gets `REFUND_EXCEEDS_PAID` | I, D |
| T-RF-02 | Card refund; COD refund | Pending until webhook; recorded as Succeeded | I, S |
| T-RF-03 | Return with restock and write-off lines; return after the window | Stock only for restocked lines; override reason required | I |
| T-IN-01 | Adjustments with wrong sign, below zero, or stale `expectedStock` | Rejected; valid adjustments write a movement with `stock_after` | I |
| T-IN-02 | Threshold changed from 5 to 10 | Low-stock list and counters update | I |

### Admin and customer account (11)

| ID | Scenario | Expected | Layer |
| --- | --- | --- | --- |
| T-AD-01 | Fee changed while an order exists | New checkouts use the new fee; existing order unchanged | I |
| T-AD-02 | Settings saved with an old version | `STALE_VERSION` | I |
| T-AD-03 | Invite, accept, change role, deactivate | Works; invite single-use; 72-hour expiry | I, E |
| T-AD-04 | Revenue with refunds, unpaid COD, cancelled orders; order at 23:30 Cairo | Received minus refunded only; counted on the Cairo date | U, I |
| T-AD-05 | Export a customer named `=HYPERLINK(...)` | Cell escaped; export audit-logged; Staff gets 403 | I |
| T-AD-06 | Price change, refund, role change | Audit rows with before and after; rows can't be edited | I, D |
| T-AD-07 | Dashboard in Arabic | Every screen right-to-left; no untranslated text; numbers and dates localized | E, M |
| T-AD-08 | Banners and featured products edited | Homepage reflects changes; max counts enforced | I |
| T-AC-01 | Addresses: 11th address, second default, invalid phone | Rejected; one default kept | I |
| T-AC-02 | Delete account with an open order; then after delivery | Blocked; then anonymized with orders kept | I |
| T-AC-03 | Order history and guest tracking | Own orders only, newest first; guest link shows one order | I, E |

### System and non-functional (14)

| ID | Scenario | Expected | Layer |
| --- | --- | --- | --- |
| T-SY-01 | Email service down during an order | Order succeeds; email retried later (NFR-06) | I |
| T-SY-02 | Daily job run twice; without the secret | Same end state; 401 | I |
| T-SY-03 | Unexpected error | `INTERNAL_ERROR` with request ID; no stack trace in the response | I |
| T-SY-04 | API starts with a missing environment variable | Refuses to start, naming the variable | I |
| T-SY-05 | Any table without Row Level Security | CI fails | D |
| T-SY-06 | Log a request containing a password and cookie | Values redacted | U |
| T-NF-01 | Key pages scanned; keyboard-only checkout | 0 critical or serious issues; checkout completes by keyboard | E, M |
| T-NF-02 | Mobile page speed; 50 concurrent users | Targets in NFR-01 to NFR-03 met | P |
| T-NF-03 | Pages at 360, 768, 1280, 1920 px | No horizontal scroll; touch targets ≥ 44 px | E |
| T-NF-04 | Core journeys in Chromium, WebKit, Firefox | All pass | E |
| T-NF-05 | Product page head; sitemap; demo headers | Unique title and canonical; sitemap lists products; noindex on demo | I, E |
| T-NF-06 | Response headers | Content-Security-Policy, HSTS, nosniff, frame protection present | I |
| T-NF-07 | CI scans | No high or critical dependency issues; no secrets found | CI |
| T-NF-08 | Restore the latest backup into a fresh database | App runs on the restored data (SM-7) | M |

## 6. Traceability matrix

Every one of the 48 Must Have requirements maps to at least one test case, which satisfies SM-2. When a requirement changes, this table shows which tests must change with it; when a test fails, it shows which requirement is at risk.

### Storefront

| Requirement | Test cases |
| --- | --- |
| ST-01 Homepage and navigation | T-SF-01, T-AD-08 |
| ST-02 Category and brand browsing | T-CA-04 |
| ST-03 Product page and variants | T-SF-02, T-CA-06 |
| ST-04 Search | T-CA-05 |
| ST-05 Filtering, sorting, pagination | T-CA-04 |
| ST-06 Shopping cart | T-CT-01, T-CT-02 |
| ST-07 Registration and sign-in | T-AU-01, T-AU-02, T-AU-03 |
| ST-09 Email verification and password reset | T-AU-04, T-AU-05 |
| ST-10 Profile and address book | T-AC-01 |
| ST-11 Account deletion | T-AC-02 |
| ST-12 Checkout | T-CO-01, T-CO-03 to T-CO-09 |
| ST-13 Card payment | T-CO-02, T-PA-01, T-PA-04 |
| ST-14 Cash on Delivery | T-CO-01, T-CO-08, T-OL-05 |
| ST-15 Payment failure and retry | T-PA-05, T-PA-06 |
| ST-16 Order history and tracking | T-AC-03, T-AZ-03 |
| ST-17 Customer cancellation | T-OL-02, T-PA-07 |
| ST-18 Content pages | T-SF-03 |

### Admin dashboard

| Requirement | Test cases |
| --- | --- |
| AD-01 Staff sign-in and sessions | T-AU-06, T-AU-07, T-AU-08 |
| AD-02 Products, variants, images | T-CA-01, T-CA-02, T-CA-03, T-CA-07, T-CO-10 |
| AD-03 Brands and categories | T-CA-03 |
| AD-04 Inventory | T-IN-01, T-IN-02 |
| AD-05 Orders and fulfilment | T-OL-01 to T-OL-06 |
| AD-06 Refunds and returns | T-RF-01, T-RF-02, T-RF-03 |
| AD-07 Shipping configuration | T-AD-01, T-CO-09 |
| AD-08 Homepage content | T-AD-08 |
| AD-09 Customer viewing | T-AZ-01, T-AZ-02 |
| AD-10 Analytics and counters | T-AD-04, T-IN-02 |
| AD-11 CSV exports | T-AD-05 |
| AD-12 Staff accounts and roles | T-AD-03, T-AZ-04 |
| AD-13 Store settings | T-AD-02, T-CO-08 |
| AD-14 Audit log | T-AD-06 |
| AD-15 Bilingual interface | T-AD-07 |

### Backend

| Requirement | Test cases |
| --- | --- |
| BE-01 API conventions | T-SY-03, T-CA-04 |
| BE-02 Authentication and sessions | T-AU-01, T-AU-04, T-AU-10 |
| BE-03 Authorization | T-AZ-01, T-AZ-02, T-AZ-03 |
| BE-04 Validation and errors | T-SY-03, T-AU-11 |
| BE-05 Order creation and inventory | T-CO-05, T-CO-06 |
| BE-06 Idempotency | T-CO-07, T-PA-02 |
| BE-07 Payments and webhooks | T-PA-01 to T-PA-07 |
| BE-08 State machine and expiry | T-OL-01, T-PA-06 |
| BE-09 Refunds | T-RF-01, T-RF-02, T-OL-02 |
| BE-10 File uploads | T-CA-07 |
| BE-11 Transactional emails | T-SY-01 |
| BE-12 Scheduled jobs | T-SY-02, T-PA-06 |
| BE-13 Audit logging | T-AD-06 |
| BE-14 Logging and monitoring | T-SY-03, T-SY-06 |
| BE-15 Personal data handling | T-AC-02, T-SY-06 |
| BE-16 Setup, seed, migrations | T-SY-05; every CI run migrates a fresh database and runs the seed twice to prove it's idempotent |

### Success metrics and key non-functional requirements

| Requirement | Test cases |
| --- | --- |
| SM-1 Core journeys pass end to end | T-CO-01, T-CO-02, T-PA-05 |
| SM-3 No overselling | T-CO-06 |
| SM-4 No duplicate webhook effects | T-PA-02 |
| SM-5 No admin endpoint reachable by the wrong role | T-AZ-01 |
| SM-6 and NFR-01 to NFR-03 Performance and Lighthouse scores | T-NF-02, T-NF-01, T-NF-05 |
| SM-7 and NFR-31 Backup restored | T-NF-08 |
| NFR-06 Failures never lose orders | T-SY-01 |
| NFR-11, NFR-13 HTTPS and headers | T-NF-06 |
| NFR-14 Rate limits | T-AU-03 |
| NFR-15, NFR-16 Dependencies and secrets | T-NF-07 |
| NFR-18, NFR-19 Accessibility | T-NF-01 |
| NFR-20, NFR-22 Responsive and browsers | T-NF-03, T-NF-04 |
| NFR-21, NFR-33 RTL and translations | T-AD-07 |
| NFR-23 to NFR-25 SEO and noindex | T-NF-05 |

Should Have requirements get tests when they're built: AD-16 two-factor (T-AU-09 is ready), ST-08 Google sign-in and ST-19 wallets (added to T-AU-01 and T-PA-05).

## 7. Quality gates and "production-ready"

Code moves forward only when the checks for its stage pass; a build that compiles, or a happy path that works, is not enough.

### Gates

| Gate | Must pass | Blocks |
| --- | --- | --- |
| Every push and pull request | Lint, type-check, unit, integration, database and authorization tests, production build of all three apps, dependency and secret scans | Merging |
| Merge to `main` | All of the above, plus the end-to-end suite on Chromium | Deploying to the demo |
| Feature done (each roadmap phase) | Its test cases in section 5 pass; traceability rows updated; coverage ≥ 80% on order, payment, inventory and authorization code (NFR-27); no new essential checklist gaps | Starting the next phase |
| Release 1.0 | Everything above, plus end-to-end on Chromium, WebKit and Firefox; Paymob sandbox run (T-CO-02, T-PA-05, T-RF-02); accessibility automated and manual checks; performance targets; full essential security checklist ticked; backup restore exercise | Calling the demo finished |

### Definition of production-ready

The platform is production-ready for a client only when all of these are true:

1. All 48 Must Have requirements pass their test cases, with the traceability matrix complete.
2. All 16 threats have their essential control in place and its proving test passing.
3. The Release 1.0 gate has passed on the deployed demo, not just locally.
4. The client-launch items in the architecture's section 10 are done: paid hosting, live payment keys verified with one real payment and refund, domain, backups on a paid plan, restore tested.
5. Known gaps are written down in the release notes rather than hidden.

Until then the honest description is "portfolio demo, built to production standards, running in test mode".

## 8. Decisions (approved)

| ID | Decision | Section |
| --- | --- | --- |
| D-132 | Threat assessment TH-01 to TH-16 with their controls | 2 |
| D-133 | The essential security checklist must be complete before the demo is deployed; hardening items follow later | 3 |
| D-134 | Test layers and tools: Vitest (unit, integration, database, authorization), Testing Library (selected components), Playwright with axe (end-to-end and accessibility), Lighthouse CI and k6 (performance) | 4 |
| D-135 | Fake adapters, signed webhook fixtures and a controllable clock in automated tests; the real Paymob sandbox only in release checks | 4 |
| D-136 | The 80 test cases and the traceability matrix as the definition of "done" for each requirement | 5, 6 |
| D-137 | Quality gates per stage and the definition of production-ready | 7 |

- [x] D-132 to D-137 approved
- [x] This plan approved; next is the implementation roadmap
