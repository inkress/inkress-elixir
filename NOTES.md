# Build notes / decisions

Durable log so any future session can resume from disk alone.

## Scope (approved 2026-09-01)
Thin, idiomatic Elixir wrapper for the Inkress API. **Only** two concerns:
1. **Order creator** — `Inkress.Orders.create/2` → `POST /api/v1/orders`.
2. **Webhook handler** — `Inkress.Webhooks.verify/2` (verify signature *inside* the function).

Decided out of scope (per user): hosted-checkout URL builder, Plug helper, order
read/list/cancel, any other resources.

## Key API facts (traced from the real commerce-api, not just docs)
- Base URL: `https://api.inkress.com` (live) / `https://api-dev.inkress.com` (sandbox). Path prefix `/api/v1`.
- Auth: `Authorization: Bearer <token>` + `Client-Id: m-<merchant_username>`.
- Response envelope: `{ "state": "ok"|"error", "data": ..., "result": ... }`.
- Order create body: `{ currency_code, kind, reference_id?, total?, title?, customer:{email,first_name,last_name,phone?}, products:[{id,quantity,price?}], data:{shipping_address?} }`.
- **Webhook signature**: header `x-inkress-signature: <JWT>`. The JWT is **HS256**, signed
  with the app's `whsec_…` webhook secret, and its **claims ARE the event payload**
  (signer header carries `kid` = client_id). Confirmed in
  `commerce-api/lib/api/workers/services/accounts/subscriptions.ex` (`generate_jwt`)
  and `commerce-api/lib/api/utils/verify.ex` (`decode_and_verify`) — both use **Joken**.
  (Some stale docs show HMAC-hex; the live code is Joken JWT. Match the code.)
- Event `type` values: merchant.registered, order.created, order.paid, order.failed,
  order.cancelled, payment.authorized, payment.captured, payment.failed.
  (Subscription-billing webhooks omit `type` — verify/2 must tolerate that → `:unknown`.)

## Toolchain decision (important)
- Pinned to **Elixir 1.15.8-otp-26** via `.tool-versions` (same OTP 26 as the house
  commerce-api, which itself targets 1.14.5-otp-26).
- Why not 1.14.5 (house default)? The secure **hpax 1.0.4** (fixes HIGH CVE-2026-58226,
  HPACK DoS) requires Elixir ~> 1.15. hpax ≤1.0.3 compiles on 1.14 but carries that HIGH
  CVE. Since finch→mint→hpax always pulls hpax, **there is no secure Finch/Mint stack on
  Elixir 1.14**. 1.15.8 was already installed, same OTP, so we use it. `mix hex.audit` is clean.
- Fallback if a strict 1.14.5 consumer is ever required: swap the default HTTP adapter to a
  hackney-based one (HTTPoison) — hackney avoids mint/hpax entirely. The HTTP layer is a
  behaviour (`Inkress.HTTPClient`) precisely so this swap is a one-module change.

## Deps
finch ~> 0.18 (→0.23), joken ~> 2.6.0 (→2.6.2), jason ~> 1.4. All secure; audit clean.

## Design (modules)
- `Inkress` — facade: `new/1`, `create_order/2`, `verify_webhook/2`.
- `Inkress.Client` — `%Client{}` config struct, `new/1`, header/URL building, mode→base_url.
- `Inkress.HTTPClient` — behaviour (adapter contract): `request(request, opts)`.
- `Inkress.HTTPClient.Finch` — default adapter (Finch).
- `Inkress.HTTP` — internal dispatch (build url/headers/json + call adapter) + envelope unwrap.
- `Inkress.Orders` — `create/2`.
- `Inkress.Order` — typed struct + `from_map/1`.
- `Inkress.Webhooks` — `verify/2` (Joken HS256).
- `Inkress.Webhook.Event` — typed struct + `from_claims/1`.
- `Inkress.Webhook.EventType` — enum (string ↔ atom), `parse/1`, `to_string/1`, `all/0`.
- `Inkress.Error` — typed error struct.
- `Inkress.Application` — supervises `{Finch, name: Inkress.Finch}`.

## Progress
- [x] Scaffold, deps, toolchain, clean audit
- [x] EventType (TDD) — 5 tests
- [x] Webhooks.verify (TDD) — 8 tests
- [x] Client.new + headers (TDD) — 8 tests
- [x] Orders.create (TDD) — 11 tests (stub HTTP adapter)
- [x] Facade (Inkress.new/create_order/verify_webhook) + doctest — 2 tests + 1 doctest
- [x] Application supervises {Finch, name: Inkress.Finch}
- [x] README
- [x] Green: 1 doctest + 34 tests, 0 failures; `mix format --check-formatted` OK;
      `mix compile --warnings-as-errors` OK; `mix hex.audit` clean.

DONE — complete and verified 2026-09-01.

## Follow-up: custom pricing (2026-09-01)
- Investigated whether commerce-api honors caller-supplied per-line prices → NO; it
  re-prices from the catalog (`processor.ex:833-837`, `validate_total`). Only open-amount
  (no-products) orders use the caller's total.
- Decision: ship **Design A** (trusted server-side `unit_price` override) first; roadmap
  **Design B** (signed quote tokens) for hosted-checkout/client-crossing. Full design in
  `docs/custom-pricing-design.md`.
- [x] Wrapper: `Inkress.Orders.create_open_amount/2` (open-amount convenience) — 4 tests, TDD.
- [~] commerce-api Design A — IN PROGRESS on worktree `_worktrees/capi-custom-pricing`
      (branch `feat/order-trusted-unit-price` off origin/version/4.1-beta).
      - DONE + unit-tested (8/8, pure): `price_override_allowed?/1`, `resolve_unit_price/3`,
        and `fetch_products/1` wiring + audit stamp. Compiles clean; non-override byte-identical.
      - REMAINING: the `secret_key_auth` signal from the auth layer (security-critical; needs a
        decision — extend `Principal` vs a plug). See `capi-custom-pricing/CUSTOM_PRICING_HANDOFF.md`.
      - Trust gate = `sk_live_` secret key (owner confirmed). Integration test blocked by a
        pre-existing duplicate migration (20260105161800) on 4.1-beta.
- [ ] Wrapper: type/doc `unit_price` passthrough once A lands.
- [ ] Design B (roadmap).
