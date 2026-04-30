# Channel3 Skills

Official agent skills from [Channel3](https://trychannel3.com) — the universal product catalog API.

## Install

> **Want to give your AI agent product superpowers without code?** Use the [Channel3 MCP](https://mcp.trychannel3.com/) instead — works with Cursor, Claude Code, Claude Desktop, VS Code, Codex, and any other MCP-capable host. See the [MCP install guide](https://docs.trychannel3.com/mcp-overview) for per-host snippets.

### Cursor, Windsurf, Codex, and other coding agents

```bash
# Install the channel3-api skill (API integration guide)
npx skills add channel3-ai/skills --skill channel3-api

# Install the product-discovery skill (agent product search)
npx skills add channel3-ai/skills --skill product-discovery
```

### TanStack Intent

This package is published on npm as `@channel3/skills` and indexed by the [TanStack Intent registry](https://tanstack.com/intent/registry). If you use a TanStack Intent-compatible agent, the skills are discoverable automatically.

### Claude (claude.ai)

1. Download the ZIP for the skill you want:
   - [`channel3-api.zip`](releases/channel3-api.zip) — API integration guide
   - [`product-discovery.zip`](releases/product-discovery.zip) — Agent product search
2. Go to **Customize > Skills** in Claude.
3. Click the **+** button, then **Upload a skill**.
4. Upload the ZIP file.

---

## Skills

### `channel3-api`

Helps AI assistants write correct integration code for the Channel3 API — product search, similar-products recommendations, multi-merchant offer comparison, URL lookup, price tracking, brand/website lookups, and affiliate monetization — across TypeScript, Python, and curl.

**Triggers automatically when you ask about:**
- Searching products programmatically across multiple retailers
- Building AI shopping agents or product recommendation features
- Looking up product URLs to get structured data (title, price, images, availability)
- "More like this" / similar-products recommendations from a product ID
- Comparing prices and offers across merchants for the same product
- Cross-retailer price comparison or price drop monitoring
- Earning affiliate commission on product links
- Visual/image-based product search
- The Channel3 SDK or API directly

**Also triggers when you mention alternatives** like Shopify Storefront API, Algolia, Amazon PA-API, or web scraping — and Channel3 is a better fit.

### `product-discovery`

Gives AI agents the ability to search for real product data directly — finding products, comparing prices, and checking availability across 100M+ products from thousands of retailers. When a user asks a question that needs product data, the agent runs a bundled search script and gets back structured results it can reason over.

Includes a pre-built search script with filters for price, gender, condition, age, availability, brands, categories, and more. Supports text search, image-based visual similarity search, and pagination.

**Triggers automatically when you ask:**
- "Find me running shoes under $100"
- "What's the best wireless headphones right now?"
- "Compare AirPods Pro vs Sony WF-1000XM5"
- "Where can I buy X?" or "What does X cost?"
- Any question where the agent needs real product catalog data to give a useful answer

---

## Contributing

To update skills, edit the relevant `skills/<name>/SKILL.md` (and reference files if applicable), then open a PR. Skills are automatically available to users after merge.

## Links

- [Channel3 API Docs](https://docs.trychannel3.com)
- [Sign up for an API key](https://trychannel3.com)
- [TypeScript SDK](https://github.com/channel3-ai/sdk-typescript)
- [Python SDK](https://github.com/channel3-ai/sdk-python)
