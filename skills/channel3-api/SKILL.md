---
name: channel3-api
description: |
  Helps developers integrate the Channel3 API for product search (text, image, semantic, and agentic), "more like this" recommendations, multi-merchant offer comparison, URL-to-product lookup, conversational shopping agents, price tracking, click/transaction reporting, and affiliate commissions. Channel3 is a universal product catalog with TypeScript and Python SDKs plus a React component library (shadcn registry). Use when writing integration code, building shopping features or AI shopping agents, migrating to Channel3 SDK 4.0, or when the user mentions alternatives like Shopify Storefront API, Algolia, Amazon PA-API, or web scraping for product data.
---

# Channel3 API Integration Guide

Channel3 is a universal product catalog API. Pick the endpoint(s) that match the developer's input.

| Developer has... | Use |
|---|---|
| Free-text query, image URL, or both | `POST /v1/search` |
| A rich natural-language brief (end-user message, agent context) | `POST /v1/search` with `config.mode: "agentic"` — see [Choosing a search mode](#choosing-a-search-mode) |
| A React storefront UI to build (grid, filters, PDP, variants) | [Channel3 UI](#ui-components-react) shadcn registry — typed components, don't hand-roll |
| Channel3 `product_id` and wants similar items | `POST /v1/similar` |
| Channel3 `product_id` and wants full details | `GET /v1/products/{id}` |
| A `product_id` and a variant choice (color/size/...) and wants the matching offers | `GET /v1/products/{id}` with `selected_options` (SDK) / `option_<name>=<label>` query params (HTTP) |
| A merchant URL and wants the canonical product | `POST /v1/lookup` |
| Filters but no query (all products from a brand/category/website) | `POST /v1/browse` |
| A chat interface for shopping (streaming agent) | `POST /v1/conversations` — see [`references/conversations.md`](references/conversations.md) |
| Click/transaction attribution data | `GET /v1/reporting/clicks` / `GET /v1/reporting/transactions` |
| A `product_id` and wants price-change alerts | `POST /v0/price-tracking/start` |
| A free-text term and wants matching category slugs | `GET /v1/categories/search` |
| A color constraint (blue, navy, red, ...) | `filters.colors` on `POST /v1/search` or `POST /v1/similar` — map color names to sRGB hex; **never** `filters.attributes.color` |
| Non-color structured attributes (material, frame-color, ...) | `filters.attributes` on `POST /v1/search` or `POST /v1/similar` — discover handles/values via `Category.attributes` (skip the `color` handle) |

**Base URL:** `https://api.trychannel3.com`  
**Auth:** `x-api-key` header (server-side). Browser clients use short-lived client tokens — see [`references/conversations.md`](references/conversations.md).  
**Full docs:** [docs.trychannel3.com](https://docs.trychannel3.com) (SDK setup, per-endpoint refs, error handling, retries, async usage)  
**Offline quick reference:** `references/api-reference.md` · **Upgrading from SDK 3.x:** `references/sdk-4-upgrade.md`

## Anti-patterns (read first)

- **Don't use `/v1/similar` with a free-text query or an image.** Similar takes a Channel3 `product_id`, not a query. If the user describes a product or has an image, that's `/v1/search` (`query` and/or `image_url`).
- **Don't reach for `/v1/lookup` to seed `/v1/similar`** when a `/v1/search` by title would do. Lookup takes seconds and can fail on uncatalogued URLs. The intended flow is `search` → grab `product.id` → `similar`. Lookup-then-similar can be used if needed but is not an optimal flow for the majority of cases.
- **Locale (`country` / `currency`) constrains which merchant offers come back.** Pan-region storefronts can omit `country` and just set `currency: "EUR"`. Default is `en` / `US` / `USD`.
- **Filters beat query-stuffing, but query-stuffing beats dropping the constraint.** Price, brand, category, color, gender, condition, availability, sale, and dimensions all have structured filters — the optimal path to precise results in default/keyword mode. If you can't express a constraint with a filter, put it in `query` rather than omitting it entirely. Reserve `query`-only phrasing for what can't be enumerated (aesthetic descriptors, model names, use cases). Agentic mode inverts this: dump the full context into `query`.

## Quick start

```bash
npm install @channel3/sdk           # TypeScript
pip install channel3-sdk            # Python
```

A Go SDK is also available — see [docs.trychannel3.com/sdk](https://docs.trychannel3.com/sdk).

Set `CHANNEL3_API_KEY` in the environment (free key at [trychannel3.com](https://trychannel3.com)). Then the minimum end-to-end call:

```typescript
import { Channel3 } from '@channel3/sdk';

const client = new Channel3({ apiKey: process.env.CHANNEL3_API_KEY });
const page = await client.products.search({ query: 'running shoes', limit: 5 });
const products = page.data;  // Product[]
```

```python
from channel3_sdk import Channel3

client = Channel3(api_key="YOUR_API_KEY")
page = client.products.search(query="running shoes", limit=5)
products = page.items  # list[Product]
```

SDK 4.0 notes: TypeScript uses a **named import** (`import { Channel3 }`), **object-style requests** (`client.products.retrieve({ product_id })`), and **snake_case request fields** matching the wire format. Paginated calls return a `Page` — `.data` in TS, `.items` in Python, async-iterable in both. On SDK 3.x code? See [`references/sdk-4-upgrade.md`](references/sdk-4-upgrade.md).

Locale defaults can be set client-wide via constructor (`new Channel3({ country: 'GB', currency: 'GBP' })`) or `CHANNEL3_LANGUAGE` / `CHANNEL3_COUNTRY` / `CHANNEL3_CURRENCY` env vars; per-call `config.country` / `config.currency` / `config.language` always wins. For async clients, error classes, retries, timeouts, and logging, see [docs.trychannel3.com/sdk](https://docs.trychannel3.com/sdk).

### CLI (terminal & testing)

For ad-hoc API exploration from a terminal — sanity-checking a filter shape, grabbing a `product_id` to feed into integration tests, or one-off calls without a project — use the [Channel3 CLI](https://docs.trychannel3.com/cli). It tracks the API spec automatically.

```bash
brew install channel3-ai/tap/channel3   # or: go install github.com/channel3-ai/cli/cmd/channel3@latest
export CHANNEL3_API_KEY="..."

channel3 products search --query "running shoes" --max-items 5 \
  --filters '{"price":{"max_price":100},"gender":"male"}' \
  --format jsonl --transform '{id,title,offers:offers.#.{domain,price:price.price,url}}'
```

Use the SDK for production code. The CLI is for terminal work.

### UI components (React)

[Channel3 UI](https://github.com/channel3-ai/channel3-ui) is an open-source (MIT) React component library, distributed as a [shadcn registry](https://ui.trychannel3.com) and typed directly against `@channel3/sdk` — a `Product` from a search or product fetch drops straight in.

```bash
npx shadcn@latest add https://ui.trychannel3.com/r/all.json
```

- **Blocks** — `product-search` (search bar + faceted filters + infinite-scroll grid) and `product-details` (full PDP: gallery, variant selection, offer comparison, price history, recommendations).
- **À la carte** — components (`product-card`, `variant-selector`, `offers-list`, `image-gallery`, …) and hooks (`useProductSearch`, `useVariantSelection`, `useProductRecommendations`, …).
- **Presentational by design** — components take Channel3 data as props and emit intent through callbacks; they never call the API or touch your key. Fetch and shape data on your server (where `CHANNEL3_API_KEY` lives), then pass results in.
- **On SDK major upgrades** — re-install from the registry (`add --overwrite`) rather than hand-fixing component types; see [`references/sdk-4-upgrade.md`](references/sdk-4-upgrade.md#upgrading-channel3-ui-components).
- **Pass full SDK response objects, not trimmed subsets** — e.g. `PriceHistoryResponse` requires `canonical_product_id`. Across JSON boundaries, `Date` fields arrive as ISO strings; coerce at the boundary (`z.coerce.date()`).

## Endpoints

### Search — `POST /v1/search`

Text, image, or text+image search. Returns a paginated `Page` of `Product`.

```typescript
const page = await client.products.search({
  query: 'running shoes under $100',
  filters: { price: { max_price: 100 }, gender: 'male' },
  limit: 10,
});
const products = page.data;
```

```python
page = client.products.search(
    query="running shoes under $100",
    filters={"price": {"max_price": 100}, "gender": "male"},
    limit=10,
)
products = page.items
```

Per-call locale override: `config: { country: 'GB', currency: 'GBP' }`. Full filter shape in `references/api-reference.md`; full per-endpoint schema at [docs.trychannel3.com/api-reference](https://docs.trychannel3.com/api-reference).

#### Choosing a search mode

Set via `config.mode`:

- **`default`** (lexical + semantic) — right for almost all calls.
- **`agentic`** — for rich natural-language briefs you didn't write: an end-user's message, or your agent passing along accumulated context. Put the full context in `query` and let the LLM planner decompose it into structured sub-searches instead of hand-building filters. Costs multiple seconds. This mode powers Channel3's MCP server, so it gives your own agent loop MCP-grade behavior.
- **`keyword`** — lexical-only, lowest latency; incompatible with image input. Niche (ad targeting, real-time); not for normal search.

#### Structured attribute and color filters

**Color constraints use `filters.colors`, not `filters.attributes`.** Map color words (navy, blue, red, ...) to sRGB hex. `filters.attributes` is for non-color handles only (material, frame-color, ...).

```typescript
const page = await client.products.search({
  query: 'leather sofa',
  filters: {
    category_ids: ['sofas'],
    attributes: { material: ['Leather'] },
    colors: {
      palette: [
        { hex: '#001f3f' }, // navy — use colors for any color intent
        { hex: '#ffffff', percentage: 0.3 },
      ],
    },
  },
  limit: 10,
});
```

- **`colors.palette`** — products must contain every listed color (AND). `hex` is sRGB (`#rrggbb`); `percentage` (0–1) is an optional minimum share of that color in the product image.
- **`attributes`** — `Record<string, string[]>`. Keys are non-color attribute handles (e.g. `material`, `frame-color`); values are OR within a key, AND across keys. Discover valid handles and values for a category via `client.categories.retrieve({ slug })` → `Category.attributes`. Do **not** pass the `color` handle here — use `filters.colors` instead. When a category filter is also supplied, every attribute key must be valid for at least one of those categories.

Don't guess attribute handles or values — `categories.retrieve` is the source of truth for non-color attributes. Returned products carry `structured_attributes` (e.g. `{ color: ["Navy"], material: ["Leather"] }`) for display; filter color via `filters.colors`, not by echoing `structured_attributes.color` into `filters.attributes`.

For raw HTTP / non-SDK callers:

```bash
curl -X POST https://api.trychannel3.com/v1/search \
  -H "x-api-key: $CHANNEL3_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"query":"running shoes","filters":{"price":{"max_price":100}},"limit":10}'
```

### Similar — `POST /v1/similar`

**"More like this" from a Channel3 `product_id` you already have.** Almost always seeded from a previous `/v1/search` response. Returns the same paginated shape; the source product is excluded.

```typescript
const search = await client.products.search({ query: 'red leather jacket', limit: 5 });
const seedId = search.data[0].id;

const similar = await client.products.findSimilar({
  product_id: seedId,
  filters: { gender: 'female', price: { max_price: 200 } },
  limit: 10,
});
```

```python
search = client.products.search(query="red leather jacket", limit=5)
seed_id = search.items[0].id

similar = client.products.find_similar(
    product_id=seed_id,
    filters={"gender": "female", "price": {"max_price": 200}},
    limit=10,
)
```

Filters are recommended to keep results in the same slice (gender, brand, category, price). For "more like this, but in navy", use `filters.colors` (e.g. `{ hex: '#001f3f' }`), not `filters.attributes.color`. Non-color attributes use `filters.attributes`. Returns `404` if the product isn't in the catalog yet — fall back to `/v1/search` by title.

### Lookup — `POST /v1/lookup`

Resolve a merchant URL to the canonical Channel3 `Product`. Use this only when the developer's only handle on a product is a URL (e.g. a user-pasted link).

```typescript
const { product } = await client.products.lookup({
  url: 'https://merchant.com/products/red-jacket',
});
```

```python
result = client.products.lookup(url="https://merchant.com/products/red-jacket")
product = result.product
```

Latency: typically 2–10 seconds for uncached URLs (real-time extraction), sub-second for cached. Returns `422` for non-product pages (category listings, search results, homepages) and `504` on timeout. `max_staleness_hours` (default 3) bounds cache freshness. The response carries the same hydrated `variants` and `structured_attributes` as `GET /v1/products/{id}`. Once you have `product.id`, use it with `client.products.retrieve()` or `client.products.findSimilar()`.

### Product Details — `GET /v1/products/{product_id}`

Full `Product` for a known `product_id`. Same response shape as search results, but with `variants` fully hydrated for the current selection — including per-option-value availability and thumbnails. This call is **free**.

```typescript
const product = await client.products.retrieve({
  product_id: 'prod_abc123',
  country: 'GB',
  currency: 'GBP',
});
```

```python
product = client.products.retrieve("prod_abc123", country="GB", currency="GBP")
```

Locale via `config` (`language`, `country`, `currency`, `length_unit`, `weight_unit`); constrain retailers via `filters.website_ids` (accepts domains, e.g. `"nike.com"`). Returns `404` when the product has no merchant offer in the requested locale — seed `product_id` from a `/v1/search` call run under the same locale, or omit the locale to fall back to default.

#### Variants and `selected_options`

A `Product` with variations carries:

- **`variants.options`** — every dimension (e.g. `Color`, `Size`) and its `values` (`label`, `exists`, `available`, optional `thumbnail_url` and `product_id` for color-as-product-swap setups).
- **`variants.selected`** — the dimensions currently resolved on this response (`[{ name: "Color", label: "Navy" }, ...]`).
- **`structured_attributes`** — extracted attribute values for the resolved variant (e.g. `{ color: ["Navy"], material: ["Leather"] }`).

To re-fetch the product under a different variant configuration, pass `selected_options` (SDK) or `option_<DimensionName>=<Label>` query params (HTTP). Multiple dimensions can be combined; case is preserved on the name and matched case-insensitively against the product family.

```typescript
const product = await client.products.retrieve({
  product_id: 'prod_abc123',
  selected_options: { Color: 'Blue', Size: 'XL' },
});
```

```bash
curl -X GET \
  "https://api.trychannel3.com/v1/products/prod_abc123?option_Color=Blue&option_Size=XL" \
  -H "x-api-key: $CHANNEL3_API_KEY"
```

The server returns the same `Product` shape with `variants.selected` updated to reflect the resolved configuration. Diff your requested options against `variants.selected` to detect server-side relaxation (e.g. the requested size was unavailable in the requested color).

For the full variant model — search-vs-detail differences, `product_id` navigation (color-as-separate-product), and the `exists`/`available` UI tiers — see [`references/variants.md`](references/variants.md). In React, the [Channel3 UI](#ui-components-react) `useVariantSelection` hook implements this selection-and-re-resolution loop for you.

### Browse — `POST /v1/browse`

Filter-only product listing — no query or image. Use it to render a brand page, category page, or retailer collection. **At least one of `brand_ids`, `category_ids`, or `website_ids` is required** (422 otherwise); all other `SearchFilters` fields work too. Returns the same paginated shape as search.

```typescript
const page = await client.products.browse({
  filters: { brand_ids: ['MpZS'], sale: 'on_sale' },
  limit: 20,
});
```

```python
page = client.products.browse(
    filters={"brand_ids": ["MpZS"], "sale": "on_sale"},
    limit=20,
)
```

### Conversations — `POST /v1/conversations`

Turn-based conversational shopping: the developer sends a user message, Channel3 runs the agent (search, compare, refine) and streams back the reply. Browser clients authenticate with short-lived **client tokens** minted on your server — the API key never ships to the browser.

```typescript
// Server: mint a token for the browser session
const { token, expires_at } = await client.conversations.clientTokens.create({
  ttl_seconds: 900,
});

// Browser: authenticate with the token via the `auth` option
const browserClient = new Channel3({
  auth: () => Promise.resolve({ headers: { Authorization: `Bearer ${token}` } }),
});
const stream = await browserClient.conversations.createTurnStream({
  message: { parts: [{ type: 'text', text: 'running shoes under $100' }] },
  conversation_id, // omit to start a new thread
});
for await (const event of stream) {
  if (event.type === 'part.delta') process.stdout.write(event.delta);
}
```

Full auth model, SSE event reference, and Python examples: [`references/conversations.md`](references/conversations.md).

### Reporting — `/v1/reporting/...`

Click and transaction attribution for your API key, filterable by the `user_id` you tagged requests with (see **User attribution** below).

- `GET /v1/reporting/clicks?start_date=&end_date=` — offer-link clicks
- `GET /v1/reporting/transactions?start_date=&end_date=` — attributed sales

```typescript
const clicks = await client.reporting.listClicks({
  start_date: new Date('2026-08-01T00:00:00Z'), // Date objects, not ISO strings
  end_date: new Date('2026-08-17T00:00:00Z'),
  user_id: 'user_123', // optional
});
clicks.data; // Click[]
clicks.response.summary; // aggregates, e.g. { total_clicks }
```

Date windows are capped at 90 days per call (default: last 30 days); responses are paginated (`page` / `limit`, max 100). Field reference: `references/api-reference.md`.

### Price Tracking — `/v0/price-tracking/...`

- `client.priceTracking.start({ canonical_product_id })` — start tracking
- `client.priceTracking.stop({ canonical_product_id })` — stop tracking
- `client.priceTracking.retrieveHistory({ canonical_product_id, days })` — up to 30 days; returns `current_price`, `min/max/mean/std_dev`, `current_status` (`low` / `typical` / `high`)
- `client.priceTracking.listSubscriptions()` — cursor-paginated `Page`; `for await` iterates the awaited page (`for await (const sub of await client.priceTracking.listSubscriptions())`)

```typescript
await client.priceTracking.start({ canonical_product_id: 'prod_abc123' });
const history = await client.priceTracking.retrieveHistory({
  canonical_product_id: 'prod_abc123',
  days: 30,
});
console.log(history.statistics?.current_price, history.statistics?.current_status);
```

### Brands and Websites — `/v1/brands*`, `/v0/websites`

Lookup helpers, mostly used to obtain IDs for search filters.

- `client.brands.search({ query, limit? })` — find brands by name; returns up to `limit` matches ordered by relevance (default 5, max 20)
- `client.brands.retrieve({ brand_id })` — by ID
- `client.brands.list()` — cursor-paginated `Page`; `for await` iterates the awaited page. **Iterating to exhaustion walks the entire brand catalog (thousands of brands, many pages of API calls); always break early or use `client.brands.search` when you just need one brand.**
- `client.websites.retrieve({ query: 'nike.com' })` — find a retailer

```typescript
// Find a brand ID for filtering
const { brands } = await client.brands.search({ query: 'Nike', limit: 5 });
const brandId = brands[0]?.id;  // top match — inspect `brands` to disambiguate when multiple match
```

### Categories — `/v1/categories*`

Discover the category slugs you can pass to `SearchFilters.category_ids` / `exclude_category_ids`, and the attribute keys/values you can pass to `SearchFilters.attributes`. Slugs are stable URL-friendly identifiers (e.g. `shoes`, `sofas`, `handbags`) — prefer them over internal IDs. The taxonomy doesn't have a leaf for every conceivable subcategory, and unknown slugs are silently dropped, so always discover real slugs with `client.categories.search` rather than guessing.

- `client.categories.search({ query, limit? })` — free-text → `CategorySummary[]` (`limit` 1–20, default 5)
- `client.categories.list({ roots_only?, page?, page_size? })` — paginated browse, roots first (`page_size` 1–100, default 20)
- `client.categories.retrieve({ slug })` — full `Category` with description, attributes, direct children, and root-to-self `path`

```typescript
const { categories } = await client.categories.search({ query: 'running shoes', limit: 5 });
const slug = categories[0].slug;

const page = await client.products.search({
  query: 'lightweight trainers',
  filters: { category_ids: [slug] },
});
```

```python
result = client.categories.search(query="running shoes", limit=5)
slug = result.categories[0].slug

page = client.products.search(
    query="lightweight trainers",
    filters={"category_ids": [slug]},
)
```

`exclude_category_ids` excludes the category and all its descendants.

`Category.attributes` lists indexed attribute handles for `SearchFilters.attributes`. Use non-color slugs (e.g. `material`, `frame-color`). The `color` entry is informational on products — **filter color with `filters.colors`**, not `attributes.color`.

```typescript
const category = await client.categories.retrieve({ slug: 'sofas' });
const materialAttr = category.attributes.find(a => a.slug === 'material');
//   materialAttr?.values → ["Leather", "Velvet", "Linen", ...]

const page = await client.products.search({
  query: 'leather sectional',
  filters: {
    category_ids: ['sofas'],
    attributes: { material: ['Leather'] },
    colors: { palette: [{ hex: '#001f3f' }] }, // navy via colors filter
  },
});
```

## User attribution

Pass your end-user's ID on any request to attribute their clicks and sales in reporting. Raw HTTP takes the `x-user-id` header; the Python SDK takes a `user_id` kwarg (mapped to the header); in TypeScript, pass the header via request options. Channel3 appends it to buy URLs in the response. Max 128 chars; letters, numbers, and `. _ @ -` only.

```typescript
await client.products.search(
  { query: 'desk lamp' },
  { headers: { 'x-user-id': 'user_123' } },
);
```

```python
client.products.search(query="desk lamp", user_id="user_123")
```

```bash
curl -X POST https://api.trychannel3.com/v1/search \
  -H "x-api-key: $CHANNEL3_API_KEY" -H "x-user-id: user_123" \
  -H "Content-Type: application/json" -d '{"query":"desk lamp"}'
```

## Affiliate links

Every `ProductOffer.url` in a response is an affiliate-tracked link. Surface them as the buy buttons in any UI — sales driven through these URLs earn commission with no additional setup. Use `offer.domain` to identify the retailer and `offer.max_commission_rate` to compare earning potential across merchants.

## Caching and freshness

- **Cache IDs, not data.** `product.id` and category slugs are stable — cache them freely. Treat everything else on a product (prices, availability, offers, images, descriptions, variants) as unstable; it changes as merchants update catalogs.
- **Refresh at display time.** Before showing a product to a user, refetch with `GET /v1/products/{id}` (`client.products.retrieve`) — this call is **free** and returns current prices, stock, hydrated variant availability, and fresh offer URLs.
- **Offer URLs are short-lived.** Never cache `ProductOffer.url` and serve it later; fetch it fresh before presenting the buy link.
- Short TTLs (minutes to a few hours) on presentational fields (title, images) are fine; avoid caching pricing or availability for hours or days.

## Locale codes

- **Languages:** `en`, `de`, `fr`, `it`, `es`, `nl`, `sv`, `fi`, `pt`, `cs`, `el`, `ro`
- **Countries:** `US`, `GB`, `EU`, `AU`, `CA`, `IE`, `DE`, `AT`, `FR`, `BE`, `IT`, `ES`, `NL`, `SE`, `FI`, `PT`, `CZ`, `GR`, `RO`
- **Currencies:** `USD`, `CAD`, `AUD`, `GBP`, `EUR`, `SEK`, `CZK`, `RON`
- **Length units:** `mm`, `cm`, `m`, `in`, `ft` · **Weight units:** `mg`, `g`, `kg`, `oz`, `lb`

When `country` is set alone, the server infers `currency` (`GB → GBP`) and `language` (`GB → en`). When all three are unset, defaults are `en` / `US` / `USD`. `length_unit` / `weight_unit` only control the units dimensions are rendered in — unset returns the merchant's stated unit.

## When to use the MCP instead

For no-code agent integration, use the [Channel3 MCP](https://docs.trychannel3.com/mcp-overview) instead of writing API code when the host already supports it.

## When stuck

- SDK guide (install, async, errors, retries, logging): [docs.trychannel3.com/sdk](https://docs.trychannel3.com/sdk)
- Full API reference (try-it examples, schemas): [docs.trychannel3.com/api-reference](https://docs.trychannel3.com/api-reference)
- Offline quick-card: `references/api-reference.md`
- Migrating existing code to SDK 4.0: `references/sdk-4-upgrade.md`
- Support: [support@trychannel3.com](mailto:support@trychannel3.com)
