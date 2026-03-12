---
name: product-discovery
description: |
  Use this skill when you need real product data to answer a user's question — finding products, comparing prices, recommending items, or checking availability across retailers. This skill gives you a search script that queries a catalog of millions of products and returns structured results.

  Trigger for: "find me X", "what's the best Y", "compare Z", "best X under $N", product recommendations, price lookups, "is this a good deal?", "where can I buy X", shopping queries, product comparisons, and any task where you need real product catalog data to answer the user.
---

# Product Discovery

You have access to a product search script that queries a catalog of millions of products across thousands of retailers. Use it whenever you need real product data to answer a user's question.

## Search Script

**Location:** `product-discovery/scripts/search.sh` (relative to the skill root)

Run it via the shell. The script requires `curl` and `jq`.

### Usage

```
search.sh [OPTIONS] "query text"
```

### Options

| Flag | Description | Example |
|------|-------------|---------|
| `-n NUM` | Number of results (default: 5, max: 30) | `-n 10` |
| `-p MAX_PRICE` | Maximum price in dollars | `-p 100` |
| `--min-price MIN` | Minimum price in dollars | `--min-price 50` |
| `-g GENDER` | Gender filter (male/female/unisex) | `-g male` |
| `-c CONDITION` | Product condition (new/refurbished/used) | `-c new` |
| `-a AGE` | Comma-separated age groups (newborn/infant/toddler/kids/adult) | `-a "kids,toddler"` |
| `--availability STATUS` | Comma-separated availability statuses (InStock/OutOfStock/PreOrder/BackOrder/LimitedAvailability/SoldOut/Discontinued) | `--availability "InStock"` |
| `-i IMAGE_URL` | Search by image (visual similarity) | `-i "https://example.com/photo.jpg"` |
| `-b BRAND_IDS` | Comma-separated brand IDs to include | `-b "brand_abc,brand_def"` |
| `-w WEBSITE_IDS` | Comma-separated website IDs to include | `-w "website_abc"` |
| `--categories IDS` | Comma-separated category IDs to include | `--categories "cat_abc"` |
| `--exclude-brands IDS` | Comma-separated brand IDs to exclude | `--exclude-brands "brand_xyz"` |
| `--exclude-websites IDS` | Comma-separated website IDs to exclude | `--exclude-websites "website_xyz"` |
| `--exclude-categories IDS` | Comma-separated category IDs to exclude | `--exclude-categories "cat_xyz"` |
| `--keyword-only` | Use exact keyword matching instead of semantic search | `--keyword-only` |
| `--next TOKEN` | Pagination token from a previous search | `--next "tok_abc..."` |

The query argument is optional when using `-i` for image-only search. Text and image can be combined.

### Examples

```bash
# Basic text search
search.sh "wireless noise cancelling headphones"

# Price-filtered search
search.sh -p 100 -n 10 "running shoes"

# Price range search
search.sh --min-price 50 -p 200 "winter boots"

# Gendered search
search.sh -g female -p 200 "winter jacket"

# Condition filter
search.sh -c used "macbook pro"

# Kids products
search.sh -a kids -p 50 "sneakers"

# Only in-stock products
search.sh --availability "InStock" "yoga mat"

# Image-based visual similarity search
search.sh -i "https://example.com/dress.jpg"

# Combined text + image search
search.sh -i "https://example.com/jacket.jpg" "similar but in blue"

# Keyword-only (exact match, no semantic search)
search.sh --keyword-only "Nike Air Max 90"

# Paginate for more results
search.sh --next "tok_abc123..." "running shoes"
```

### Output Format

The script outputs structured text, not raw JSON. Each product includes its ID, brands, and all merchant offers with prices and buy links:

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

If no results are found, the output is: `No products found.`

If the API key is missing or invalid, the script prints instructions on how to get one.

## Workflow Patterns

### Find products

User asks "find me running shoes under $100":

1. Run: `search.sh -p 100 "running shoes"`
2. Present the results as a clean numbered list with product name, price, merchant, and buy link.

### Compare products

User asks "compare AirPods Pro vs Sony WF-1000XM5":

1. Run two searches: `search.sh -n 3 "AirPods Pro"` and `search.sh -n 3 "Sony WF-1000XM5"`
2. Build a markdown comparison table with columns for product, price, merchants, and availability.

### Best option under a budget

User asks "what's the best laptop under $800":

1. Run: `search.sh -p 800 -n 10 "laptop"`
2. Review the results and recommend the top picks, explaining why based on the product details.

### Image-based search

User shares an image URL and says "find me something like this":

1. Run: `search.sh -i "IMAGE_URL"`
2. Present visually similar products with prices and links.

### Get more results

If the user wants more results after an initial search:

1. Copy the `next_page` token from the previous output.
2. Run: `search.sh --next "TOKEN" "original query"`
3. Present the additional results.

## How to Present Results to the User

- Synthesize the script output into a clean response. Do NOT paste the raw script output.
- Present products as a numbered list or markdown table — whichever fits the question better.
- Always include: product name, price, merchant name, and the buy link URL.
- For comparisons, use a markdown table with columns like Product, Price, Merchant, and Link.
- If multiple merchants sell the same product at different prices, highlight the cheapest option.
- Keep it concise — the user wants recommendations, not a data dump.
