# Channel3 API Reference

Complete reference for all Channel3 API endpoints, types, and parameters.

**Base URL:** `https://api.trychannel3.com/v0`
**Authentication:** `x-api-key` header

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

### `POST /v0/search`

Search for products using text, images, or both.

**Request Body (`SearchPerformParams`):**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `query` | `string \| null` | No | Search query — natural language or keywords |
| `image_url` | `string \| null` | No | URL of an image for visual similarity search |
| `base64_image` | `string \| null` | No | Base64-encoded image for visual similarity search |
| `context` | `string \| null` | No | Personalization context (e.g., "gift for a hiker") |
| `limit` | `number \| null` | No | Number of results (default: 20, max: 30) |
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
| `exclude_product_ids` | `string[]` | Product IDs to exclude from results |

**`SearchConfig`:**

| Field | Type | Description |
|-------|------|-------------|
| `redirect_mode` | `"brand" \| "price" \| "commission"` | Controls affiliate link routing. `"price"` = lowest price, `"commission"` = highest commission, `"brand"` = brand page |
| `keyword_search_only` | `boolean` | Use exact keyword matching instead of semantic search. Incompatible with image search. |

**Response:** `Product[]` (array of Product objects)

**SDK Methods:**
- TypeScript: `client.search.perform({ ...params })`
- Python sync: `client.search.perform(**params)`
- Python async: `await client.search.perform(**params)`

---

## Products

### `GET /v0/products/{product_id}`

Retrieve detailed information about a specific product.

**Path Parameters:**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `product_id` | `string` | Yes | The product ID |

**Query Parameters:**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `redirect_mode` | `RedirectMode` | No | Affiliate link routing mode |
| `website_ids` | `string[]` | No | Constrain to specific merchant websites |

**Response:** `ProductDetail`

**SDK Methods:**
- TypeScript: `client.products.retrieve(productId, { ...params })`
- Python: `client.products.retrieve(product_id, **params)`

---

## Enrich

### `POST /v0/enrich`

Look up a product by its URL and return structured data. If the product isn't in Channel3's database, attempts real-time extraction with basic details.

**Request Body:**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `url` | `string` | Yes | The product page URL to enrich |

**Response:** `ProductDetail`

**SDK Methods:**
- TypeScript: `client.enrich.enrichURL({ url })`
- Python: `client.enrich.enrich_url(url="...")`

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

List your active price tracking subscriptions.

**Query Parameters:**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `limit` | `number` | No | Results per page |
| `page_token` | `string` | No | Pagination cursor |

**Response:** `PaginatedSubscriptions`

**SDK Methods:**
- TypeScript: `client.priceTracking.start({ canonical_product_id })`, `.stop()`, `.getHistory(id, { days })`, `.listSubscriptions()`
- Python: `client.price_tracking.start(canonical_product_id=...)`, `.stop()`, `.get_history(id, days=...)`, `.list_subscriptions()`

---

## Brands

### `GET /v0/list-brands`

List all brands alphabetically with pagination.

**Query Parameters:**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `limit` | `number` | No | Results per page (1-100) |
| `paging_token` | `string` | No | Cursor for next page |

**Response:** `PaginatedListBrandsResponse`

### `GET /v0/brands`

Find a specific brand by name.

**Query Parameters:**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `query` | `string` | Yes | Brand name to search for |

**Response:** `Brand`

**SDK Methods:**
- TypeScript: `client.brands.list({ limit, paging_token })`, `client.brands.find({ query })`
- Python: `client.brands.list(limit=..., paging_token=...)`, `client.brands.find(query="...")`

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

### `Product`

Returned by the search endpoint.

```typescript
{
  id: string;
  title: string;
  url: string;                          // Affiliate-tracked link
  price: Price;
  availability: AvailabilityStatus;
  score: number;                        // Relevance score
  brand_id?: string | null;
  brand_name?: string | null;
  categories?: string[];
  description?: string | null;
  gender?: "male" | "female" | "unisex" | null;
  images?: Image[];
  key_features?: string[] | null;
  materials?: string[] | null;
  variants?: Variant[];
  image_url?: string;                   // DEPRECATED — use images[] instead
  image_urls?: string[];                // DEPRECATED — use images[] instead
}
```

### `ProductDetail`

Returned by the product retrieve and enrich endpoints. Same as `Product` but without `score` or deprecated `image_url` field.

### `Price`

```typescript
{
  price: number;                        // Current price (after discounts)
  currency: string;                     // e.g., "USD", "EUR", "GBP"
  compare_at_price?: number | null;     // Original pre-discount price
}
```

### `Image`

```typescript
{
  url: string;
  alt_text?: string | null;
  is_main_image?: boolean;
  photo_quality?: "professional" | "ugc" | "poor" | null;
  shot_type?: "hero" | "lifestyle" | "on_model" | "detail" | "scale_reference"
            | "angle_view" | "flat_lay" | "in_use" | "packaging" | "size_chart"
            | "color_swatch" | "product_information" | "merchant_information" | null;
}
```

### `Variant`

```typescript
{
  product_id: string;
  title: string;
  image_url: string;
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

```typescript
"InStock" | "LimitedAvailability" | "PreOrder" | "BackOrder"
| "SoldOut" | "OutOfStock" | "Discontinued" | "Unknown"
```

### `RedirectMode`

```typescript
"brand" | "price" | "commission"
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

### `PaginatedSubscriptions`

```typescript
{
  subscriptions: Subscription[];
  next_page_token?: string | null;
}
```

### `PaginatedListBrandsResponse`

```typescript
{
  items: Brand[];
  paging_token?: string | null;         // null when no more results
}
```
