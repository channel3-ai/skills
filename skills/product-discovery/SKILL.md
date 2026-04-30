---
name: product-discovery
description: |
  Fetches real product data — prices, stock, retailer links, "more like this" recommendations, and visual-similarity matches — across 100M+ products from thousands of retailers, by running bundled scripts (`search.sh`, `similar.sh`, `categories.sh`, `brands.sh`). Use during a conversation when the user asks "find me X", "best Y under $N", "compare Z", "more like this", "where can I buy X", "is this a good deal?", or any question that needs real product catalog data to answer well.
---

# Product Discovery

Four scripts query a catalog of 100M+ products across thousands of retailers.

## Decision

| User wants... | Use |
|---|---|
| Find products by description, image, or both | `search.sh` |
| More like this product I already found | `similar.sh --id <ID>` |
| Find a category slug to use as a filter | `categories.sh "query"` |
| Find a brand ID to use as a filter | `brands.sh "name"` |
| Wire Channel3 into their agent host directly (no scripts) | Channel3 MCP — see below |

## Anti-patterns

- **`similar.sh` requires a Channel3 product ID** (the `ID:` field from a previous `search.sh` result). Don't use it for "find me visually similar products to this image" — that's `search.sh -i <URL>`.
- **Don't run `search.sh` then `similar.sh` reflexively.** If the first `search.sh` already produced good matches, present them; the user didn't ask for "more like the first hit". Use `similar.sh` only when the user is anchored on one specific product.
- **When `similar.sh` returns 404**, the product isn't in the catalog yet. Fall back to `search.sh` with the product's title or category.
- **Don't run `categories.sh` by default.** Semantic search in `search.sh` already routes "bags" to bag products and "running shoes" to running shoes — no slug lookup needed. Reach for `categories.sh` when (a) strict inclusion/exclusion is required ("only handbags", "exclude electronics"), or (b) the query is too generic to imply the right categories on its own ("gifts under $50" scoped to a department).
- **Don't run `brands.sh` by default.** Semantic search in `search.sh` already biases toward in-brand matches when the brand name is in the query. Reach for `brands.sh` only when (a) strict inclusion is required ("only Nike, not Nike-mentioning"), (b) exclusion is required ("running shoes excluding Nike"), or (c) the user is anchored on one brand and asking "what does X sell".

## Alternative: Channel3 MCP

The Channel3 MCP (`https://mcp.trychannel3.com/`, free tier; append `?apiKey=<key>` for pay-as-you-go) is functionally overlapping with these scripts. If the user already has it wired into their host (Cursor, Claude Code, etc.), use that instead — see [docs.trychannel3.com/mcp-overview](https://docs.trychannel3.com/mcp-overview). Don't recommend both.

## search.sh

```
search.sh [OPTIONS] "query text"
```

The query argument is optional when using `-i` for image-only search. Text and image can be combined.

| Flag | Description |
|---|---|
| `-n NUM` | Number of results (default: 5, max: 30) |
| `-p MAX_PRICE` / `--min-price MIN` | Price range (dollars) |
| `-g GENDER` | `male` / `female` / `unisex` |
| `-c CONDITION` | `new` / `refurbished` / `used` |
| `-a AGE` | Comma-separated: `newborn`, `infant`, `toddler`, `kids`, `adult` |
| `--availability STATUS` | Comma-separated: `InStock`, `OutOfStock`, `PreOrder`, `BackOrder`, `LimitedAvailability`, `SoldOut`, `Discontinued` |
| `-i IMAGE_URL` | Visual similarity search (combinable with text) |
| `-b` / `-w` / `--categories` | Inclusion filters: brand IDs / website IDs / category slugs (comma-separated) |
| `--exclude-brands` / `--exclude-websites` / `--exclude-categories` | Exclusion filters |
| `--keyword-only` | Exact keyword matching, no semantic search (incompatible with `-i`) |
| `--country` / `--currency` / `--language` | ISO 3166-1 / 4217 / 639-1 codes |
| `--next TOKEN` | Pagination token from a previous response |

```bash
search.sh -p 100 -n 10 "running shoes"                              # basic + filtered
search.sh --categories shoes -p 150 "lightweight trainers"          # filter by category slug
search.sh -i "https://example.com/jacket.jpg" "similar but in blue" # image + text
search.sh --country GB --currency GBP "raincoat"                    # locale override
```

Category slugs are stable, URL-friendly IDs (e.g. `shoes`, `sofas`, `handbags`). The taxonomy doesn't have a leaf for every conceivable subcategory, and unknown slugs are silently dropped — always discover real slugs with `categories.sh "<query>"` rather than guessing. Browse the full tree at [docs.trychannel3.com/categories](https://docs.trychannel3.com/categories).

Reference: [docs.trychannel3.com/api-reference/v1/search](https://docs.trychannel3.com/api-reference/v1/search)

## similar.sh

Use after `search.sh` (or any other path) has located a product. `--id` is the canonical product ID — the `ID:` field in `search.sh` output.

```
similar.sh --id PRODUCT_ID [OPTIONS]
```

All `search.sh` filter / locale / pagination flags work here too, except `-i IMAGE_URL` and `--keyword-only` (neither applies). Filters are recommended to keep results in the same slice (gender, brand, price ceiling, etc.).

```bash
similar.sh --id prod_abc123                                  # basic
similar.sh --id prod_abc123 -g female -p 200                 # narrowed
similar.sh --id prod_abc123 --country GB --currency GBP      # locale override
```

Reference: [docs.trychannel3.com/api-reference/v1/similar-products](https://docs.trychannel3.com/api-reference/v1/similar-products)

## categories.sh

Find one or more category slugs to feed back into `search.sh` / `similar.sh` `--categories` (comma-separated). Pick multiple slugs when the user's scope spans more than one category (e.g. `handbags,backpacks,duffel-bags`).

```
categories.sh [-n NUM] "query text"
```

| Flag | Description |
|---|---|
| `-n NUM` | Number of results (default: 5, max: 20) |

```bash
categories.sh "running shoes"   # find matching category slugs
categories.sh -n 10 "bags"      # broader exploration; pick the slugs that match intent
```

Output is a numbered list with `Slug`, `Path` (root → self, separated by ` > `), and `Has children: yes` when the match has subcategories. Empty results print `No categories found.`. Internal IDs also work in `--categories`, but slugs from this script are the canonical identifier.

Reference: [docs.trychannel3.com/api-reference/v1/search-categories](https://docs.trychannel3.com/api-reference/v1/search-categories) · Browse the full tree at [docs.trychannel3.com/categories](https://docs.trychannel3.com/categories)

## brands.sh

Find one or more brand IDs to feed back into `search.sh` / `similar.sh` `-b` (or `--exclude-brands`). Returns matches ordered by relevance.

```
brands.sh [-n NUM] "brand name"
```

| Flag | Description |
|---|---|
| `-n NUM` | Number of results (default: 5, max: 20) |

```bash
brands.sh "Nike"          # find brand ID for filtering
brands.sh -n 10 "Adidas"  # broader exploration; pick the row that matches intent
```

Output is a numbered list with `Name`, `ID`, optional `Description`, and optional `Best commission: X%`. Empty results print `No brands found.`.

Reference: [docs.trychannel3.com/api-reference/v1/search-brands](https://docs.trychannel3.com/api-reference/v1/search-brands)

## Output Format

`search.sh` and `similar.sh` emit the same product format below. `categories.sh` has its own format documented in its section. Synthesize all output; never paste it raw.

```
Found 5 products (next_page: tok_abc123)

1. Nike Air Zoom Pegasus 41
   ID: prod_abc123
   Brands: Nike
   Offers:
     - nordstrom.com: $89.99 (InStock) https://buy.trychannel3.com/...
     - nike.com: $94.99 (InStock) https://buy.trychannel3.com/...

2. Adidas Ultraboost Light
   ID: prod_def456
   Brands: Adidas
   Offers:
     - adidas.com: $97.00 (InStock) https://buy.trychannel3.com/...
```

Empty result paths print `No products found.` / `No similar products found.`. Auth or quota issues print actionable instructions and exit non-zero.

## Workflow patterns

### Find products

User: "find me running shoes under $100" → `search.sh -p 100 "running shoes"` → present a numbered list with name, price, merchant, buy link.

### More like this

User: "more like the first one" / "find similar":

1. Pick up the `ID:` of the anchored product from a previous `search.sh` (or run `search.sh` first if they only described it).
2. `similar.sh --id <ID>` with any narrowing the user implied (`-g`, `-p`, `--exclude-brands`, etc.).
3. Frame the response as "Similar to <source title>:".

### Different locale

User: "raincoat in the UK" → `search.sh --country GB --currency GBP "raincoat"`. Same flags work for `similar.sh`.

### Filter by category

Most queries don't need this — `search.sh "bags"` already returns bags. Reach for it when the query needs explicit constraints: strict inclusion ("only handbags"), explicit exclusion ("running shoes excluding casual sneakers"), or a generic query that isn't self-narrowing ("gifts under $50" scoped to a department).

1. `categories.sh "<term>"` → grab one or more `Slug` values that match the user's intent. Multiple slugs are fine when the scope spans, e.g. `handbags,backpacks`. Don't guess slugs; unknown slugs are silently dropped, not errored.
2. `search.sh --categories <slug1>,<slug2> "<query>"` (or `similar.sh --id <ID> --categories <slug>`, or `--exclude-categories <slug>` for the inverse).

### Filter by brand

Most queries don't need this — `search.sh "Nike running shoes"` already biases toward Nike products. Reach for it when the constraint is strict ("only Nike, not Nike-mentioning"), inverted ("running shoes excluding Nike"), or the user is anchored on a brand ("what does Patagonia sell").

1. `brands.sh "<name>"` → grab the `ID:` of the right brand. Multiple IDs are fine if the user means several brands.
2. `search.sh -b <id1>,<id2> "<query>"` (or `similar.sh --id <ID> -b <id>`, or `--exclude-brands <id>` for the inverse).

### Get more results

Copy `next_page` from the previous output → `search.sh --next "<TOKEN>" "original query"` (or `similar.sh --id <ID> --next "<TOKEN>"`).

## How to present results

- Numbered list or markdown table — whichever fits the ask.
- Always include name, price, merchant, buy link.
- Highlight the cheapest merchant when multiple offer the same product.
- Keep it concise — recommendations, not a data dump.

## Setup

- **API key:** `CHANNEL3_API_KEY` env var. Free key at [trychannel3.com](https://trychannel3.com).
- **Dependencies:** `curl` and `jq`.

## About this skill

This skill queries the [Channel3](https://trychannel3.com) product catalog API (`api.trychannel3.com`). Search queries and any image URLs you provide are sent to this third-party API. Buy links point to `buy.trychannel3.com`, which redirects to merchant sites with affiliate tracking. Avoid sending sensitive or private information in search queries.

- **API docs:** [docs.trychannel3.com](https://docs.trychannel3.com)
- **Source:** [github.com/channel3-ai/skills](https://github.com/channel3-ai/skills)
- **Provider:** Channel3 ([trychannel3.com](https://trychannel3.com))
