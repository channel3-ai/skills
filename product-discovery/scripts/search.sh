#!/usr/bin/env bash
set -euo pipefail

# ── Parse arguments ───────────────────────────────────────────────────

LIMIT=5
MIN_PRICE=""
MAX_PRICE=""
GENDER=""
CONDITION=""
AGE=""
AVAILABILITY=""
IMAGE_URL=""
BRAND_IDS=""
WEBSITE_IDS=""
CATEGORY_IDS=""
EXCLUDE_BRAND_IDS=""
EXCLUDE_WEBSITE_IDS=""
EXCLUDE_CATEGORY_IDS=""
KEYWORD_ONLY=false
PAGE_TOKEN=""
QUERY=""

usage() {
  echo "Usage: search.sh [OPTIONS] \"query text\""
  echo ""
  echo "Options:"
  echo "  -n NUM                  Number of results (default: 5, max: 30)"
  echo "  -p MAX_PRICE            Maximum price in dollars"
  echo "  --min-price MIN         Minimum price in dollars"
  echo "  -g GENDER               Gender filter (male/female/unisex)"
  echo "  -c CONDITION            Condition (new/refurbished/used)"
  echo "  -a AGE                  Comma-separated age groups (newborn/infant/toddler/kids/adult)"
  echo "  --availability STATUS   Comma-separated statuses (InStock/OutOfStock/PreOrder/BackOrder/...)"
  echo "  -i IMAGE_URL            Search by image URL (visual similarity)"
  echo "  -b BRAND_IDS            Comma-separated brand IDs to include"
  echo "  -w WEBSITE_IDS          Comma-separated website IDs to include"
  echo "  --categories IDS        Comma-separated category IDs to include"
  echo "  --exclude-brands IDS    Comma-separated brand IDs to exclude"
  echo "  --exclude-websites IDS  Comma-separated website IDs to exclude"
  echo "  --exclude-categories IDS Comma-separated category IDs to exclude"
  echo "  --keyword-only          Exact keyword matching (no semantic search)"
  echo "  --next TOKEN            Pagination token from a previous search"
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
    -n) LIMIT="$2"; shift 2 ;;
    -p) MAX_PRICE="$2"; shift 2 ;;
    --min-price) MIN_PRICE="$2"; shift 2 ;;
    -g) GENDER="$2"; shift 2 ;;
    -c) CONDITION="$2"; shift 2 ;;
    -a) AGE="$2"; shift 2 ;;
    --availability) AVAILABILITY="$2"; shift 2 ;;
    -i) IMAGE_URL="$2"; shift 2 ;;
    -b) BRAND_IDS="$2"; shift 2 ;;
    -w) WEBSITE_IDS="$2"; shift 2 ;;
    --categories) CATEGORY_IDS="$2"; shift 2 ;;
    --exclude-brands) EXCLUDE_BRAND_IDS="$2"; shift 2 ;;
    --exclude-websites) EXCLUDE_WEBSITE_IDS="$2"; shift 2 ;;
    --exclude-categories) EXCLUDE_CATEGORY_IDS="$2"; shift 2 ;;
    --keyword-only) KEYWORD_ONLY=true; shift ;;
    --next) PAGE_TOKEN="$2"; shift 2 ;;
    -h|--help) usage ;;
    -*) echo "Unknown option: $1"; usage 1 ;;
    *) QUERY="$1"; shift ;;
  esac
done

if [ -z "$QUERY" ] && [ -z "$IMAGE_URL" ]; then
  echo "ERROR: Provide a search query and/or an image URL (-i)."
  echo ""
  usage 1
fi

# ── Build JSON request body ───────────────────────────────────────────

build_body() {
  local body="{}"
  body=$(echo "$body" | jq --argjson limit "$LIMIT" '.limit = $limit')

  if [ -n "$QUERY" ]; then
    body=$(echo "$body" | jq --arg q "$QUERY" '.query = $q')
  fi

  if [ -n "$IMAGE_URL" ]; then
    body=$(echo "$body" | jq --arg u "$IMAGE_URL" '.image_url = $u')
  fi

  if [ -n "$PAGE_TOKEN" ]; then
    body=$(echo "$body" | jq --arg t "$PAGE_TOKEN" '.page_token = $t')
  fi

  if [ "$KEYWORD_ONLY" = true ]; then
    body=$(echo "$body" | jq '.config = {keyword_search_only: true}')
  fi

  # Build filters object
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
  -X POST "https://api.trychannel3.com/v1/search" \
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
  echo "Add a payment method at https://trychannel3.com to continue searching."
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
  echo "No products found."
  exit 0
fi

if [ -n "$NEXT_PAGE" ]; then
  echo "Found $PRODUCT_COUNT products (next_page: $NEXT_PAGE)"
else
  echo "Found $PRODUCT_COUNT products"
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
