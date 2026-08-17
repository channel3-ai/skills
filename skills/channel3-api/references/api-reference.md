# Channel3 API Reference (offline quick-card)

> **For full request/response schemas with try-it examples, see [docs.trychannel3.com/api-reference](https://docs.trychannel3.com/api-reference).** This file is a minimal offline backstop — endpoint signatures, the high-traffic `SearchFilters` / `SearchConfig` / `LocaleConfig` shapes, and compact response types. Matches SDK 4.0.

**Base URL:** `https://api.trychannel3.com` · **Auth:** `x-api-key` header (conversations also accept `Authorization: Bearer c3_ct_...` client tokens) · `/v1` for everything except price-tracking/websites (`/v0`).

## Contents

- Endpoint quick-cards (`/v1/search`, `/v1/similar`, `/v1/products/{id}`, `/v1/lookup`, `/v1/browse`, conversations, reporting, price tracking, brands and websites, categories)
- `SearchFilters` shape (including `attributes`, `colors`, `dimensions`)
- `SearchConfig` and `LocaleConfig` shapes
- Core response types (`SearchResponse`, `Product`, `ProductOffer`, `Price`, `ProductImage`, `Dimensions`, `Variants`, `VariantOption`, `OptionValue`, `SelectedOption`, `Brand`, `Website`, `PriceHistory`, `Subscription`, `CategorySummary`, `Category`, `CategoryRef`, `CategoryAttribute`, reporting types)
- Color filter helpers (`SearchColorsFilter`, `SearchFilterColor`)

For locale codes (languages, countries, currencies, units) and inference rules, see SKILL.md. For the conversational API's auth model and SSE events, see [`conversations.md`](conversations.md).

---

## Endpoint quick-cards

### `POST /v1/search`

Free-text and/or image search. At least one of `query`, `image_url`, `base64_image`, or `page_token` is required (422 otherwise).

- **Body:** `query?` · `image_url?` · `base64_image?` · `limit?` (default 20, max 30) · `page_token?` · `filters?: SearchFilters` · `config?: SearchConfig`
- **Headers:** `x-user-id?` (user attribution — appended to buy URLs)
- **Response:** `SearchResponse`
- **SDK:** `client.products.search({...})` → `Page` (`.data` in TS, `.items` in Python)

### `POST /v1/similar`

"More like this" from a Channel3 `product_id` you already have. Source product is excluded.

- **Body:** `product_id` (required) · `limit?` · `page_token?` · `filters?: SearchFilters` · `config?: LocaleConfig`
- **Response:** `SearchResponse`
- **Errors:** `404` (product not in catalog yet — fall back to `/v1/search` by title)
- **SDK:** `client.products.findSimilar({...})` (TS) / `client.products.find_similar({...})` (Python)

### `GET /v1/products/{product_id}`

Full canonical product by ID, including hydrated `variants` and `structured_attributes`. Free call.

- **Path:** `product_id`
- **Query:** `website_ids?` (accepts domains, e.g. `nike.com`) · `language?` · `country?` · `currency?` · `length_unit?` · `weight_unit?` · `option_<name>=<label>` (repeatable; selects a variant configuration, e.g. `option_Color=Blue&option_Size=XL`)
- **Headers:** `x-user-id?`
- **Response:** `Product`
- **SDK:** `client.products.retrieve({ product_id, selected_options?, ... })` (TS) · `client.products.retrieve(product_id, selected_options?, ...)` (Python)
- **Variant interaction guide:** [`variants.md`](variants.md)

### `POST /v1/lookup`

Resolve a merchant URL to the canonical `Product`. URL-only fallback.

- **Body:** `url` (required) · `max_staleness_hours?` (default 3)
- **Response:** `LookupResponse` (`{ product }`)
- **Errors:** `422` (not a product page) · `500` (extraction failed) · `504` (timeout). Typical latency 2–10s uncached.
- **SDK:** `client.products.lookup({ url, max_staleness_hours? })`

### `POST /v1/browse`

Filter-only listing — no query, no image. For brand pages, category pages, and retailer collections.

- **Body:** `filters: SearchFilters` (required; **must include at least one of `brand_ids`, `category_ids`, or `website_ids`**) · `limit?` · `page_token?` · `config?: LocaleConfig`
- **Response:** `SearchResponse`
- **Errors:** `422` (missing required filter)
- **SDK:** `client.products.browse({...})`

### Conversations — `/v1/conversations`

Turn-based conversational shopping with SSE streaming. Full reference: [`conversations.md`](conversations.md).

- `POST /v1/conversations` — create a turn. Body: `message` (`{ parts: [{ type: "text", text }] }`, image parts also supported) · `conversation_id?` (omit to create thread) · `filters?` (pinned catalog filters) · `context?` · `stream?` (default true → SSE of `TurnEvent`; false → buffered `TurnResult`). Auth: API key **or** `Bearer` client token.
- `POST /v1/conversations/client_tokens` — mint a browser-safe token. Body: `conversation_id?` (pin to thread) · `ttl_seconds?` (60–7200). → `{ token, token_id, expires_at }`. API key only.
- `POST /v1/conversations/client_tokens/revoke` — body `{ token }`. API key only.
- `GET /v1/conversations/{conversation_id}` — thread history (paginated).
- **SDK:** `client.conversations.createTurn | createTurnStream | retrieve` · `client.conversations.clientTokens.create | revoke`

### Reporting — `/v1/reporting/...`

Attribution data for your API key. Both endpoints share the same query shape:

- **Query:** `start_date?` · `end_date?` (ISO 8601 datetimes; naive = UTC; default window is the last 30 days; **max 90 days**, 400 otherwise) · `page?` (1-indexed, default 1) · `limit?` (default 20, max 100) · `user_id?` (filter to one attributed user)
- `GET /v1/reporting/clicks` → `ClicksResponse`
- `GET /v1/reporting/transactions` → `TransactionsResponse`
- **SDK:** `client.reporting.listClicks({...})` · `client.reporting.listTransactions({...})` (TS) / `client.reporting.list_clicks({...})` · `client.reporting.list_transactions({...})` (Python)

### Price tracking — `/v0/price-tracking/...`

- `POST /start` — body `{ canonical_product_id }` → `Subscription`
- `POST /stop` — body `{ canonical_product_id }` → `Subscription`
- `GET /history/{canonical_product_id}?days=` — up to 30 days → `PriceHistory`
- `GET /subscriptions?limit&cursor` → `CursorPage<Subscription>`
- **SDK:** `client.priceTracking.start | stop | retrieveHistory | listSubscriptions`

### Brands and websites

- `GET /v1/brands?limit&cursor` → `CursorPage<Brand>` · SDK: `client.brands.list({...})`
- `GET /v1/brands/{brand_id}` → `Brand` · SDK: `client.brands.retrieve({ brand_id })`
- `GET /v1/brands/search?query&limit` → `SearchBrandsResponse` (list, ordered by relevance; `limit` 1–20, default 5) · SDK: `client.brands.search({ query, limit? })`
- `GET /v0/websites?query=` → `Website | null` · SDK: `client.websites.retrieve({ query })`

### Categories — `/v1/categories*`

- `GET /v1/categories/search?query=&limit=` (`limit` 1–20, default 5) → `SearchCategoriesResponse` · SDK: `client.categories.search({ query, limit? })`
- `GET /v1/categories?roots_only=&page=&page_size=` (`page_size` 1–100, default 20; roots first) → `PaginatedListCategoriesResponse` · SDK: `client.categories.list({ roots_only?, page?, page_size? })`
- `GET /v1/categories/{slug}` → `Category` (404 if unknown). `slug` accepts a URL-friendly slug or an internal `category_id` · SDK: `client.categories.retrieve({ slug })`

Use the resulting `slug` values anywhere `SearchFilters.category_ids` / `exclude_category_ids` is accepted.

---

## `SearchFilters`

The single most-typo'd shape in the API. Used by `/v1/search`, `/v1/similar`, and `/v1/browse`.

| Field | Type | Description |
|---|---|---|
| `price` | `{ min_price?: number, max_price?: number }` | Price range in the request currency |
| `brand_ids` | `string[]` | Include only these brands (use `client.brands.search` to obtain IDs) |
| `category_ids` | `string[]` | Include only these categories (descendants implicit). Use slugs; discover with `client.categories.search` |
| `website_ids` | `string[]` | Include only these retailer websites. Accepts website IDs or domains (`"nike.com"`) |
| `gender` | `"male" \| "female"` | |
| `age` | `("newborn" \| "infant" \| "toddler" \| "kids" \| "adult")[]` | Age-agnostic products are treated as adult |
| `conditions` | `("new" \| "used")[]` | OR. **Default `["new"]`** — also matches offers whose condition is unknown. Pass both values to disable. `"refurbished"` is rejected. |
| `availability` | `("InStock" \| "OutOfStock")[]` | OR. **Default `["InStock"]`** — offers with no availability data count as InStock. Pass both values to disable. |
| `sale` | `"on_sale"` | Only products with at least one on-sale offer (priced below compare-at) in the requested locale |
| `dimensions` | `SearchFilterDimensions` | Physical size ranges (length/width/height/weight), matched against a single offer |
| `attributes` | `Record<string, string[]>` | Non-color extracted attribute constraints (e.g. `material`, `frame-color`). Values OR within a key, AND across keys. Discover keys/values via `Category.attributes`. **Do not use for color** — use `colors` instead. |
| `colors` | `SearchColorsFilter` | [Beta] Color filter: required sRGB palette in the product image (AND across entries). Map color names to `#rrggbb` hex. |
| `exclude_brand_ids` | `string[]` | |
| `exclude_website_ids` | `string[]` | Accepts website IDs or domains |
| `exclude_category_ids` | `string[]` | Excludes the category and its descendants. Slugs. |

### `SearchFilterDimensions`

Every provided range must be satisfied by the same offer. An offer with no data for a filtered field does not match.

```typescript
dimensions: {
  length?: { min?: number, max?: number, unit: "mm"|"cm"|"m"|"in"|"ft" },
  width?:  { min?: number, max?: number, unit: LengthUnit },
  height?: { min?: number, max?: number, unit: LengthUnit },
  weight?: { min?: number, max?: number, unit: "mg"|"g"|"kg"|"oz"|"lb" },
}
// e.g. a desk that fits a small space:
// dimensions: { width: { max: 120, unit: "cm" }, height: { max: 80, unit: "cm" } }
```

## `SearchConfig`

`SearchConfig` extends `LocaleConfig` with one extra field:

| Field | Type | Description |
|---|---|---|
| `mode` | `"default" \| "keyword" \| "agentic"` | Search strategy. `default` (recommended) = lexical + semantic. `agentic` = LLM planner decomposes a rich natural-language brief into structured sub-searches — pass full context in `query`; multiple seconds of latency (powers Channel3's MCP). `keyword` = lexical only, low latency (ad targeting, real-time); incompatible with image input; niche. |
| `language` | `LanguageCode \| null` | inherited from `LocaleConfig` |
| `country` | `CountryCode \| null` | inherited from `LocaleConfig` |
| `currency` | `CurrencyCode \| null` | inherited from `LocaleConfig` |
| `length_unit` | `LengthUnit \| null` | inherited from `LocaleConfig` |
| `weight_unit` | `WeightUnit \| null` | inherited from `LocaleConfig` |

## `LocaleConfig`

```typescript
{
  language?: LanguageCode | null;
  country?: CountryCode | null;
  currency?: CurrencyCode | null;
  length_unit?: "mm" | "cm" | "m" | "in" | "ft" | null;   // response rendering only
  weight_unit?: "mg" | "g" | "kg" | "oz" | "lb" | null;   // response rendering only
}
```

Used as `config` on `/v1/similar` and `/v1/browse`, and as the locale base of `SearchConfig`. Raw-HTTP callers can also set locale client-wide with `X-Channel3-Language` / `X-Channel3-Country` / `X-Channel3-Currency` / `X-Channel3-Length-Unit` / `X-Channel3-Weight-Unit` headers. For the list of supported codes and inference rules, see SKILL.md.

---

## Core types

```typescript
SearchResponse {
  products: Product[];
  next_page_token?: string | null;        // null when no more results
}
// SDK 4.0 wraps this in a Page: `.data` (TS) / `.items` (Python),
// `hasNextPage()` / `getNextPage()`, and async iteration over products.

LookupResponse {
  product: Product;
}

Product {
  id: string;
  title: string;
  description?: string | null;
  brands?: ProductBrand[];
  images?: ProductImage[];
  category?: CategorySummary | null;      // the single category this product belongs to (slug, title, path, has_children)
  gender?: "male" | "female" | null;
  age?: "newborn" | "infant" | "toddler" | "kids" | "adult" | null;
  materials?: string[] | null;
  key_features?: string[] | null;
  offers?: ProductOffer[];
  variants?: Variants | null;             // null when the product has no variations
  structured_attributes: Record<string, string[]>;
                                          // e.g. { color: ["Navy"], material: ["Leather"] }
                                          // values come from the category's CategoryAttribute.values
}

Variants {
  options: VariantOption[];               // every dimension available on this product family
  selected: SelectedOption[];             // currently resolved configuration on this response
}

VariantOption {
  name: string;                           // e.g. "Color", "Size"
  values: OptionValue[];
}

OptionValue {
  label: string;                          // e.g. "Blue", "XL"
  exists: boolean;                        // false when the value is present on a sibling variant
                                          // but not this configuration (e.g. XL only in Red)
  available?: "InStock" | "OutOfStock" | null;
                                          // hydrated on GET /v1/products/{id}; null on search results
  thumbnail_url?: string | null;          // e.g. color swatch image
  product_id?: string | null;             // set when this value resolves to a different product
                                          // (color-as-product-swap setups)
}

SelectedOption {
  name: string;                           // dimension name, matches VariantOption.name
  label: string;                          // resolved value; diff against requested selected_options
                                          // to detect server-side relaxation
}

ProductOffer {
  url: string;                            // affiliate-tracked; carries user_id when request set it
  domain: string;                         // e.g. "nordstrom.com"
  price: Price;
  availability: "InStock" | "OutOfStock";
  condition?: "new" | "used" | null;      // null when unknown
  max_commission_rate?: number;           // fraction, 0.0–0.5 (0.05 = 5%)
  dimensions?: Dimensions | null;         // physical size of this offer, when known
}

Dimensions {
  length?: LengthDimension | null;
  width?: LengthDimension | null;
  height?: LengthDimension | null;
  weight?: WeightDimension | null;
}

LengthDimension { number: number; unit: "mm" | "cm" | "m" | "in" | "ft" }
WeightDimension { number: number; unit: "mg" | "g" | "kg" | "oz" | "lb" }
// Unit is the request's filter/preferred unit when one was given (value converted);
// otherwise the merchant's stated unit.

SearchColorsFilter {
  palette: SearchFilterColor[];           // AND across entries — product must match all
}

SearchFilterColor {
  hex: string;                            // sRGB, e.g. "#1a2b3c"
  percentage?: number | null;             // 0–1; optional minimum share of this color in the image
}

Price {
  price: number;                          // post-discount
  currency: string;
  compare_at_price?: number | null;       // pre-discount
}

ProductImage {
  url: string;
  cleaned_url?: string | null;            // background-removed square image on Channel3 CDN;
                                          // best for product grids
  alt_text?: string | null;
  is_main_image?: boolean;
  shot_type?: "hero" | "lifestyle" | "on_model" | "detail" | "scale_reference"
            | "angle_view" | "flat_lay" | "in_use" | "packaging" | "size_chart"
            | "product_information" | "merchant_information" | null;
}

ProductBrand { id: string; name: string }

Brand {
  id: string;
  name: string;
  best_commission_rate?: number;          // already a percentage (7.7 = 7.7%); do NOT multiply by 100
  description?: string | null;
  logo_url?: string | null;
}

SearchBrandsResponse {
  brands: Brand[];                        // ordered by relevance
}

Website {
  id: string;
  url: string;
  best_commission_rate?: number;          // already a percentage (8.39 = 8.39%); same units as Brand
}

PriceHistory {
  canonical_product_id: string;
  product_title?: string | null;
  history?: Array<{ price: number; currency: string; timestamp: string }>;
  statistics?: {
    current_price: number;
    min_price: number;
    max_price: number;
    mean: number;
    std_dev: number;
    currency: string;
    current_status: "low" | "typical" | "high";
  } | null;
}

Subscription {
  canonical_product_id: string;
  created_at: string;                     // ISO 8601
  subscription_status: "active" | "cancelled";
}

CategoryRef { slug: string; title: string }

CategorySummary {
  slug: string;                           // URL-friendly id, e.g. "shoes", "handbags"
  title: string;
  path: CategoryRef[];                    // root-to-self chain; last entry is self
  has_children: boolean;
}

Category extends CategorySummary {
  description?: string | null;            // natural-language category description
  children: CategoryRef[];                // direct subcategories (one level only)
  attributes: CategoryAttribute[];        // structured attributes for products in this category
}

CategoryAttribute {
  slug: string;                           // e.g. "color", "frame-color"
  name: string;                           // e.g. "Color"
  values: string[];                       // allowed values; empty when no enumerated set
}

SearchCategoriesResponse {
  categories: CategorySummary[];          // ordered by relevance
}

PaginatedListCategoriesResponse {
  items: CategorySummary[];
  page: number;                           // 1-indexed
  page_size: number;
  total: number;
}
```

## Reporting types

```typescript
ClicksResponse {
  summary: { total_clicks: number };
  items: Click[];
  page: number;                           // 1-indexed
  limit: number;
  total_count: number;
  has_more: boolean;
  start_date: string;                     // resolved window, UTC offset
  end_date: string;
}

Click {
  id: string;
  timestamp: string;                      // UTC
  user_id?: string | null;                // partner-supplied, from the buy URL
  product?: { id: string; title: string } | null;
  city?: string | null;
  country?: string | null;
}

TransactionsResponse {
  summary: { total_count: number; total_commission: number };
                                          // total_commission = vendor net (after Channel3 take rate)
  items: Transaction[];
  page: number; limit: number; total_count: number; has_more: boolean;
  start_date: string; end_date: string;
}

Transaction {
  id: string;
  order_amount: number;
  commission_amount: number;              // vendor net
  status: "pending" | "paid";             // network-approved surfaces as pending
  purchased_at: string;                   // UTC
  user_id?: string | null;
  product?: { id: string; title: string } | null;
  brand_name?: string | null;
  city?: string | null;
  country?: string | null;
}
```
