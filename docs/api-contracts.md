# API Contracts — Beauty & Cosmetics E-commerce Platform

Oct 8, 2026 · @Fatma

## 1. Summary and conventions

The API is one REST API under `/api/v1`, split into four route groups: storefront, admin, integrations and health. Every request and response shape is a shared Zod schema in `packages/shared`, and the OpenAPI documentation is generated from those schemas (D-069). This document lists every endpoint the PRD needs and gives full contracts for the ones where money, stock or security are at stake. It was approved on 8 October 2026, including decisions D-121 to D-130 (section 10).

### Route groups (D-121)

| Group | Prefix | Called by | Accepted `Origin` |
| --- | --- | --- | --- |
| Storefront | `/api/v1/store/*` | Storefront app (proxied, D-072) | `STOREFRONT_URL` only |
| Admin | `/api/v1/admin/*` | Dashboard app (proxied) | `DASHBOARD_URL` only |
| Integrations | `/api/v1/webhooks/*`, `/api/v1/jobs/*` | Paymob, Vercel Cron | None; signature or secret instead |
| Health | `/api/v1/health` | Uptime checks | Any |

Each group accepts requests only from its own frontend's address. A request for an admin endpoint arriving from the storefront is rejected before any other check, which adds a layer on top of permissions (R-003).

### Versioning

The version is in the path (`/v1`). Within v1, changes are only additive: new endpoints, new optional request fields, new response fields. Removing or renaming a field, or changing its meaning, requires `/v2`. Because both frontends ship from the same monorepo as the API, v2 is unlikely to be needed in release 1.0.

### Formats (D-122)

| Item | Convention | Example |
| --- | --- | --- |
| Body | JSON (`Content-Type: application/json`); image upload is the only `multipart/form-data` endpoint |  |
| Field names | camelCase | `paymentStatus` |
| Single resource | `{ "data": { ... } }` |  |
| List | `{ "data": [ ... ], "meta": { ...pagination } }` | Section 3 |
| Error | `{ "error": { ... } }` | Section 2 |
| IDs | UUID strings | `"0192f3a1-..."` |
| Order number | String of digits, shown to people | `"100245"` |
| Money | Object with a decimal string and currency; never a JSON number | `{ "amount": "350.00", "currency": "EGP" }` |
| Dates and times | ISO 8601 in UTC; frontends display in Cairo time | `"2026-10-08T14:30:00Z"` |
| Enums | Upper-case strings matching the database | `"AWAITING_PAYMENT"` |
| Empty values | `null`, never omitted, for optional fields that exist on the resource | `"landmark": null` |
| Text language | English in 1.0; responses carry the translated name for the requested locale with English fallback once Arabic exists (D-108) |  |

Money is a string because JSON numbers are floating point in JavaScript; `"350.10"` stays exact, while `350.1` can drift during arithmetic (D-104).

## 2. Errors (D-123)

Every error, from every endpoint, has the same shape. Frontends decide what to show from the `code`, never by parsing the message.

```json
{
  "error": {
    "code": "VALIDATION_FAILED",
    "message": "Some fields are invalid.",
    "details": [
      { "path": "address.phone", "code": "INVALID_PHONE", "message": "Enter an Egyptian mobile number starting with 010, 011, 012 or 015." }
    ],
    "requestId": "req_01JA2X8M3K"
  }
}
```

- `details` appears only for validation errors and lists every invalid field, so a form can mark them all at once.
- `requestId` also appears in the logs (BE-14), so a user's screenshot of an error leads straight to the log line.
- Unexpected errors return `INTERNAL_ERROR` with a generic message; the stack trace goes only to logs and Sentry (BE-04).

### Error codes

| HTTP | Code | When |
| --- | --- | --- |
| 400 | `MALFORMED_REQUEST` | Body isn't valid JSON, or the wrong content type |
| 401 | `UNAUTHENTICATED` | No valid session for an endpoint that needs one |
| 401 | `TWO_FACTOR_REQUIRED` | Staff session exists but the 2FA step isn't completed (AD-16) |
| 403 | `FORBIDDEN` | Signed in, but the role lacks the permission |
| 403 | `ORIGIN_NOT_ALLOWED` | Request came from the wrong frontend or failed the CSRF check (D-076) |
| 404 | `NOT_FOUND` | Record doesn't exist, or belongs to someone else (object-level access, BE-03) |
| 409 | `STALE_VERSION` | Admin edit based on an outdated `version` ("changed by someone else, reload") |
| 409 | `INVALID_STATUS_TRANSITION` | Status change not allowed from the current status (FL-07) |
| 409 | `OUT_OF_STOCK` | Not enough stock; `details` names each variant and the quantity available |
| 409 | `PRICE_CHANGED` | Total differs from what the customer confirmed; response includes the new quote (ST-12) |
| 409 | `ORDER_ALREADY_PROCESSED` | Payment retry or cancel on an order that has moved on |
| 409 | `LAST_ADMIN` | Would deactivate or demote the last active Admin |
| 409 | `IN_USE` | Delete blocked because other records reference it (e.g. brand with products) |
| 422 | `VALIDATION_FAILED` | Field-level errors in `details` |
| 422 | `COD_NOT_AVAILABLE` | Order total is above the COD maximum |
| 422 | `GOVERNORATE_NOT_AVAILABLE` | Delivery to that governorate is disabled |
| 422 | `REFUND_EXCEEDS_PAID` | Refund larger than the amount paid minus earlier refunds |
| 422 | `RETURN_WINDOW_CLOSED` | Return outside the window without an override reason |
| 422 | `IDEMPOTENCY_KEY_REUSED` | Same idempotency key sent with a different request |
| 422 | `INVALID_OR_EXPIRED_TOKEN` | Reset, verification or invite link is wrong, used or expired |
| 422 | `PRODUCT_NOT_ACTIVATABLE` | Activation rules not met; `details` lists what's missing (AD-02) |
| 429 | `RATE_LIMITED` | Too many attempts; includes a `Retry-After` header |
| 429 | `ACCOUNT_LOCKED` | Staff account temporarily locked after failed sign-ins (AD-01) |
| 502 | `PAYMENT_PROVIDER_ERROR` | Paymob returned an error or timed out; the order is kept and can be retried |
| 503 | `SERVICE_UNAVAILABLE` | A dependency the API needs (the database) isn't reachable; used by the health check (D-149) |
| 500 | `INTERNAL_ERROR` | Anything unexpected |

Sign-in failures always return the same `UNAUTHENTICATED` message whether the email exists or not (ST-07).

## 3. Pagination, filtering and sorting (D-124)

All list endpoints use numbered pages, matching the storefront's numbered pagination (D-054). With at most 500 products and a few thousand orders, page-number pagination is fast enough and simpler than cursor-based paging.

### Request parameters

| Parameter | Rule |
| --- | --- |
| `page` | Whole number from 1; default 1 |
| `pageSize` | Storefront fixed at 24 (D-054); admin default 25, allowed 10 to 100 |
| `sort` | One value from the endpoint's allowed list, e.g. `price_asc`; unknown values fall back to the default |
| Filters | Named query parameters per endpoint, e.g. `brand=glow-lab&inStock=true`. Repeated parameters mean "any of": `brand=a&brand=b` |
| `q` | Search text, trimmed, 2 to 100 characters (ST-04) |

### Response

```json
{
  "data": [ { "...": "..." } ],
  "meta": { "page": 2, "pageSize": 24, "totalItems": 61, "totalPages": 3 }
}
```

### Invalid values

- **Storefront:** invalid filters are ignored and an out-of-range page is clamped to the nearest valid page, never an error page (ST-05). `meta.page` returns the page actually shown, so the frontend can correct the URL.
- **Admin:** invalid values return `VALIDATION_FAILED`, because staff tools should be strict and explicit.

### Sort options

| Endpoint | Allowed `sort` values | Default |
| --- | --- | --- |
| Storefront products | `newest`, `price_asc`, `price_desc`, `best_selling` | `newest` |
| Admin products | `updated_desc`, `name_asc`, `stock_asc` | `updated_desc` |
| Admin orders | `created_desc`, `created_asc`, `total_desc` | `created_desc` |
| Admin customers | `created_desc`, `name_asc` | `created_desc` |
| Audit log | `created_desc` | `created_desc` |

Date filters (`from`, `to`) are calendar dates interpreted in Cairo time, so "today" in the dashboard means today in Egypt (D-045).

## 4. Authentication and permissions

Sessions travel in cookies set by the API and passed through each frontend's proxy, so the browser sees them as belonging to that frontend's address (D-072, D-073).

### Session cookies (D-125)

| Cookie | Set by | Attributes | Lifetime |
| --- | --- | --- | --- |
| `__Host-customer_session` | Storefront sign-in | `HttpOnly`, `Secure`, `SameSite=Lax`, `Path=/`, no `Domain` | 30 days, renewed while active (D-075) |
| `__Host-staff_session` | Dashboard sign-in | Same | 30 minutes idle, 12 hours maximum (AD-01) |

The `__Host-` prefix makes the browser refuse the cookie unless it is Secure, path `/` and tied to one exact address, so a cookie can't be planted from another subdomain. In local development over plain HTTP, the cookies drop the prefix and `Secure`.

### Rules on every request

1. Check the `Origin` header against the route group's frontend (section 1). Requests that change data must also be `application/json` (CSRF, D-076).
2. Resolve the session from the cookie: hash it, look it up, check expiry and, for staff, idle time and account status.
3. Check the endpoint's permission (admin) or the record's owner (storefront).
4. Validate the request with its Zod schema.

### Named permissions (D-126)

Each admin endpoint declares one permission. Roles map to permissions in one file (D-041), so a future Manager role is one new list.

| Permission | Allows | Staff | Admin |
| --- | --- | --- | --- |
| `catalog.read` | View products (including drafts), brands, categories | ✓ | ✓ |
| `catalog.write` | Create and edit products, variants, images, brands, categories | ✓ | ✓ |
| `inventory.adjust` | Stock adjustments and stock history | ✓ | ✓ |
| `orders.read` | View orders and their customer details | ✓ | ✓ |
| `orders.fulfil` | Status changes, tracking, address edits, returned-to-sender, COD collected | ✓ | ✓ |
| `orders.cancel` | Cancel before shipping | ✓ | ✓ |
| `refunds.manage` | Refunds and returns |  | ✓ |
| `customers.read` | Customer list and profiles |  | ✓ |
| `content.manage` | Banners and featured products | ✓ | ✓ |
| `shipping.read` | View governorates and fees | ✓ | ✓ |
| `shipping.write` | Edit fees, enabled governorates, free-shipping threshold |  | ✓ |
| `settings.manage` | Store settings |  | ✓ |
| `analytics.read` | Analytics page |  | ✓ |
| `exports.create` | CSV exports |  | ✓ |
| `staff.manage` | Invite, change role, deactivate staff |  | ✓ |
| `audit.read` | Audit log |  | ✓ |

Every signed-in staff member, whatever their role, can see the navigation counters and manage their own password, language and 2FA.

### Storefront access levels

| Level | Who | Example endpoints |
| --- | --- | --- |
| Public | Anyone | Catalog, home, checkout configuration, place order |
| Customer | Signed-in customer | Account, addresses, server cart, own orders |
| Guest token | Holder of the emailed order link | That one order: view, cancel, retry payment |

## 5. Idempotency, concurrency and rate limits

Three mechanisms make retries and simultaneous edits safe: idempotency keys for actions that create money or orders, version numbers for admin edits, and rate limits for endpoints attackers target.

### Idempotency keys (D-127)

The frontend generates a random UUID when the user starts the action and sends it as the `Idempotency-Key` header. A retry after a timeout or double-click reuses the same key, so the action happens once (BE-06).

| Endpoint | Key required | Effect of a repeat |
| --- | --- | --- |
| Place order | Yes | Returns the original response, including the same order |
| Retry card payment | Yes | Returns the same payment page URL |
| Switch to COD | Yes | Returns the same result |
| Create refund | Yes | Returns the same refund; also used as the provider's refund key |
| Record COD collected | Yes | Returns the same payment record |

Keys are stored for 24 hours. The same key with a different request body returns `IDEMPOTENCY_KEY_REUSED`.

### Version numbers for admin edits

Admin updates to products, variants, orders and settings include the `version` the screen loaded. If someone else saved in the meantime, the API returns `STALE_VERSION` and nothing is overwritten (AD-02, AD-05). The response to every successful update includes the new `version`.

### Price confirmation (D-128)

Placing an order includes `expectedTotal`: the total the customer saw. If the server's calculation differs because a price, fee or threshold changed, the API returns `PRICE_CHANGED` with a fresh quote instead of charging a different amount (ST-12).

### Rate limits (D-129, NFR-14)

Counters are stored in the database so they work across serverless instances (architecture section 6).

| Endpoint | Limit | Counted by |
| --- | --- | --- |
| Customer sign-in | 5 failures per 15 minutes | Email, and separately 20 per IP |
| Staff sign-in | 5 failures per 15 minutes, then 15-minute lock | Account, and separately 20 per IP |
| 2FA code | 5 failures per 15 minutes | Session |
| Password reset request | 3 per hour | Email, and 10 per IP |
| Registration | 5 per hour | IP |
| Resend verification email | 3 per hour | Customer |
| Place order | 10 per minute | IP (and customer if signed in) |
| Retry payment | 5 per order per 10 minutes | Order |
| Search and listing | 120 per minute | IP |

Responses beyond the limit return `RATE_LIMITED` with `Retry-After`. Limits are configuration values and will be checked in the security review (phase 12).

## 6. Storefront endpoints

All paths below start with `/api/v1/store`. Access levels are defined in section 4: Public, Customer, Guest token. Endpoints marked (key) need an `Idempotency-Key` header.

### Customer authentication

| Method | Path | Access | Purpose | Req |
| --- | --- | --- | --- | --- |
| POST | `/auth/register` | Public | Create account; optional `guestOrderToken` links a guest order (ST-16) | ST-07 |
| POST | `/auth/sign-in` | Public | Email and password sign-in; merges the sent guest cart lines (D-019) | ST-07 |
| POST | `/auth/sign-out` | Customer | End this session on the server | ST-07 |
| GET | `/auth/session` | Public | Current customer or `null` | ST-07 |
| GET | `/auth/google/start` | Public | Redirect to Google (Should) | ST-08 |
| GET | `/auth/google/callback` | Public | Finish Google sign-in (Should) | ST-08 |
| POST | `/auth/email-verification` | Public | Confirm email with token | ST-09 |
| POST | `/auth/email-verification/resend` | Customer | Send a new verification email | ST-09 |
| POST | `/auth/password-reset/request` | Public | Always returns 202, whether or not the email exists | ST-09 |
| POST | `/auth/password-reset/confirm` | Public | Set new password with token; ends other sessions | ST-09 |

### Account

| Method | Path | Access | Purpose | Req |
| --- | --- | --- | --- | --- |
| GET | `/account` | Customer | Profile | ST-10 |
| PATCH | `/account` | Customer | Update name and phone | ST-10 |
| POST | `/account/password` | Customer | Change password (current password required) | ST-10 |
| POST | `/account/email-change` | Customer | Request change; new address must be verified | ST-09 |
| POST | `/account/email-change/confirm` | Public | Confirm with token | ST-09 |
| GET | `/account/addresses` | Customer | List addresses | ST-10 |
| POST | `/account/addresses` | Customer | Add address (max 10) | ST-10 |
| PATCH | `/account/addresses/{id}` | Customer | Edit address | ST-10 |
| DELETE | `/account/addresses/{id}` | Customer | Delete address | ST-10 |
| POST | `/account/addresses/{id}/default` | Customer | Make default | ST-10 |
| DELETE | `/account` | Customer | Delete account; body has the password; blocked while orders are open | ST-11 |

### Catalog and home

| Method | Path | Access | Purpose | Req |
| --- | --- | --- | --- | --- |
| GET | `/home` | Public | Banners, featured products, 8 new arrivals, top categories, brands | ST-01 |
| GET | `/products` | Public | Listing and search: `q`, `category`, `brand`, `minPrice`, `maxPrice`, `inStock`, `sort`, `page` | ST-02, ST-04, ST-05 |
| GET | `/products/{slug}` | Public | Product page: options, variants with price and stock state, images. Archived returns 410 with related products | ST-03 |
| GET | `/categories` | Public | Two-level category tree | ST-02 |
| GET | `/brands` | Public | Active brands | ST-02 |
| GET | `/brands/{slug}` | Public | Brand details | ST-02 |

Stock is shown to customers as a state (`IN_STOCK`, `OUT_OF_STOCK`), not an exact count.

### Cart

| Method | Path | Access | Purpose | Req |
| --- | --- | --- | --- | --- |
| POST | `/cart/price` | Public | Price a list of `{ variantId, quantity }` lines: current prices, availability, capped quantities. Used for the guest browser cart | ST-06 |
| GET | `/cart` | Customer | Server cart, re-priced | ST-06 |
| PUT | `/cart/items/{variantId}` | Customer | Set quantity (1 to 10) | ST-06 |
| DELETE | `/cart/items/{variantId}` | Customer | Remove line | ST-06 |
| POST | `/cart/merge` | Customer | Merge browser cart lines into the server cart (D-019) | ST-06 |

### Checkout and orders

| Method | Path | Access | Purpose | Req |
| --- | --- | --- | --- | --- |
| GET | `/checkout/config` | Public | Enabled governorates with fees, free-shipping threshold, COD maximum | ST-12 |
| POST | `/checkout/quote` | Public | Totals for lines + governorate + payment method | ST-12 |
| POST | `/orders` (key) | Public | Place order (section 9.1) | ST-12, ST-13, ST-14 |
| GET | `/orders` | Customer | Own orders, newest first | ST-16 |
| GET | `/orders/{orderNumber}` | Customer | Own order details | ST-16 |
| GET | `/guest-orders/{token}` | Guest token | Order details for a guest | ST-16 |
| GET | `/orders/{orderNumber}/payment-status` | Customer or guest token | Return-page polling; triggers reconciliation (section 9.3) | ST-13, D-080 |
| POST | `/orders/{orderNumber}/payment-retry` (key) | Customer or guest token | New payment page URL (section 9.4) | ST-15 |
| POST | `/orders/{orderNumber}/switch-to-cod` (key) | Customer or guest token | Change an unpaid card order to COD | ST-15 |
| POST | `/orders/{orderNumber}/cancel` | Customer or guest token | Cancel while Awaiting payment or Confirmed | ST-17 |

Guest-token requests send the token in the `X-Order-Token` header, never in a URL that could end up in logs, except for the emailed link itself, which the storefront exchanges immediately.

## 7. Admin endpoints

All paths below start with `/api/v1/admin`. The Permission column names the permission from section 4; "Signed in" means any active staff member. Endpoints marked (key) need an `Idempotency-Key` header; endpoints marked (v) need the current `version`.

### Staff authentication and own account

| Method | Path | Permission | Purpose | Req |
| --- | --- | --- | --- | --- |
| POST | `/auth/sign-in` | Public | Email and password; returns `twoFactorRequired` when 2FA is on | AD-01 |
| POST | `/auth/two-factor` | Session without 2FA | Submit authenticator or recovery code | AD-16 |
| POST | `/auth/sign-out` | Signed in | End session | AD-01 |
| GET | `/auth/session` | Signed in | Current staff member, role, permissions, language | AD-01 |
| POST | `/auth/invites/accept` | Public | Set password from invite token | AD-12 |
| POST | `/auth/password-reset/request` | Public | Always 202 | AD-01 |
| POST | `/auth/password-reset/confirm` | Public | Set new password; ends other sessions | AD-01 |
| PATCH | `/me` | Signed in | Change own name and interface language (en, ar) | AD-15 |
| POST | `/me/password` | Signed in | Change own password | AD-12 |
| POST | `/me/two-factor/setup` | Signed in | Start 2FA: returns secret and QR data | AD-16 |
| POST | `/me/two-factor/confirm` | Signed in | Confirm first code; returns recovery codes once | AD-16 |
| GET | `/counters` | Signed in | New orders waiting, low-stock variants | AD-10 |

### Catalog

| Method | Path | Permission | Purpose | Req |
| --- | --- | --- | --- | --- |
| GET | `/products` | `catalog.read` | List with `q` (name or SKU), `brand`, `category`, `status`, `stock` (in, low, out) | AD-02 |
| POST | `/products` | `catalog.write` | Create draft product | AD-02 |
| GET | `/products/{id}` | `catalog.read` | Full product with options, variants, images | AD-02 |
| PATCH | `/products/{id}` (v) | `catalog.write` | Edit name, description, brand, category, slug | AD-02 |
| POST | `/products/{id}/status` (v) | `catalog.write` | Activate, archive or return to draft; activation rules checked | AD-02 |
| DELETE | `/products/{id}` | `catalog.write` | Hard delete a never-sold draft; otherwise `IN_USE` | AD-02 |
| PUT | `/products/{id}/options` (v) | `catalog.write` | Set options (Shade, Size, Scent) and their values | AD-02 |
| POST | `/products/{id}/variants` | `catalog.write` | Add variant (SKU, price, option values, initial stock 0) | AD-02 |
| PATCH | `/variants/{id}` (v) | `catalog.write` | Edit SKU, price, enabled, image | AD-02 |
| POST | `/variants/{id}/archive` | `catalog.write` | Archive variant | AD-02 |
| POST | `/products/{id}/images` | `catalog.write` | Upload one image (multipart, max 4 MB) | AD-02, BE-10 |
| PATCH | `/images/{id}` | `catalog.write` | Edit alt text | AD-02 |
| PUT | `/products/{id}/images/order` | `catalog.write` | Reorder; first is the main image | AD-02 |
| DELETE | `/images/{id}` | `catalog.write` | Delete image and its files | AD-02 |
| GET, POST | `/brands` | `catalog.read`, `catalog.write` | List, create | AD-03 |
| PATCH, DELETE | `/brands/{id}` | `catalog.write` | Edit, archive or delete if unused | AD-03 |
| GET, POST | `/categories` | `catalog.read`, `catalog.write` | Tree, create (two levels) | AD-03 |
| PATCH, DELETE | `/categories/{id}` | `catalog.write` | Edit, archive or delete if unused | AD-03 |

### Inventory

| Method | Path | Permission | Purpose | Req |
| --- | --- | --- | --- | --- |
| POST | `/variants/{id}/stock-adjustments` | `inventory.adjust` | Adjust with reason (section 9.6) | AD-04 |
| GET | `/variants/{id}/stock-movements` | `inventory.adjust` | Stock history | AD-04 |
| GET | `/inventory/low-stock` | `catalog.read` | Variants at or below the threshold | AD-04 |

### Orders, refunds and returns

| Method | Path | Permission | Purpose | Req |
| --- | --- | --- | --- | --- |
| GET | `/orders` | `orders.read` | Filters: `status`, `paymentStatus`, `paymentMethod`, `from`, `to`, `governorate`, `q` | AD-05 |
| GET | `/orders/{id}` | `orders.read` | Details with payments, refunds, returns, history | AD-05 |
| POST | `/orders/{id}/transitions` (v) | `orders.fulfil` | Move to Processing, Shipped (tracking required), Delivered (section 9.5) | AD-05 |
| PATCH | `/orders/{id}/delivery` (v) | `orders.fulfil` | Edit address and phone until shipped | AD-05 |
| POST | `/orders/{id}/cancel` (v) | `orders.cancel` | Cancel before shipping; auto-refund for paid card orders | AD-05 |
| POST | `/orders/{id}/cod-collected` (key) | `orders.fulfil` | Record COD cash received | AD-05 |
| POST | `/orders/{id}/returned-to-sender` (v) | `orders.fulfil` | Record that a refused or undeliverable parcel came back; sets Returned to sender and returns the stock | AD-05 |
| POST | `/orders/{id}/refunds` (key) | `refunds.manage` | Full or partial refund (section 9.7) | AD-06 |
| POST | `/orders/{id}/returns` | `refunds.manage` | Record a return with restock or write-off per item | AD-06 |

### Customers, shipping, content and settings

| Method | Path | Permission | Purpose | Req |
| --- | --- | --- | --- | --- |
| GET | `/customers` | `customers.read` | List with search | AD-09 |
| GET | `/customers/{id}` | `customers.read` | Profile, addresses, orders | AD-09 |
| GET | `/shipping` | `shipping.read` | Governorates, fees, threshold | AD-07 |
| PATCH | `/shipping/governorates/{code}` | `shipping.write` | Fee and enabled flag | AD-07 |
| PATCH | `/shipping/free-shipping` | `shipping.write` | Threshold or off | AD-07 |
| GET, POST | `/banners` | `content.manage` | List, create | AD-08 |
| PATCH, DELETE | `/banners/{id}` | `content.manage` | Edit, delete | AD-08 |
| PUT | `/featured-products` | `content.manage` | Set the ordered list (max 12) | AD-08 |
| GET | `/settings` | `settings.manage` | Store settings | AD-13 |
| PATCH | `/settings` (v) | `settings.manage` | Update settings | AD-13 |

### Staff, analytics, exports and audit

| Method | Path | Permission | Purpose | Req |
| --- | --- | --- | --- | --- |
| GET | `/staff` | `staff.manage` | Staff list | AD-12 |
| POST | `/staff/invites` | `staff.manage` | Invite by email with role | AD-12 |
| POST | `/staff/{id}/invite/resend` | `staff.manage` | New invite link | AD-12 |
| PATCH | `/staff/{id}` | `staff.manage` | Change role (last-Admin rule) | AD-12 |
| POST | `/staff/{id}/deactivate` | `staff.manage` | Deactivate; ends sessions | AD-12 |
| POST | `/staff/{id}/reactivate` | `staff.manage` | Reactivate | AD-12 |
| GET | `/analytics/summary` | `analytics.read` | Revenue, orders, average order value, by status, top products, new customers for `from` to `to` | AD-10 |
| GET | `/analytics/revenue-series` | `analytics.read` | Daily revenue for the chart | AD-10 |
| GET | `/exports/orders.csv` | `exports.create` | CSV with filters; formula-safe cells | AD-11 |
| GET | `/exports/inventory.csv` | `exports.create` | CSV of all variants | AD-11 |
| GET | `/audit-logs` | `audit.read` | Filters: `staffId`, `action`, `from`, `to` | AD-14 |

## 8. Integration endpoints

These endpoints are called by machines, not browsers, so they skip the Origin check and authenticate with a signature or a secret instead.

| Method | Path | Called by | Authentication | Purpose |
| --- | --- | --- | --- | --- |
| POST | `/api/v1/webhooks/paymob` | Paymob | HMAC signature verified against the raw body (R-001) | Payment and refund events (section 9.2) |
| GET | `/api/v1/jobs/daily` | Vercel Cron | `Authorization: Bearer <CRON_SECRET>` | Expire unpaid orders, retry failed emails, delete expired tokens and sessions, send low-stock summary (D-084) |
| GET | `/api/v1/health` | Uptime checks | None | `{ "status": "ok", "database": "ok" }`; no other details. Database unreachable or slower than 2 seconds: 503 `SERVICE_UNAVAILABLE` in the standard error format (D-149) |

Rules for the webhook endpoint:

- It reads the **raw request body** before any JSON parsing, because the signature is calculated on the exact bytes.
- It returns **200 quickly** once the event is safely stored, so Paymob doesn't retry while we're still processing.
- An **invalid signature** returns 401 and is logged with the request ID, but the payload is not processed.
- A **duplicate event** returns 200 without processing it again (D-115).

The daily job is safe to run twice and safe to miss (BE-12); a request without the correct secret returns 401.

## 9. Detailed contracts for critical endpoints

These seven endpoints move money or stock, so their full request, response and error behavior is fixed here. The remaining endpoints follow the same conventions, and their exact schemas are written as Zod schemas during implementation.

### 9.1 Place order: `POST /api/v1/store/orders`

**Headers:** `Idempotency-Key` (required). **Access:** Public; uses the customer session if present.

```json
{
  "items": [ { "variantId": "0192f3a1-7c2e-7b10-9a1e-3f5c2d8e4b01", "quantity": 2 } ],
  "contact": { "name": "Nour Hassan", "email": "nour@example.com", "phone": "01012345678" },
  "address": {
    "recipientName": "Nour Hassan", "phone": "01012345678", "governorateCode": "CAI",
    "cityArea": "Maadi", "street": "Road 9", "building": "12", "floor": "3", "apartment": "7", "landmark": null
  },
  "paymentMethod": "CARD",
  "note": "Please call before arriving",
  "expectedTotal": { "amount": "760.00", "currency": "EGP" }
}
```

**Validation:** 1 to 50 lines with distinct variants; quantity 1 to 10; phone matches `^01[0125][0-9]{8}$`; valid email; names 1 to 100 characters; note up to 500. Signed-in customers may send `savedAddressId` instead of `address`. Prices are never accepted from the client (R-002).

**201 Created (card):**

```json
{
  "data": {
    "order": {
      "id": "0192f3b0-...", "orderNumber": "100245", "status": "AWAITING_PAYMENT",
      "paymentStatus": "UNPAID", "paymentMethod": "CARD",
      "subtotal": { "amount": "700.00", "currency": "EGP" },
      "shippingFee": { "amount": "60.00", "currency": "EGP" },
      "total": { "amount": "760.00", "currency": "EGP" },
      "expiresAt": "2026-10-08T15:00:00Z"
    },
    "nextAction": { "type": "REDIRECT_TO_PAYMENT", "url": "https://accept.paymob.com/..." },
    "guestOrderToken": "k3Jw..."
  }
}
```

| `nextAction.type` | When | Storefront does |
| --- | --- | --- |
| `REDIRECT_TO_PAYMENT` | Card order, payment page created | Redirect to `url` |
| `SHOW_CONFIRMATION` | COD order (status Confirmed) | Show the confirmation page |
| `PAYMENT_UNAVAILABLE` | Card order saved, but Paymob couldn't be reached | Show "retry payment" (9.4) |

`guestOrderToken` is returned only for guest orders, and only in this response; it's also in the confirmation email. The server stores only its hash (D-116).

**Errors:** `VALIDATION_FAILED`; `OUT_OF_STOCK` (details: `variantId`, `requested`, `available`); `PRICE_CHANGED` (details: a fresh quote); `COD_NOT_AVAILABLE`; `GOVERNORATE_NOT_AVAILABLE`; `IDEMPOTENCY_KEY_REUSED`; `RATE_LIMITED`.

### 9.2 Payment webhook: `POST /api/v1/webhooks/paymob`

The Paymob adapter turns the provider's payload into one of our own events; the payments service only sees these:

| Our event | Order is Awaiting payment | Order already Cancelled (expired) | Already processed |
| --- | --- | --- | --- |
| `PAYMENT_SUCCEEDED` (amount matches) | Confirmed, Paid; confirmation email | Try to re-reserve stock: confirm if possible, otherwise automatic refund and Admin alert (BE-07) | Ignored, 200 |
| `PAYMENT_SUCCEEDED` (amount differs) | Payment recorded, order flagged for Admin review; no confirmation | Same flag | Ignored, 200 |
| `PAYMENT_FAILED` | Payment row Failed; order stays Awaiting payment; failure email | Recorded only | Ignored, 200 |
| `REFUND_SUCCEEDED` | Refund Succeeded; payment status Partially refunded or Refunded; refund email | Same | Ignored, 200 |
| `REFUND_FAILED` | Refund Failed; Admin alert | Same | Ignored, 200 |

### 9.3 Payment status: `GET /api/v1/store/orders/{orderNumber}/payment-status`

Polled every 2 seconds by the return page, for up to 60 seconds.

```json
{ "data": { "orderNumber": "100245", "status": "AWAITING_PAYMENT", "paymentStatus": "UNPAID", "result": "PENDING" } }
```

`result` is `PENDING`, `SUCCEEDED` or `FAILED`. If the order has been waiting more than 10 seconds without a webhook, the server asks Paymob for the status itself, at most once every 10 seconds per order (D-080). The browser's word is never trusted (R-001).

### 9.4 Retry payment: `POST /api/v1/store/orders/{orderNumber}/payment-retry`

**Headers:** `Idempotency-Key`. **Allowed when** the order is Awaiting payment and not past `expiresAt`. Creates a new payment row (D-115) and returns `{ "nextAction": { "type": "REDIRECT_TO_PAYMENT", "url": "..." } }`. Retrying doesn't extend the 30-minute window (D-014).

**Errors:** `ORDER_ALREADY_PROCESSED` (paid, cancelled or expired), `PAYMENT_PROVIDER_ERROR`, `RATE_LIMITED`.

### 9.5 Order transition: `POST /api/v1/admin/orders/{id}/transitions`

```json
{ "to": "SHIPPED", "courierName": "Courier Co", "trackingNumber": "CC123456789EG", "note": null, "version": 4 }
```

| From | `to` | Extra fields | Side effects |
| --- | --- | --- | --- |
| Confirmed | `PROCESSING` | none | History row |
| Processing | `SHIPPED` | `courierName`, `trackingNumber` required | Shipped email |
| Shipped | `DELIVERED` | none | History row |

Cancelling and returned-to-sender have their own endpoints because they move stock and money. **200** returns the updated order with its new `version`. **Errors:** `INVALID_STATUS_TRANSITION`, `STALE_VERSION`, `VALIDATION_FAILED`, `FORBIDDEN`.

### 9.6 Stock adjustment: `POST /api/v1/admin/variants/{id}/stock-adjustments`

```json
{ "change": 12, "reason": "RECEIVED", "note": "Supplier delivery", "expectedStock": 3 }
```

| `reason` | Allowed `change` |
| --- | --- |
| `RECEIVED` | Positive |
| `DAMAGED` | Negative |
| `CORRECTION` | Positive or negative; `note` required |

`expectedStock` is the number the staff member was looking at; if stock changed since (for example an order was placed), the API returns `STALE_VERSION` instead of applying the change to a number they didn't see. **201** returns the new `stockQuantity` and the stock movement. **Errors:** `VALIDATION_FAILED` (zero change, wrong sign, result below 0), `STALE_VERSION`.

### 9.7 Refund: `POST /api/v1/admin/orders/{id}/refunds`

**Headers:** `Idempotency-Key`. **Permission:** `refunds.manage` (Admin only).

```json
{ "amount": { "amount": "350.00", "currency": "EGP" }, "method": "PROVIDER", "reason": "Damaged on arrival", "returnId": null }
```

| Order paid by | Allowed `method` | Result |
| --- | --- | --- |
| Card or wallet | `PROVIDER` | Refund Pending until Paymob's webhook confirms it |
| COD | `BANK_TRANSFER`, `WALLET_TRANSFER`, `CASH` with a `reference` note | Refund recorded as Succeeded immediately |

**201** returns the refund. **Errors:** `REFUND_EXCEEDS_PAID` (includes the refundable amount), `VALIDATION_FAILED`, `PAYMENT_PROVIDER_ERROR` (the refund is marked Failed and can be retried with a new key). Every refund is audit-logged (D-031).

## 10. Decisions (approved)

Approving these completes phase 3. The contracts are then written as Zod schemas in `packages/shared` during implementation, and the OpenAPI document is generated from them.

| ID | Decision | Section |
| --- | --- | --- |
| D-121 | Four route groups under `/api/v1`; storefront and admin groups accept requests only from their own frontend's address | 1 |
| D-122 | Response envelope (`data`, `meta`, `error`), camelCase fields, money as `{ amount: "0.00", currency }`, ISO 8601 UTC times | 1 |
| D-123 | One error format with `code`, `message`, `details`, `requestId`, and the error code catalog | 2 |
| D-124 | Page-number pagination with `meta`; storefront corrects invalid values, admin rejects them | 3 |
| D-125 | `__Host-customer_session` and `__Host-staff_session` cookies: HttpOnly, Secure, SameSite=Lax | 4 |
| D-126 | The 16 named permissions and their Staff and Admin mapping | 4 |
| D-127 | `Idempotency-Key` header on place order, retry payment, switch to COD, refunds and COD collection; kept 24 hours | 5 |
| D-128 | Stale-data guards: `expectedTotal` when ordering, `version` on admin edits, `expectedStock` on stock adjustments | 5, 9 |
| D-129 | Rate limit values in section 5 | 5 |
| D-130 | Checkout returns a `nextAction`; fulfilment steps share one transitions endpoint, while cancel, returned-to-sender and refunds have their own | 7, 9 |

- [x] D-121 to D-130 approved
- [x] This document approved as the API contract for release 1.0
