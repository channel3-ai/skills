#!/usr/bin/env bash
set -euo pipefail

# ── Parse arguments ───────────────────────────────────────────────────

LIMIT=5
PRODUCT_ID=""
MIN_PRICE=""
MAX_PRICE=""
GENDER=""
CONDITION=""
AGE=""
AVAILABILITY=""
BRAND_IDS=""
WEBSITE_IDS=""
CATEGORY_IDS=""
EXCLUDE_BRAND_IDS=""
EXCLUDE_WEBSITE_IDS=""
EXCLUDE_CATEGORY_IDS=""
COUNTRY=""
CURRENCY=""
LANGUAGE=""
PAGE_TOKEN=""

usage() {
  echo "Usage: similar.sh --id PRODUCT_ID [OPTIONS]"
  echo ""
  echo "Find products similar to a given canonical product."
  echo ""
  echo "Options:"
  echo "  --id PRODUCT_ID         Canonical product ID to find similar products for (required)"
  echo "  -n NUM                  Number of results (default: 5, max: 30)"
  echo "  -p MAX_PRICE            Maximum price in dollars"
  echo "  --min-price MIN         Minimum price in dollars"
  echo "  -g GENDER               Gender filter (male/female/unisex)"
  echo "  -c CONDITION            Condition (new/refurbished/used)"
  echo "  -a AGE                  Comma-separated age groups (newborn/infant/toddler/kids/adult)"
  echo "  --availability STATUS   Comma-separated statuses (InStock/OutOfStock/PreOrder/BackOrder/...)"
  echo "  -b BRAND_IDS            Comma-separated brand IDs to include"
  echo "  -w WEBSITE_IDS          Comma-separated website IDs to include"
  echo "  --categories SLUGS      Comma-separated category slugs to include"
  echo "  --exclude-brands IDS    Comma-separated brand IDs to exclude"
  echo "  --exclude-websites IDS  Comma-separated website IDs to exclude"
  echo "  --exclude-categories SLUGS Comma-separated category slugs to exclude"
  echo "  --country CODE          ISO 3166-1 alpha-2 country code (e.g. GB, DE)"
  echo "  --currency CODE         ISO 4217 currency code (e.g. GBP, EUR)"
  echo "  --language CODE         ISO 639-1 language code (e.g. en, de)"
  echo "  --next TOKEN            Pagination token from a previous response"
  echo "  -h                      Show this help"
  exit "${1:-0}"
}

for arg in "$@"; do
  case "$arg" in -h|--help) usage ;; esac
done

if ! command -v jq &>/dev/null; then
  echo "ERROR: jq is required but not installed."
  echo ""
  echo "Install it:"
  echo "  macOS:  brew install jq"
  echo "  Ubuntu: sudo apt-get install jq"
  exit 1
fi

while [[ $# -gt 0 ]]; do
  case "$1" in
    --id) PRODUCT_ID="$2"; shift 2 ;;
    -n) LIMIT="$2"; shift 2 ;;
    -p) MAX_PRICE="$2"; shift 2 ;;
    --min-price) MIN_PRICE="$2"; shift 2 ;;
    -g) GENDER="$2"; shift 2 ;;
    -c) CONDITION="$2"; shift 2 ;;
    -a) AGE="$2"; shift 2 ;;
    --availability) AVAILABILITY="$2"; shift 2 ;;
    -b) BRAND_IDS="$2"; shift 2 ;;
    -w) WEBSITE_IDS="$2"; shift 2 ;;
    --categories) CATEGORY_IDS="$2"; shift 2 ;;
    --exclude-brands) EXCLUDE_BRAND_IDS="$2"; shift 2 ;;
    --exclude-websites) EXCLUDE_WEBSITE_IDS="$2"; shift 2 ;;
    --exclude-categories) EXCLUDE_CATEGORY_IDS="$2"; shift 2 ;;
    --country) COUNTRY="$2"; shift 2 ;;
    --currency) CURRENCY="$2"; shift 2 ;;
    --language) LANGUAGE="$2"; shift 2 ;;
    --next) PAGE_TOKEN="$2"; shift 2 ;;
    -h|--help) usage ;;
    -*) echo "Unknown option: $1"; usage 1 ;;
    *) echo "Unexpected positional argument: $1"; usage 1 ;;
  esac
done

if [ -z "$PRODUCT_ID" ]; then
  echo "ERROR: --id PRODUCT_ID is required."
  echo ""
  usage 1
fi

# ── Build JSON request body ───────────────────────────────────────────

build_body() {
  local body="{}"
  body=$(echo "$body" | jq --arg id "$PRODUCT_ID" '.product_id = $id')
  body=$(echo "$body" | jq --argjson limit "$LIMIT" '.limit = $limit')

  if [ -n "$PAGE_TOKEN" ]; then
    body=$(echo "$body" | jq --arg t "$PAGE_TOKEN" '.page_token = $t')
  fi

  local config="{}"
  local has_config=false

  if [ -n "$COUNTRY" ]; then
    config=$(echo "$config" | jq --arg c "$COUNTRY" '.country = $c')
    has_config=true
  fi

  if [ -n "$CURRENCY" ]; then
    config=$(echo "$config" | jq --arg c "$CURRENCY" '.currency = $c')
    has_config=true
  fi

  if [ -n "$LANGUAGE" ]; then
    config=$(echo "$config" | jq --arg l "$LANGUAGE" '.language = $l')
    has_config=true
  fi

  if [ "$has_config" = true ]; then
    body=$(echo "$body" | jq --argjson c "$config" '.config = $c')
  fi

  local filters="{}"
  local has_filters=false

  if [ -n "$MIN_PRICE" ] || [ -n "$MAX_PRICE" ]; then
    local price="{}"
    if [ -n "$MIN_PRICE" ]; then
      price=$(echo "$price" | jq --argjson p "$MIN_PRICE" '.min_price = $p')
    fi
    if [ -n "$MAX_PRICE" ]; then
      price=$(echo "$price" | jq --argjson p "$MAX_PRICE" '.max_price = $p')
    fi
    filters=$(echo "$filters" | jq --argjson p "$price" '.price = $p')
    has_filters=true
  fi

  if [ -n "$GENDER" ]; then
    filters=$(echo "$filters" | jq --arg g "$GENDER" '.gender = $g')
    has_filters=true
  fi

  if [ -n "$CONDITION" ]; then
    filters=$(echo "$filters" | jq --arg c "$CONDITION" '.condition = $c')
    has_filters=true
  fi

  if [ -n "$AGE" ]; then
    local arr
    arr=$(echo "$AGE" | jq -R 'split(",")')
    filters=$(echo "$filters" | jq --argjson a "$arr" '.age = $a')
    has_filters=true
  fi

  if [ -n "$AVAILABILITY" ]; then
    local arr
    arr=$(echo "$AVAILABILITY" | jq -R 'split(",")')
    filters=$(echo "$filters" | jq --argjson a "$arr" '.availability = $a')
    has_filters=true
  fi

  if [ -n "$BRAND_IDS" ]; then
    local arr
    arr=$(echo "$BRAND_IDS" | jq -R 'split(",")')
    filters=$(echo "$filters" | jq --argjson b "$arr" '.brand_ids = $b')
    has_filters=true
  fi

  if [ -n "$WEBSITE_IDS" ]; then
    local arr
    arr=$(echo "$WEBSITE_IDS" | jq -R 'split(",")')
    filters=$(echo "$filters" | jq --argjson w "$arr" '.website_ids = $w')
    has_filters=true
  fi

  if [ -n "$CATEGORY_IDS" ]; then
    local arr
    arr=$(echo "$CATEGORY_IDS" | jq -R 'split(",")')
    filters=$(echo "$filters" | jq --argjson c "$arr" '.category_ids = $c')
    has_filters=true
  fi

  if [ -n "$EXCLUDE_BRAND_IDS" ]; then
    local arr
    arr=$(echo "$EXCLUDE_BRAND_IDS" | jq -R 'split(",")')
    filters=$(echo "$filters" | jq --argjson b "$arr" '.exclude_brand_ids = $b')
    has_filters=true
  fi

  if [ -n "$EXCLUDE_WEBSITE_IDS" ]; then
    local arr
    arr=$(echo "$EXCLUDE_WEBSITE_IDS" | jq -R 'split(",")')
    filters=$(echo "$filters" | jq --argjson w "$arr" '.exclude_website_ids = $w')
    has_filters=true
  fi

  if [ -n "$EXCLUDE_CATEGORY_IDS" ]; then
    local arr
    arr=$(echo "$EXCLUDE_CATEGORY_IDS" | jq -R 'split(",")')
    filters=$(echo "$filters" | jq --argjson c "$arr" '.exclude_category_ids = $c')
    has_filters=true
  fi

  if [ "$has_filters" = true ]; then
    body=$(echo "$body" | jq --argjson f "$filters" '.filters = $f')
  fi

  echo "$body"
}

BODY=$(build_body)

# ── Call the API ──────────────────────────────────────────────────────

RESPONSE=$(curl -s -w "\n%{http_code}" \
  -X POST "https://api.trychannel3.com/v1/similar" \
  -H "x-api-key: ${CHANNEL3_API_KEY:-}" \
  -H "Content-Type: application/json" \
  -d "$BODY")

HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
RESPONSE_BODY=$(echo "$RESPONSE" | sed '$d')

if [ "$HTTP_CODE" -eq 401 ] || [ "$HTTP_CODE" -eq 403 ]; then
  echo "ERROR: Missing or invalid API key."
  echo ""
  echo "Get a free API key at https://trychannel3.com and set it:"
  echo "  export CHANNEL3_API_KEY=\"your_key_here\""
  exit 1
fi

if [ "$HTTP_CODE" -eq 402 ]; then
  echo "ERROR: Free credits exhausted."
  echo ""
  echo "Add a payment method at https://trychannel3.com to continue."
  exit 1
fi

if [ "$HTTP_CODE" -eq 404 ]; then
  detail=$(echo "$RESPONSE_BODY" | jq -r '.detail // "Product not found"' 2>/dev/null || echo "Product not found")
  echo "ERROR: $detail"
  echo ""
  echo "Tip: this product may not be in the Channel3 catalog yet. Fall back to"
  echo "search.sh with the product's title or category."
  exit 1
fi

if [ "$HTTP_CODE" -ne 200 ]; then
  echo "ERROR: API returned HTTP $HTTP_CODE"
  error_msg=$(echo "$RESPONSE_BODY" | jq -r '.detail // .message // "Unknown error"' 2>/dev/null || echo "$RESPONSE_BODY")
  echo "  $error_msg"
  exit 1
fi

# ── Format output ─────────────────────────────────────────────────────

PRODUCT_COUNT=$(echo "$RESPONSE_BODY" | jq '.products | length')
NEXT_PAGE=$(echo "$RESPONSE_BODY" | jq -r '.next_page_token // empty')

if [ "$PRODUCT_COUNT" -eq 0 ]; then
  echo "No similar products found."
  exit 0
fi

if [ -n "$NEXT_PAGE" ]; then
  echo "Found $PRODUCT_COUNT similar products (next_page: $NEXT_PAGE)"
else
  echo "Found $PRODUCT_COUNT similar products"
fi
echo ""

echo "$RESPONSE_BODY" | jq -r '
  .products | to_entries[] |
  "\(.key + 1). \(.value.title)"
  + "\n   ID: \(.value.id)"
  + "\n   Brands: \((.value.brands // []) | map(.name) | join(", ") | if . == "" then "—" else . end)"
  + "\n   Offers:"
  + (
      if (.value.offers // []) | length == 0 then
        "\n     (no offers available)"
      else
        (.value.offers | map(
          "     - \(.domain): $\(.price.price) \(.price.currency)"
          + (if .price.compare_at_price then " (was $\(.price.compare_at_price))" else "" end)
          + " (\(.availability))"
          + " \(.url)"
        ) | join("\n") | "\n" + .)
      end
    )
  + "\n"
'
