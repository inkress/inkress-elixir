# 1. Single `inkress` Elixir SDK — no admin/storefront package split

Date: 2026-09-01

## Status

Accepted

## Context

Inkress ships client SDKs per language. The JavaScript/TypeScript family is split
into **two** packages:

- `@inkress/storefront-sdk` — runs in the **browser**: publishable key (`pk_…`) and
  customer tokens, for storefront/public operations (product browsing, cart,
  wishlist, customer auth).
- `@inkress/admin-sdk` — runs **server-side**: secret key (`sk_…`), for
  management/admin operations (creating orders, webhooks, custom pricing).

When building the **Elixir** SDK, the question arose: should it mirror that split —
e.g. a package `inkress_admin` with modules under `Inkress.Admin.*`, leaving room for
a future `inkress_storefront` / `Inkress.Storefront.*`?

The functionality built first (order creation, `sk_live_`-gated custom pricing,
webhook verification with the webhook secret) is squarely the **admin/server**
surface, which is what prompted the question.

## Decision

**One Elixir package, `inkress`, with all modules under `Inkress.*`.** No
admin/storefront package split.

- Server-side secret-key operations live at the natural top level:
  `Inkress.Orders`, `Inkress.Webhooks`, `Inkress.Client`, etc.
- Repository: `inkress/inkress-elixir`.
- **If** a public/storefront API surface is ever needed from Elixir (e.g. a
  server-rendered storefront or backend-for-frontend calling products/cart with the
  publishable key), it is added as `Inkress.Storefront.*` **within this same
  package** — not as a separate package.

## Rationale

The JS `admin`/`storefront` split is driven by a **runtime + security boundary**:
`storefront-sdk` must run in the browser and therefore must never hold the secret
key; `admin-sdk` is server-only. It is fundamentally a client/server division.

**Elixir has no browser runtime.** Every line of an Elixir SDK runs server-side and
can safely hold the secret key. The primary driver of the JS split is simply absent.

What remains is a weaker distinction — two API *surfaces* / credential types. That is
real, but it does not justify separate **packages** in Elixir:

- Elixir libraries are conventionally broader than npm packages; fragmenting one SDK
  into two runs against the grain of the ecosystem.
- A single Phoenix app may legitimately need both surfaces; two packages would mean
  pulling both anyway.
- Mirroring the split would add an `Admin.` qualifier to **every** call site
  (`Inkress.Admin.Orders.create/2`) to express a distinction that does not exist in a
  server-only ecosystem — redundant noise.

Cross-language brand parity (wanting every language to literally have an
"admin-sdk") is a **branding preference, explicitly not a goal** for this SDK.

## Consequences

- Idiomatic, concise call sites: `Inkress.Orders.create/2`,
  `Inkress.Webhooks.verify/2`.
- The `Inkress.Storefront.*` namespace is **reserved** for future public-surface
  helpers, should they ever be needed — without a package split.
- This SDK is understood to be **server-side by nature** (it holds secret keys). That
  is communicated in the README, not in the module namespace.
- Should Inkress later mandate cross-language naming parity, this can be revisited —
  but that is a branding decision, and the cost (renaming every module + the repo)
  should be weighed against the benefit. Supersede this ADR rather than editing it.

## Alternatives considered

- **`inkress_admin` package + `Inkress.Admin.*` modules + repo
  `inkress-admin-sdk-elixir`** (mirror the JS family). Rejected: it imports a
  runtime-driven boundary that does not apply to server-only Elixir, fragments the
  SDK, and adds a redundant qualifier to every call site.
