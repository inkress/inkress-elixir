# Custom pricing for orders — design & roadmap

Status: **A chosen for v1; B roadmapped.** Decided 2026-09-01. No code written yet
(commerce-api money-logic change pending trust-gate confirmation — see Open Questions).

## Problem

`POST /api/v1/orders` re-prices every product line from the catalog. `fetch_products/1`
does `Map.merge(caller, catalog_record)` then `Map.put(:price, total_cost)` — so a
caller-supplied per-line price is discarded (evidence:
`commerce-api/lib/api/services/orders/processor.ex:833-837`), and `validate_total/2`
recomputes the order total from catalog costs, ignoring the caller's `total` when products
are present. The only merchant-set-amount path today is an **open-amount order** (a `total`
with no `products`). Use case driving this: **dynamic / quoted pricing** — the merchant's
backend computes a per-order price that may be above *or* below list.

Rejected idea: `price = max(supplied, catalog)`. It silently overcharges, blocks the common
"discount below list" case, and is a magnitude proxy for what is really a *trust* question.

## Trust model (grounded in the code)

- The order endpoint is multi-credential; merchant identity comes from tenant context
  (`Repo.get_merchant_id()`), set by auth plugs, not params (`processor.ex#fetch_merchant`).
- `Api.Auth.Principal` (`lib/api/auth/principal.ex`) is the credential abstraction, with
  `source :: :service | :oauth | :embedded_jwt | :session | :anonymous`.
  - `:service` = internal Inkress **bot key** (least-privilege via `BotPolicy`) — NOT a merchant key.
  - `:oauth` = OAuth integration bearer (`inka_` tokens; apps acting for an org).
  - `:embedded_jwt` / `:session` = storefront / hosted / logged-in (client-influenced).
- A `USE_PRINCIPAL_AUTH` rollout is in flight (principal as single source of truth).

## Design A — trusted server-side `unit_price` override (v1)

One step for the developer: their backend sends the price directly on order creation.

- **Field:** explicit per-line `unit_price` (do NOT overload `price`). Optional `product_id`
  (quotes may be for ad-hoc/service items not in the catalog).
- **Trust gate:** honor `unit_price` ONLY when the request is a trusted merchant server-side
  credential (the `Principal.source` value confirmed in Open Questions). All other sources →
  ignore `unit_price`, keep catalog re-pricing (unchanged behavior).
- **Processor:** a `resolve_priced_products/1` branch that, for the trusted credential, builds
  the product-map shape `create_order_lines/1` already expects using `unit_price` instead of
  the catalog merge; `validate_total/2` sums supplied prices (mirror the existing
  `kind == "subscription"` bypass); frozen line price = supplied price.
- **Audit (required):** stamp `line_meta_data` with `price_source: "override"`, and the catalog
  price snapshot when `product_id` is present, so finance/support can always explain the amount.
- **Backward-compat:** no `unit_price` or non-trusted credential → today's catalog behavior.

Limitation (why B exists): safe only server-to-server. A price posted from an untrusted client
must not be honored — that's Design B.

## Design B — signed quote tokens (roadmap)

For quotes that must survive a hop through the customer's browser (hosted checkout).

- `POST /api/v1/quotes` (secret-key only) → priced line items → returns a **signed quote token**
  (Joken HS256, the inverse of the existing webhook JWT pattern) + `quote_id` + optional
  `checkout_url`.
- `POST /api/v1/orders` accepts `quote_token`; verifies signature + `exp` + single-use, prices
  lines from the quote (bypassing catalog), uses the quote total.
- Leans: **persist** quotes (single-use + revocation + reporting; a bare signed token is a
  replayable "charge me $X"); **platform signing key** (Inkress issues + verifies, so redemption
  needn't resolve a per-merchant secret first); **reuse the `order_invoice` (kind 4)** semantics.
- Deferred because it doubles the developer's per-transaction work (issue quote → create order).

## Wrapper (inkress-elixir) impact

- **Now (safe, independent):** open-amount order convenience — `create/2` guards that a positive
  `total` is present when there are no `products`/`quote_token`; optional `create_open_amount/2`.
- **With A:** `Orders.create/2` already passes `unit_price` through; add typing + docs once the
  server honors it.
- **With B:** add `Inkress.Quotes.create/2` + `Inkress.Quote`, and `quote_token` on order create.

## Trust gate — RESOLVED (2026-09-01)

Merchants authenticate server-side with their **`sk_live_` secret key** (confirmed by owner).
`Context.Auth.is_token_valid?/1` (`lib/api/context/auth/auth.ex:53`) already looks the token up
by value and parses the `sk` vs `pk` prefix — but **only to enforce live/test mode**, not to gate
capabilities. So the signal exists; it just isn't surfaced to the order processor. `Principal.source`
does NOT currently distinguish `sk_` from `pk_` (both resolve a Token → `:session`/`:embedded_jwt`),
so A must add a small, explicit "secret-key auth" signal rather than reuse `source`.

Gate = **the authenticating token is a secret key** (prefer a structural check — the Token record's
`kind`, or that the value matched the `private_key` column — over string-prefix; confirm in step 1).

## Design A — implementation plan

1. **Surface the signal.** In the auth layer, when the request authenticates via the secret key,
   stamp a flag reachable by the processor (e.g. `conn.private[:secret_key_auth]` threaded into the
   order params, or a `confidential?` field on `Principal`). Step 1 also confirms whether `Token.kind`
   / a `private_key` match is the reliable structural signal (preferred over the `sk_` string prefix).
2. **Honor `unit_price` behind the gate.** In `processor.ex`, add `resolve_priced_products/1`: when
   `secret_key_auth?` AND a line carries `unit_price`, build the line from `unit_price` (skip the
   `Map.merge(catalog)` + `Map.put(:price, total_cost)` override at `processor.ex:833-837`); otherwise
   fall through to today's catalog pricing. Mirror in `validate_total/2` (sum supplied prices, like the
   existing `kind == "subscription"` bypass) and `create_order_lines/1` (frozen price = `unit_price`).
3. **Audit.** Stamp `line_meta_data.price_source = "override"` + the catalog price snapshot (when
   `product_id` given). 4. **Tests (TDD):** secret-key + `unit_price` honored; non-secret credential
   ignores it (catalog); mixed lines; total reconciliation; audit stamp present.
   5. **Backward-compat:** no `unit_price` or non-secret credential → byte-identical to today.

Stakes: production payments + auth. Land as its own branch/PR through commerce-api's review.

## Roadmap

- Design B (signed quote tokens) — for hosted-checkout / client-crossing quotes. See above.
