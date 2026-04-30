# Channel3 API Reference (offline quick-card)

> **For full request/response schemas with try-it examples, see [docs.trychannel3.com/api-reference](https://docs.trychannel3.com/api-reference).** This file is a minimal offline backstop — endpoint signatures, the high-traffic `SearchFilters` / `SearchConfig` / `LocaleConfig` shapes, and compact response types.

**Base URL:** `https://api.trychannel3.com` · **Auth:** `x-api-key` header · `/v1` for products/brands/categories, `/v0` for price-tracking/websites.

## Contents

- Endpoint quick-cards (`/v1/search`, `/v1/similar`, `/v1/products/{id}`, `/v1/lookup`, price tracking, brands and websites, categories)
- `SearchFilters` shape
- `SearchConfig` and `LocaleConfig` shapes
- Core response types (`SearchResponse`, `ProductDetail`, `ProductOffer`, `Price`, `ProductImage`, `Brand`, `Website`, `PriceHistory`, `Subscription`, `AvailabilityStatus`, `CategorySummary`, `Category`, `CategoryRef`, `CategoryAttribute`)

For locale codes (languages, countries, currencies) and inference rules, see SKILL.md.

---

## Endpoint quick-cards

### `POST /v1/search`

Free-text and/or image search.

- **Body:** `query?` · `image_url?` · `base64_image?` · `limit?` (default 20, max 30) · `page_token?` · `filters?: SearchFilters` · `config?: SearchConfig`
- **Response:** `SearchResponse`
- **SDK:** `client.products.search({...})`

### `POST /v1/similar`

"More like this" from a Channel3 `product_id` you already have. Source product is excluded.

- **Body:** `product_id` (required) · `limit?` · `page_token?` · `filters?: SearchFilters` · `config?: LocaleConfig`
- **Response:** `SearchResponse`
- **Errors:** `404` (product not in catalog yet — fall back to `/v1/search` by title) · `402` (credits exhausted)
- **SDK:** `client.products.find_similar({...})`

### `GET /v1/products/{product_id}`

Full canonical product by ID.

- **Path:** `product_id`
- **Query:** `website_ids?` · `language?` · `country?` · `currency?`
- **Response:** `ProductDetail`
- **SDK:** `client.products.retrieve(productId, {...})`

### `POST /v1/lookup`

Resolve a merchant URL to the canonical `Product`. URL-only fallback.

- **Body:** `url` (required) · `max_staleness_hours?` (default 3)
- **Response:** `LookupResponse` (`{ product }`)
- **Errors:** `422` (not a product page) · `500` (extraction failed) · `504` (timeout). Typical latency 2–10s uncached.
- **SDK:** `client.products.lookup({ url, max_staleness_hours? })`

### Price tracking — `/v0/price-tracking/...`

- `POST /start` — body `{ canonical_product_id }` → `Subscription`
- `POST /stop` — body `{ canonical_product_id }` → `Subscription`
- `GET /history/{canonical_product_id}?days=` — up to 30 days → `PriceHistory`
- `GET /subscriptions?limit&cursor` → `CursorPage<Subscription>`
- **SDK:** `client.priceTracking.start | stop | retrieveHistory | listSubscriptions`

### Brands and websites

- `GET /v1/brands?limit&cursor` → `CursorPage<Brand>` · SDK: `client.brands.list({...})`
- `GET /v1/brands/{brand_id}` → `Brand` · SDK: `client.brands.retrieve(brandId)`
- `GET /v1/brands/search?query&limit` → `SearchBrandsResponse` (list, ordered by relevance; `limit` 1–20, default 5) · SDK: `client.brands.search({ query, limit? })`
- `GET /v0/websites?query=` → `Website | null` · SDK: `client.websites.retrieve({ query })`

### Categories — `/v1/categories*`

- `GET /v1/categories/search?query=&limit=` (`limit` 1–20, default 5) → `SearchCategoriesResponse` · SDK: `client.categories.search({ query, limit? })`
- `GET /v1/categories?roots_only=&page=&page_size=` (`page_size` 1–100, default 20; roots first) → `PaginatedListCategoriesResponse` · SDK: `client.categories.list({ roots_only?, page?, page_size? })`
- `GET /v1/categories/{slug}` → `Category` (404 if unknown). `slug` accepts a URL-friendly slug or an internal `category_id` · SDK: `client.categories.retrieve(slug)`

Use the resulting `slug` values anywhere `SearchFilters.category_ids` / `exclude_category_ids` is accepted.

---

## `SearchFilters`

The single most-typo'd shape in the API. Used by both `/v1/search` and `/v1/similar`.

| Field | Type | Description |
|---|---|---|
| `price` | `{ min_price?: number, max_price?: number }` | Price range in dollars |
| `brand_ids` | `string[]` | Include only these brands (use `client.brands.search` to obtain IDs) |
| `category_ids` | `string[]` | Include only these categories (descendants implicit). Use slugs; discover with `client.categories.search` |
| `website_ids` | `string[]` | Include only these retailer websites |
| `gender` | `"male" \| "female" \| "unisex"` | |
| `age` | `("newborn" \| "infant" \| "toddler" \| "kids" \| "adult")[]` | |
| `condition` | `"new" \| "refurbished" \| "used"` | |
| `availability` | `AvailabilityStatus[]` | Stock status filter |
| `exclude_brand_ids` | `string[]` | |
| `exclude_website_ids` | `string[]` | |
| `exclude_category_ids` | `string[]` | Excludes the category and its descendants. Slugs. |

## `SearchConfig`

`SearchConfig` extends `LocaleConfig` with one extra field:

| Field | Type | Description |
|---|---|---|
| `keyword_search_only` | `boolean` | Exact keyword match instead of semantic; incompatible with image input. Default `false`. |
| `language` | `LanguageCode \| null` | inherited from `LocaleConfig` |
| `country` | `CountryCode \| null` | inherited from `LocaleConfig` |
| `currency` | `CurrencyCode \| null` | inherited from `LocaleConfig` |

## `LocaleConfig`

```typescript
{
  language?: LanguageCode | null;
  country?: CountryCode | null;
  currency?: CurrencyCode | null;
}
```

Used as `config` on `/v1/similar` and as the locale base of `SearchConfig`. For the list of supported language / country / currency codes and inference rules, see SKILL.md.

---

## Core types

```typescript
SearchResponse {
  products: ProductDetail[];
  next_page_token?: string | null;        // null when no more results
}

LookupResponse {
  product: ProductDetail;
}

ProductDetail {
  id: string;
  title: string;
  description?: string | null;
  brands?: ProductBrand[];
  images?: ProductImage[];
  categories?: string[];
  gender?: "male" | "female" | "unisex" | null;
  age?: "newborn" | "infant" | "toddler" | "kids" | "adult" | null;
  materials?: string[] | null;
  key_features?: string[] | null;
  offers?: ProductOffer[];
}

ProductOffer {
  url: string;                            // affiliate-tracked
  domain: string;                         // e.g. "nordstrom.com"
  price: Price;
  availability: "InStock" | "OutOfStock";
  max_commission_rate?: number;           // fraction, 0.0–0.5 (0.05 = 5%)
}

Price {
  price: number;                          // post-discount
  currency: string;
  compare_at_price?: number | null;       // pre-discount
}

ProductImage {
  url: string;
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

AvailabilityStatus =                       // for SearchFilters.availability;
  "InStock" | "LimitedAvailability" | "PreOrder" | "BackOrder"
  | "SoldOut" | "OutOfStock" | "Discontinued" | "Unknown";
// Note: ProductOffer.availability on responses is simplified to "InStock" | "OutOfStock".

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
