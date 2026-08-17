# Upgrading to Channel3 SDK 4.0

> Read this when the user's project has Channel3 SDK 3.x (or older) code and needs to move to 4.0. SDK 4.0 is regenerated from the API spec (Fern) and has breaking changes on both the client surface and the underlying API. The wire API itself also changed — raw-HTTP integrations need the [API changes](#api-changes-that-affect-any-client) section too.

Install:

```bash
npm install @channel3/sdk@latest     # TypeScript
pip install --upgrade channel3-sdk   # Python (package renamed from channel3_sdk;
                                     # the import stays `channel3_sdk`)
```

## TypeScript: client surface

| 3.x | 4.0 |
|---|---|
| `import Channel3 from '@channel3/sdk'` (default import) | `import { Channel3 } from '@channel3/sdk'` — **named import only**, no default export |
| `client.products.retrieve(productId, { country: 'GB' })` | `client.products.retrieve({ product_id: productId, country: 'GB' })` — **all methods take one request object**; IDs moved inside it |
| `client.products.retrieve(id, { option_Color: 'Blue' })` | `client.products.retrieve({ product_id: id, selected_options: { Color: 'Blue' } })` — typed `selected_options` replaces ad-hoc `option_*` params |
| `page.products` | `page.data` — paginated calls return `Page<T>` (`.data`, `hasNextPage()`, `getNextPage()`, async-iterable) |
| `page.next_page_token` | `page.response.next_page_token` — raw response fields moved onto `.response` |
| `for await (const p of client.products.search(...))` — 3.x's `PagePromise` was directly async-iterable | Await first, then iterate the page: `for await (const p of await client.products.search(...))` |
| `ProductDetail`, `ProductDetailsSearchPage` | `Product`, `Page<Product, SearchResponse>` |
| `client.enrich.enrichURL({ url })` | `client.products.lookup({ url })` |
| `client.search.perform({...})` (legacy resource) | `client.products.search({...})` |
| `client.brands.find({ query })` (deprecated) | `client.brands.search({ query })` — returns a list ordered by relevance |
| `client.websites.find({ query })` (deprecated alias) | `client.websites.retrieve({ query })` |
| `client.priceTracking.retrieveHistory(id, { days })` | `client.priceTracking.retrieveHistory({ canonical_product_id: id, days })` |
| `client.brands.retrieve(brandId)` | `client.brands.retrieve({ brand_id })` |
| `client.categories.retrieve(slug)` | `client.categories.retrieve({ slug })` |

Request fields are **snake_case** in 4.0 TypeScript, matching the wire format exactly (`product_id`, `max_price`, `selected_options`, `page_token`). Client-constructor options stay camelCase (`apiKey`, `lengthUnit`, `weightUnit`).

Rename with word boundaries: a global `ProductDetail` → `Product` replace corrupts `ProductDetails*` identifiers (`ProductDetails` → `Products`). Rename type imports, or match `\bProductDetail\b` exactly.

## Python: client surface

| 3.x | 4.0 |
|---|---|
| `pip install channel3_sdk` | `pip install channel3-sdk` — import is unchanged: `from channel3_sdk import Channel3` |
| `response.products` | `page.items` — paginated calls return a pager (`.items`, `.has_next`, `.next_page()`, iterable) |
| `client.products.retrieve(id, option_Color="Blue")` | `client.products.retrieve(id, selected_options={"Color": "Blue"})` |
| `client.enrich.enrich_url(url=...)` | `client.products.lookup(url=...)` |

## New in 4.0 (not just renames)

- **`client.conversations`** — turn-based conversational shopping with SSE streaming and browser-safe client tokens. See [`conversations.md`](conversations.md).
- **`client.reporting`** — `listClicks` / `listTransactions` (TS), `list_clicks` / `list_transactions` (Python): click and commission attribution, filterable by `user_id`.
- **`client.products.browse`** — filter-only listing (no query) for brand/category/retailer pages.
- **`user_id` attribution** — Python SDK kwarg and `x-user-id` HTTP header (in TS, pass the header via request options: `client.products.search({...}, { headers: { 'x-user-id': ... } })`) — attribute clicks/sales to your end users; surfaced in reporting and appended to buy URLs.
- **`lengthUnit` / `weightUnit` client options** and per-request `length_unit` / `weight_unit` — control the units physical dimensions render in.
- **`auth` client option (TS)** — pass a function returning auth headers for browser clients using client tokens.
- **SSE stream auto-reconnect** — `stream: { reconnectionEnabled, maxReconnectionAttempts }` client option.

## API changes that affect any client

These changed on the wire, so they apply to raw-HTTP integrations and both SDK languages:

| Before | Now |
|---|---|
| `filters.condition: "new"` (singular string; `"refurbished"` allowed) | `filters.conditions: ["new", "used"]` (list; `"refurbished"` rejected). Default `["new"]` |
| `filters.availability` accepted 8 values (`PreOrder`, `SoldOut`, `LimitedAvailability`, ...) | Only `"InStock"` / `"OutOfStock"`. Default `["InStock"]` |
| `config.keyword_search_only: true` | `config.mode: "keyword"` (also `"default"` / `"agentic"`) |
| — | New filters: `sale: "on_sale"`, `dimensions` (length/width/height/weight ranges with units) |
| `website_ids` accepted website IDs only | Also accepts domains (`"nike.com"`) |
| `Product.categories: string[]` (deprecated) | Removed — use `Product.category` (`CategorySummary`) |
| `ProductImage.is_cleaned_image: boolean` | Removed — use `ProductImage.cleaned_url != null` |
| `OptionValue.available` had 8 values | `"InStock"` / `"OutOfStock"` / `null` |
| `ProductOffer` had no condition/dimensions | New `condition` (`"new"` / `"used"` / `null`) and `dimensions` fields |
| `/v0/search`, `/v0/enrich`, `/v0/products/{id}`, `/v0/brands*` | Removed — use the `/v1` equivalents (`/v0/enrich` → `POST /v1/lookup`). `/v0/websites` and `/v0/price-tracking` remain |

## Upgrading channel3-ui components

Vendored channel3-ui components (installed via `npx shadcn add`, typed against `@channel3/sdk`) break on the 4.0 type changes. **Re-install them from the registry instead of hand-fixing type errors** — the latest registry version is already ported to 4.0, so re-installing is the fix: done once, by the maintainers, consistently across every component and shared lib. Hand-editing types file-by-file redoes that work, worse.

Rule of thumb: if type errors touch more than ~2 vendored files, stop hand-fixing and re-install. Hand-fixes are for the long tail, not the fleet.

### Re-installing

**With shadcn already configured** (a working `components.json`):

```bash
npx shadcn@latest add https://ui.trychannel3.com/r/all.json --overwrite --yes
```

Run it from the UI app root (where `components.json` lives), not a monorepo root. Prefer `all.json` over piecemeal re-adds: it also refreshes the shared libs and hooks (`variants.ts`, `useVariantSelection`, …) that the SDK types flow through, so no stale lib is left under new components.

**Project never shadcn-initialized?** Run `shadcn init` first — but from the UI app root, and check the result: with ambiguous template detection, `init` can scaffold a brand-new sibling app instead of configuring the existing one. A minimal `components.json` for an existing Vite + Tailwind v4 app:

```json
{
  "tailwind": { "css": "src/globals.css" },
  "aliases": { "components": "@/components", "utils": "@/lib/utils", "ui": "@/components/ui" }
}
```

**No shadcn at all / non-interactive environment** (components vendored manually, agent or CI runs where prompts can't be answered): install straight from the registry protocol. `all.json` is a meta-bundle — no `files` of its own, only `registryDependencies`; recurse into each item URL. Every item carries inline `files[].content` plus npm `dependencies` — write the files under your components dir (keeping the `@/` alias convention they import with) and install the npm deps.

Either way: re-installing pulls the *current* registry, which may have gained items and peer dependencies since the last install (e.g. `product-details` now depends on `price-history-chart`, which needs `recharts` and shadcn's `chart` primitive). Typecheck afterward and install anything listed in the items' `dependencies` fields.

### Preserving local changes

`add` replaces files wholesale — there is no merge — and an overwrite **silently removes anything upstream doesn't have**: locally-added props, sections, compound children. So:

1. **Preview first.** `--dry-run` shows what re-installing would touch; `--diff <path>` compares one local file against the registry version.
2. **Inventory local additions before overwriting.** `git log --follow --oneline -- <file>` — no commits after the initial registry add means the file is pristine. Commit or stash first so the overwrite lands as a reviewable git diff; that diff is how you recover your additions.
3. **Customized components:** re-install anyway when customizations are small or known, then re-apply them from the diff. Reserve hand-fixing for components with heavy, intertwined local changes.
4. **Typecheck** (`tsc` or the project's check script). Registry components matched to SDK 4.0 compile clean; any remaining errors are in the project's own code.

### Registry libs changed too

App code that imports the registry's shared helpers breaks on top of the SDK renames. As of the 4.0-era registry (the registry is unversioned — re-check the diff on re-install):

- `pickImage(images, { preferCleaned: true })?.url` → `productImageUrl(pickImage(images), { preferCleaned: true })`
- `currencyFormatter(...)` removed from `format.ts` — use `Intl.NumberFormat` inline

### Feeding SDK data to components

- Components expect the SDK's **full response types** — e.g. `PriceHistoryResponse` requires `canonical_product_id`, so a server tool that returns only `{ history, statistics }` must rehydrate the envelope: `{ canonical_product_id: product.id, ...historyResult }`.
- Across a JSON boundary (MCP tool results, SSR serialization), `Date` fields arrive as ISO strings while the SDK types say `Date`. Coerce at the boundary — `z.coerce.date()` in Zod schemas, or accept `Date | string` in component-facing helpers.

## Upgrade checklist

0. Preflight: confirm the installed package matches `package.json` — `node -p "require('@channel3/sdk/package.json').version"`. A partial install (new package in `node_modules`, old range in `package.json`) fails typecheck in confusing ways.
1. Bump the package (`@channel3/sdk@latest` / `channel3-sdk`).
2. Fix imports (named `Channel3` in TS).
3. Convert every method call to a single request object; move positional IDs into it (`product_id`, `brand_id`, `slug`, `canonical_product_id`).
4. Replace `page.products` → `page.data` (TS) / `page.items` (Python); move `page.next_page_token` → `page.response.next_page_token`; switch pagination to `hasNextPage()` / `getNextPage()` or async iteration over the awaited page.
5. Rename types (`ProductDetail` → `Product` — word-boundary replace only, never inside `ProductDetails*` identifiers).
6. Update filters: `condition` → `conditions`, availability values, `keyword_search_only` → `mode: "keyword"`.
7. Replace removed calls: `enrich` → `products.lookup`, `brands.find` → `brands.search`, `websites.find` → `websites.retrieve`, `search.perform` → `products.search`.
8. Replace `option_*` extra-query params with `selected_options`.
9. Sweep for removed response fields (`categories`, `is_cleaned_image`).
10. Re-install vendored channel3-ui components from the registry rather than hand-fixing their types — see [Upgrading channel3-ui components](#upgrading-channel3-ui-components).
11. Verify: fresh `install`, typecheck, production build, then a runtime smoke of every touched surface (search, detail, variants, reporting). Typecheck alone misses bundler and serialization issues.
