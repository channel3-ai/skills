#!/usr/bin/env bash
set -euo pipefail

# ── Parse arguments ───────────────────────────────────────────────────

LIMIT=5
QUERY=""

usage() {
  echo "Usage: categories.sh [-n NUM] \"query text\""
  echo ""
  echo "Find category slugs matching a free-text query."
  echo "Pipe the resulting Slug into search.sh / similar.sh --categories."
  echo ""
  echo "Options:"
  echo "  -n NUM   Number of results (default: 5, max: 20)"
  echo "  -h       Show this help"
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
    -h|--help) usage ;;
    -*) echo "Unknown option: $1"; usage 1 ;;
    *) QUERY="$1"; shift ;;
  esac
done

if [ -z "$QUERY" ]; then
  echo "ERROR: Provide a query."
  echo ""
  usage 1
fi

# ── Call the API ──────────────────────────────────────────────────────

ENCODED_QUERY=$(jq -nr --arg q "$QUERY" '$q | @uri')

RESPONSE=$(curl -s -w "\n%{http_code}" \
  -X GET "https://api.trychannel3.com/v1/categories/search?query=${ENCODED_QUERY}&limit=${LIMIT}" \
  -H "x-api-key: ${CHANNEL3_API_KEY:-}")

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

if [ "$HTTP_CODE" -ne 200 ]; then
  echo "ERROR: API returned HTTP $HTTP_CODE"
  error_msg=$(echo "$RESPONSE_BODY" | jq -r '.detail // .message // "Unknown error"' 2>/dev/null || echo "$RESPONSE_BODY")
  echo "  $error_msg"
  exit 1
fi

# ── Format output ─────────────────────────────────────────────────────

CATEGORY_COUNT=$(echo "$RESPONSE_BODY" | jq '.categories | length')

if [ "$CATEGORY_COUNT" -eq 0 ]; then
  echo "No categories found."
  exit 0
fi

echo "Found $CATEGORY_COUNT categories"
echo ""

echo "$RESPONSE_BODY" | jq -r '
  .categories | to_entries[] |
  "\(.key + 1). \(.value.title)"
  + "\n   Slug: \(.value.slug)"
  + "\n   Path: \((.value.path // []) | map(.title) | join(" > "))"
  + (if .value.has_children then "\n   Has children: yes" else "" end)
  + "\n"
'
