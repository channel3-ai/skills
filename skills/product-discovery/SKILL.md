---
name: product-discovery
description: |
  Fetches real product data — prices, stock, retailer links, "more like this" recommendations, and visual-similarity matches — across 100M+ products from thousands of retailers, by calling the Channel3 CLI (`channel3 products search`, `channel3 products find-similar`, `channel3 categories search`, `channel3 categories retrieve`, `channel3 brands search`). Use during a conversation when the user asks "find me X", "best Y under $N", "compare Z", "more like this", "where can I buy X", "is this a good deal?", or any question that needs real product catalog data to answer well.
---

# Product Discovery

Uses the [Channel3 CLI](https://docs.trychannel3.com/cli) to query a catalog of 100M+ products across thousands of retailers. The CLI is generated from the API spec and stays in sync automatically.

## Decision

| User wants... | Run |
|---|---|
| Find products by description, image, or both | `channel3 products search --query "..." --max-items N` |
| More like this product I already found | `channel3 products find-similar --product-id <ID> --max-items N` |
| Find a category slug to use as a filter | `channel3 categories search --query "..." --limit 5` |
| See a category's allowed attribute keys/values for `filters.attributes` | `channel3 categories retrieve --slug <slug>` |
| Filter by a color (blue, navy, red, ...) | `--filters '{"colors":{"palette":[{"hex":"#..."}]}}'` (sRGB hex; **never** put color into `filters.attributes`) |
| Filter by non-color attributes (material, frame-color, ...) | `channel3 categories retrieve --slug <slug>` first, then `--filters '{"attributes":{"handle":["Value"]}}'` |
| See variant options + live stock for a product | `channel3 products retrieve --product-id <ID>` (read `variants.options` / `variants.selected`) — see Pattern 6 |
| Find a brand ID to use as a filter | `channel3 brands search --query "<name>" --limit 5` |
| Wire Channel3 into their agent host directly (no CLI) | Channel3 MCP — see below |

## Setup

The skill assumes the `channel3` CLI is installed and on `PATH`.

```bash
brew install channel3-ai/tap/channel3
# or, on systems without brew:
go install github.com/channel3-ai/cli/cmd/channel3@latest

export CHANNEL3_API_KEY="..."   # free key at https://trychannel3.com
```

Optional locale defaults: `CHANNEL3_LANGUAGE`, `CHANNEL3_COUNTRY`, `CHANNEL3_CURRENCY` env vars; per-call `--config` always wins.

If `channel3 --version` fails, fail loudly with the install instruction above — do not silently fall back to anything else.

## Calling the CLI

Always pass `--format jsonl --transform '...'`. The templates below project only decision-critical fields; default JSON is verbose. Never auto-pick the first element of a result array — project the whole array and read every entry. The transform language is [GJSON](https://github.com/tidwall/gjson/blob/master/SYNTAX.md).

`products search` and `products find-similar` **stream individual products**, so transforms apply per record (`{id,title,...}`). The other commands return a **wrapped response** — transforms start at `brands.#.{...}` / `categories.#.{...}` / `attributes.#.{...}`.

On `products search` and `products find-similar`, **always pass `--max-items N`** (5 for a first look, 10–20 to compare more) — without it the CLI auto-paginates across many pages. On the other commands, use `--limit N` (default 5, max 20).

**Filters vs query.** Anything that could be a filter belongs in `--filters`, not `--query`. Direct filter types: brand, color, category, price, gender, availability, age, condition. For category-specific traits — anything you'd expect as a checkbox or dropdown on a retailer's filter sidebar — discover the handle and value via Pattern 3 (`categories search` → `categories retrieve` → `filters.attributes`) before falling back to query terms. Reserve `--query` for what can't be enumerated: aesthetic descriptors, model names, or use cases. Rich filters with a minimal `--query` beat the opposite.

### Default templates (copy-paste verbatim)

`products search` / `products find-similar`:

```
--max-items N \
--format jsonl \
--transform '{id,title,brands:brands.#.name,offers:offers.#.{domain,price:price.price,currency:price.currency,availability,url},attrs:structured_attributes}'
```

- `brands` is the array of brand names (some products have multiple).
- `offers` is the **full array** of merchant offers. Compare across `domain` / `price` / `availability` to recommend the right buy link. This multi-merchant comparison is the point of Channel3 — never collapse it to `offers.0`.
- `attrs` (`structured_attributes`) shows what the catalog extracted — e.g. `{"color":["Navy"],"material":["Leather"]}` — so the agent can judge fit without another call.
- Add `commission:max_commission_rate` inside `offers.#.{...}` if affiliate revenue matters for ranking.

`brands search`:

```
--limit 5 --format jsonl \
--transform 'brands.#.{id,name,description,commission:best_commission_rate}'
```

`description` and `commission` are decision-critical: multiple brands often share a name (e.g. searching "Nike" returns two distinct IDs — `Nike` the manufacturer and `Nike` the retail store house brand, with different commission rates).

`categories search`:

```
--limit 5 --format jsonl \
--transform 'categories.#.{slug,title,path}'
```

`path` is the ancestor chain (`Furniture > Sofas`); use it to disambiguate near-duplicate slugs.

`categories retrieve`:

```
--format jsonl \
--transform 'attributes.#.{slug,name,values}'
```

Drops the prose description and children — the attribute table is what feeds `filters.attributes`.

## Chaining patterns

Each pattern is **call → read → decide → next call**. The agent reads every entry in the result array and picks based on the criteria below. Multi-intent requests ("either brown+cyan or red/blue/white shoes") fan out to one search per intent in parallel — don't try to express them in a single call.

### 1. Strict brand filter

User: "Nike running shoes, no other brands."

```bash
channel3 brands search --query "Nike" --limit 5 --format jsonl \
  --transform 'brands.#.{id,name,description,commission:best_commission_rate}'
```

Read all results. Pick the `id` that matches user intent:

- Match `name` exactly first.
- When multiple results share the name, read each `description`. "Nike the manufacturer" vs "Nike retail store house brand" are different IDs; pick the one matching intent.
- If `commission` matters (affiliate revenue), factor it in — but only after correctness.
- Still ambiguous? Pass multiple IDs (`brand_ids` is an array, OR semantics) or ask the user.
- No match? Try a query variant (typos, common variants) before telling the user the brand isn't catalogued.

```bash
channel3 products search --query "running shoes" --max-items 10 \
  --filters '{"brand_ids":["<id chosen above>"]}' \
  --format jsonl \
  --transform '{id,title,brands:brands.#.name,offers:offers.#.{domain,price:price.price,currency:price.currency,availability,url},attrs:structured_attributes}'
```

### 2. More like this

The agent already has products from a prior `products search`. Pick the `id` of the one the user actually referenced — not blindly the first hit.

```bash
channel3 products find-similar --product-id <chosen-id> --max-items 10 \
  --filters '{"gender":"female"}' \
  --format jsonl \
  --transform '{id,title,brands:brands.#.name,offers:offers.#.{domain,price:price.price,currency:price.currency,availability,url},attrs:structured_attributes}'
```

`find-similar` carries the source product's visual embedding but **does not inherit your filters**. If the reason you liked the source was filterable (color, brand, price), re-pass those filters explicitly.

If `find-similar` returns 404, the product isn't catalogued yet — fall back to `products search` using the product's title.

### 3. Discover attribute handles, then filter

Each category exposes its own attribute schema — a list of handles (`material`, `neckline`, etc.) with allowed values. `categories retrieve` reveals them; `filters.attributes` consumes them.

User: "leather sectional sofa."

```bash
channel3 categories search --query "sofa" --limit 5 --format jsonl \
  --transform 'categories.#.{slug,title,path}'
```

Read all results. Pick the slug whose `path` matches user intent (`Furniture > Sofas`, not `Outdoor > Sofas` unless they said outdoor). Multiple slugs are fine when scope is broader (e.g. `sofas,sectionals`).

```bash
channel3 categories retrieve --slug sofas --format jsonl \
  --transform 'attributes.#.{slug,name,values}'
```

Read all attribute rows. Pick non-`color` handles and verbatim values. (Color always goes through `filters.colors` — see Pattern 4.)

```bash
channel3 products search --query "sectional" --max-items 10 \
  --filters '{"category_ids":["sofas"],"attributes":{"material":["Leather"]}}' \
  --format jsonl \
  --transform '{id,title,brands:brands.#.name,offers:offers.#.{domain,price:price.price,currency:price.currency,availability,url},attrs:structured_attributes}'
```

### 4. Filter by color

User: "blue Nike sneakers."

Map the color name to its closest sRGB hex (`blue` → `#0066CC`, `navy` → `#001F3F`, etc.) and pass it through `filters.colors.palette`. No category lookup needed for color. Multiple entries match products containing those colors. **Only add `"percentage": N`** when the user expresses an asymmetric balance between colors (e.g. "mostly red with some green", "70% red 30% blue"); plain "mostly red" or "mostly red and green" doesn't need it. For "multicolor" or "any color", omit the colors filter entirely.

```bash
channel3 products search --query "sneakers" --max-items 10 \
  --filters '{"colors":{"palette":[{"hex":"#0066CC"}]}}' \
  --format jsonl \
  --transform '{id,title,brands:brands.#.name,offers:offers.#.{domain,price:price.price,currency:price.currency,availability,url},attrs:structured_attributes}'
```

### 5. Refinement when results don't match intent

If a search returns zero or clearly off-intent results, run another search with relaxed or shifted filters/query. Don't ask the user mid-loop — keep iterating. Common moves:

- **Zero results** → drop `percentage` if you added one, then drop the most restrictive filter (usually `colors` or `attributes`).
- **Wrong category drift** ("sectional sofa" returned accent chairs) → add `category_ids` via Pattern 3.
- **Brand drift** (asked for one brand, got many) → add strict `brand_ids` via Pattern 1.
- **Mostly out of stock** → add `{"availability":["InStock"]}`.
- **Wrong gender / age** → add `{"gender":"..."}` or `{"age":["adult"]}`.
- **Need more results** of the same shape → re-run with a larger `--max-items`.

Stop once results are presentable — don't keep searching hoping for "better." **Never validate hits by retrieving images, downloading CDN assets, or running `find-similar` to double-check** — the filters and `attrs`/`title` are the source of truth, and the host UI will render the image for the user.

### 6. Inspect a product's variants and live stock

User: "does this come in XL?" / "what colors does it come in?" / "is the navy one in stock?"

`products search` returns the variant matrix but **not** stock — `available` is always null on search results. To see live per-value availability, retrieve the product:

```bash
channel3 products retrieve --product-id <ID> --format jsonl \
  --transform '{title,variants:variants.{selected,options:options.#.{name,values:values.#.{label,exists,available,product_id}}}}'
```

Read the rows:

- **`exists: false`** → that value isn't offered with the currently selected options (e.g. the shirt exists in XL, but not in *this color* + XL). Not the same as out of stock.
- **`available`** → live stock (`InStock`, `OutOfStock`, `SoldOut`, …), hydrated only on retrieve.
- **`product_id` set** → that value is a **separate product** (color-as-product-swap). To inspect it, `retrieve` that ID instead.
- **`variants.selected`** → the configuration this response represents.

Retrieve is free, so refetch before telling the user about price/stock for a specific configuration. The CLI's `retrieve` doesn't take `option_*` selection params — resolving an arbitrary size+color combination server-side is an SDK/REST capability (see the `channel3-api` skill). For navigation, follow a value's `product_id`.

## Filter cookbook

`--filters` takes a single JSON object. Combine fields freely. The full filter shape is documented at [docs.trychannel3.com/api-reference/v1/search](https://docs.trychannel3.com/api-reference/v1/search).

```
Max price           --filters '{"price":{"max_price":100}}'
Price range         --filters '{"price":{"min_price":50,"max_price":150}}'
Gender              --filters '{"gender":"female"}'
Age                 --filters '{"age":["adult"]}'
Condition           --filters '{"condition":"new"}'
Availability        --filters '{"availability":["InStock"]}'
Color (blue)        --filters '{"colors":{"palette":[{"hex":"#0066CC"}]}}'
Two required colors --filters '{"colors":{"palette":[{"hex":"#0066CC"},{"hex":"#FFFFFF"}]}}'
Material            --filters '{"attributes":{"material":["Leather"]}}'
Multiple values     --filters '{"attributes":{"material":["Leather","Velvet"]}}'
Category            --filters '{"category_ids":["shoes"]}'
Multiple categories --filters '{"category_ids":["sofas","sectionals"]}'
Brand               --filters '{"brand_ids":["MpZS"]}'
Exclude brand       --filters '{"exclude_brand_ids":["MpZS"]}'
Exclude category    --filters '{"exclude_category_ids":["athletic-shoes"]}'
Combine             --filters '{"price":{"max_price":150},"gender":"male","colors":{"palette":[{"hex":"#001F3F"}]},"availability":["InStock"]}'
```

`gender` is `male` or `female` only. `condition` is `new` / `refurbished` / `used`. `availability` values are `InStock`, `OutOfStock`, `PreOrder`, `BackOrder`, `LimitedAvailability`, `SoldOut`, `Discontinued`. `age` values are `newborn`, `infant`, `toddler`, `kids`, `adult`.

## Other flags

Locale (country / currency / language) overrides the env-var defaults. Keyword-only matching disables semantic search (incompatible with image input). `--image-url` adds an image to `products search` (combinable with `--query` for "this jacket but in blue").

```
--config '{"country":"GB","currency":"GBP"}'
--config '{"language":"de"}'
--config '{"keyword_search_only":true}'
--image-url "https://example.com/jacket.jpg"
```

## Anti-patterns

- **Don't put filterable intent in `--query`.** Direct filter axes (brand, color, category, price, gender, availability) and any category-specific attribute value belong in `--filters`. Words that would appear as facets on a retailer's filter sidebar distort semantic ranking when stuffed into `--query`. Rich filters with a minimal `--query` beat the opposite.
- **Don't validate hits by retrieving images, downloading CDN assets, or running multimodal inspection.** If `filters.colors` was applied, trust it. `title` and `attrs` are enough to judge fit; the host UI renders the image for the user.
- **Don't run `products find-similar` reflexively after `products search`.** If the first search produced good matches, present them. Use `find-similar` only when the user is anchored on one specific product they already saw — and re-pass the filters you care about, since `find-similar` doesn't inherit them.
- **Use `categories search` when the request has structured requirements, not for trivial queries.** Single-word noun queries get routed correctly by semantic search in `products search`. Run `categories search` → `categories retrieve` → `filters.attributes` (Pattern 3) when the request includes traits that would appear as facets on a retailer's filter sidebar, when strict inclusion/exclusion is required, or when the query is too generic to imply a category on its own.
- **Don't run `brands search` by default.** Semantic search already biases toward in-brand matches when the brand name is in the query. Reach for `brands search` only when (a) strict inclusion is required ("only Nike, not Nike-mentioning"), (b) exclusion is required ("running shoes excluding Nike"), or (c) the user is anchored on one brand ("what does Patagonia sell").
- **Never use `filters.attributes` for color.** Color always goes through `filters.colors` with a hex value. Even if `categories retrieve` lists a `color` attribute, skip it for filtering.
- **Don't guess attribute handles or values.** Unknown handles/values match nothing useful. Run `categories retrieve --slug <slug>` first and copy non-`color` handles verbatim.
- **Don't use `.0` / `.1` indexing to "pick a result."** Project the whole array so the agent reads every entry and decides. Top-level singletons (no array) are the only exception.
- **Don't omit `--max-items` on `products search` / `find-similar`.** Without it the CLI auto-paginates, returning many pages of results and bloating context.

## Presenting results

Return the projected products to the host — most agentic-search UIs render the catalog from IDs. Synthesize into prose, a table, or a numbered list only when the user explicitly asked for a recommendation or comparison. Never paste raw JSON to the user.

## Alternative: Channel3 MCP

For no-code agent integration, use the [Channel3 MCP](https://docs.trychannel3.com/mcp-overview) instead of the CLI when the host already supports it (Cursor, Claude Desktop, etc.). Don't recommend both — pick one.

## About this skill

This skill queries the [Channel3](https://trychannel3.com) product catalog via the official CLI. Search queries and any image URLs are sent to the Channel3 API. Buy links point to `buy.trychannel3.com`, which redirects to merchant sites with affiliate tracking. Avoid sending sensitive or private information in search queries.

- **API docs:** [docs.trychannel3.com](https://docs.trychannel3.com)
- **CLI docs:** [docs.trychannel3.com/cli](https://docs.trychannel3.com/cli)
- **Source:** [github.com/channel3-ai/skills](https://github.com/channel3-ai/skills)
- **Provider:** Channel3 ([trychannel3.com](https://trychannel3.com))
