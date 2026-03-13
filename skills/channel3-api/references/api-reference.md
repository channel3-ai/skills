# Channel3 API Reference

Complete reference for all Channel3 API endpoints, types, and parameters.

**Base URL:** `https://api.trychannel3.com`
**Authentication:** `x-api-key` header

Search and product details use `/v1`. Enrich, price tracking, brands, and websites use `/v0`.

## Table of Contents

1. [Search](#search)
2. [Products](#products)
3. [Enrich](#enrich)
4. [Price Tracking](#price-tracking)
5. [Brands](#brands)
6. [Websites](#websites)
7. [Shared Types](#shared-types)

---

## Search

### `POST /v1/search`

Search for products using text, images, or both. Returns a paginated `SearchResponse`.

**Request Body (`SearchPerformParams`):**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `query` | `string \| null` | No | Search query — natural language or keywords |
| `image_url` | `string \| null` | No | URL of an image for visual similarity search |
| `base64_image` | `string \| null` | No | Base64-encoded image for visual similarity search |
| `limit` | `number \| null` | No | Number of results (default: 20, max: 30) |
| `page_token` | `string \| null` | No | Cursor from a previous `next_page_token` to fetch the next page |
| `filters` | `SearchFilters` | No | Product filters (see below) |
| `config` | `SearchConfig` | No | Search configuration (see below) |

**`SearchFilters`:**

| Field | Type | Description |
|-------|------|-------------|
| `price` | `{ min_price?: number, max_price?: number }` | Price range in dollars |
| `brand_ids` | `string[]` | Filter to specific brands by ID |
| `category_ids` | `string[]` | Filter to specific categories |
| `website_ids` | `string[]` | Filter to specific retailer websites |
| `gender` | `"male" \| "female" \| "unisex"` | Gender filter |
| `age` | `("newborn" \| "infant" \| "toddler" \| "kids" \| "adult")[]` | Age group filter |
| `condition` | `"new" \| "refurbished" \| "used"` | Product condition |
| `availability` | `AvailabilityStatus[]` | Filter by stock status |
| `exclude_brand_ids` | `string[]` | Exclude products from these brands |
| `exclude_website_ids` | `string[]` | Exclude products from these websites |
| `exclude_category_ids` | `string[]` | Exclude products in these categories (or their descendants) |

**`SearchConfig`:**

| Field | Type | Description |
|-------|------|-------------|
| `keyword_search_only` | `boolean` | Use exact keyword matching instead of semantic search. Incompatible with image search. |

**Response:** `SearchResponse`

**SDK Methods:**
- TypeScript: `client.search.perform({ ...params })` → `SearchResponse`
- Python sync: `client.search.perform(**params)` → `SearchResponse`
- Python async: `await client.search.perform(**params)` → `SearchResponse`

---

## Products

### `GET /v1/products/{product_id}`

Retrieve detailed information about a specific product.

**Path Parameters:**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `product_id` | `string` | Yes | The product ID |

**Query Parameters:**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `website_ids` | `string[]` | No | Constrain offers to specific merchant websites |

**Response:** `ProductDetail`

**SDK Methods:**
- TypeScript: `client.products.retrieve(productId, { ...params })` → `ProductDetail`
- Python: `client.products.retrieve(product_id, **params)` → `ProductDetail`

---

## Enrich

### `POST /v0/enrich`

Look up a product by its URL and return structured data. If the product isn't in Channel3's database, attempts real-time extraction with basic details. The response includes both legacy flat fields and the new `offers` array.

**Request Body:**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `url` | `string` | Yes | The product page URL to enrich |

**Response:** `EnrichResponse`

**SDK Methods:**
- TypeScript: `client.enrich.enrichURL({ url })` → `EnrichEnrichURLResponse`
- Python: `client.enrich.enrich_url(url="...")` → `EnrichEnrichURLResponse`

---

## Price Tracking

### `POST /v0/price-tracking/start`

Start tracking price changes for a product.

**Request Body:**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `canonical_product_id` | `string` | Yes | The product ID to track |

**Response:** `Subscription`

### `POST /v0/price-tracking/stop`

Stop tracking a product.

**Request Body:**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `canonical_product_id` | `string` | Yes | The product ID to stop tracking |

**Response:** `Subscription`

### `GET /v0/price-tracking/history/{canonical_product_id}`

Get price history and statistics for a tracked product.

**Path Parameters:**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `canonical_product_id` | `string` | Yes | The product ID |

**Query Parameters:**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `days` | `number` | No | Number of days of history (max 30) |

**Response:** `PriceHistory`

### `GET /v0/price-tracking/subscriptions`

List your active price tracking subscriptions. Cursor-paginated.

**Query Parameters:**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `limit` | `number` | No | Results per page |
| `cursor` | `string` | No | Pagination cursor from previous response |

**Response:** `CursorPage<Subscription>`

**SDK Methods:**
- TypeScript: `client.priceTracking.start({ canonical_product_id })`, `.stop()`, `.getHistory(id, { days })`, `.listSubscriptions()`
- Python: `client.price_tracking.start(canonical_product_id=...)`, `.stop()`, `.get_history(id, days=...)`, `.list_subscriptions()`

The `listSubscriptions()` method returns a `PagePromise` that supports `for await` iteration.

---

## Brands

### `GET /v0/list-brands`

List all brands alphabetically with cursor pagination.

**Query Parameters:**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `limit` | `number` | No | Results per page (1-100) |
| `cursor` | `string` | No | Cursor from previous response for next page |

**Response:** `CursorPage<Brand>`

### `GET /v0/brands/{brand_id}`

Retrieve a brand by ID.

**Path Parameters:**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `brand_id` | `string` | Yes | The brand ID |

**Response:** `Brand`

### `GET /v0/brands`

Find a specific brand by name.

**Query Parameters:**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `query` | `string` | Yes | Brand name to search for |

**Response:** `Brand`

**SDK Methods:**
- TypeScript: `client.brands.list({ limit, cursor })`, `client.brands.retrieve(brandId)`, `client.brands.find({ query })`
- Python: `client.brands.list(limit=..., cursor=...)`, `client.brands.retrieve(brand_id)`, `client.brands.find(query="...")`

The `list()` method returns a `PagePromise` that supports `for await` iteration.

---

## Websites

### `GET /v0/websites`

Find a retailer website.

**Query Parameters:**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `query` | `string` | Yes | Website URL or name to search for |

**Response:** `Website | null`

**SDK Methods:**
- TypeScript: `client.websites.find({ query })`
- Python: `client.websites.find(query="...")`

---

## Shared Types

### `ProductDetail`

Returned by search and product retrieve endpoints. A canonical product with offers from one or more merchants.

```typescript
{
  id: string;
  title: string;
  description?: string | null;
  brands?: ProductBrand[];
  images?: ProductImage[];
  categories?: string[];
  gender?: "male" | "female" | "unisex" | null;
  materials?: string[] | null;
  key_features?: string[] | null;
  offers?: ProductOffer[];
}
```

### `ProductOffer`

A single merchant's offer for a product.

```typescript
{
  url: string;                          // Affiliate-tracked buy link
  domain: string;                       // Merchant domain, e.g. "nordstrom.com"
  price: Price;
  availability: "InStock" | "OutOfStock";
  max_commission_rate?: number;         // 0.0 = none, 0.5 = 50%
}
```

### `ProductBrand`

```typescript
{
  id: string;
  name: string;
}
```

### `Price`

```typescript
{
  price: number;                        // Current price (after discounts)
  currency: string;                     // e.g., "USD", "EUR", "GBP"
  compare_at_price?: number | null;     // Original pre-discount price
}
```

### `ProductImage`

```typescript
{
  url: string;
  alt_text?: string | null;
  is_main_image?: boolean;
  shot_type?: "hero" | "lifestyle" | "on_model" | "detail" | "scale_reference"
            | "angle_view" | "flat_lay" | "in_use" | "packaging" | "size_chart"
            | "product_information" | "merchant_information" | null;
}
```

### `SearchResponse`

```typescript
{
  products: ProductDetail[];
  next_page_token?: string | null;      // Null when no more results
}
```

### `EnrichResponse`

Returned by the enrich endpoint. Includes `offers` alongside legacy flat fields for backwards compatibility.

```typescript
{
  id: string;
  title: string;
  description?: string | null;
  brands?: ProductBrand[];
  images?: EnrichImage[];
  categories?: string[];
  gender?: "male" | "female" | "unisex" | null;
  materials?: string[] | null;
  key_features?: string[] | null;
  offers?: ProductOffer[];
  url: string;                          // DEPRECATED — use offers[].url
  price: Price;                         // DEPRECATED — use offers[].price
  availability: "InStock" | "OutOfStock"; // DEPRECATED — use offers[].availability
  brand_id?: string | null;             // DEPRECATED — use brands[]
  brand_name?: string | null;           // DEPRECATED — use brands[]
  image_urls?: string[];                // DEPRECATED — use images[]
  variants?: Variant[];                 // DEPRECATED — always empty
}
```

### `Brand`

```typescript
{
  id: string;
  name: string;
  best_commission_rate?: number;        // Max commission percentage
  description?: string | null;
  logo_url?: string | null;
}
```

### `Website`

```typescript
{
  id: string;
  url: string;
  best_commission_rate?: number;        // Max commission percentage
}
```

### `AvailabilityStatus`

Used in search filters. Offer availability is simplified to `"InStock" | "OutOfStock"`.

```typescript
"InStock" | "LimitedAvailability" | "PreOrder" | "BackOrder"
| "SoldOut" | "OutOfStock" | "Discontinued" | "Unknown"
```

### `PriceHistory`

```typescript
{
  canonical_product_id: string;
  product_title?: string | null;
  history?: Array<{
    price: number;
    currency: string;
    timestamp: string;                  // ISO 8601
  }>;
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
```

### `Subscription`

```typescript
{
  canonical_product_id: string;
  created_at: string;                   // ISO 8601
  subscription_status: "active" | "cancelled";
}
```
