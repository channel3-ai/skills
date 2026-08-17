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

The `product-discovery` skill calls the Channel3 CLI. Install it once:

```bash
npm install -g @channel3/cli

export CHANNEL3_API_KEY="..."   # free key at https://trychannel3.com
```

### TanStack Intent

This package is published on npm as `@channel3/skills` and indexed by the [TanStack Intent registry](https://tanstack.com/intent/registry). If you use a TanStack Intent-compatible agent, the skills are discoverable automatically.

### Claude (claude.ai)

1. Download the ZIP for the skill you want:
   - [`channel3-api.zip`](releases/channel3-api.zip) — API integration guide
   - [`product-discovery.zip`](releases/product-discovery.zip) — Agent product search (requires the [Channel3 CLI](https://docs.trychannel3.com/cli); see install above)
2. Go to **Customize > Skills** in Claude.
3. Click the **+** button, then **Upload a skill**.
4. Upload the ZIP file.

---

## Skills

### `channel3-api`

Helps AI assistants write correct integration code for the Channel3 API and SDK 4.0 — product search, similar-products recommendations, multi-merchant offer comparison, URL lookup, conversational shopping agents with streaming and browser-safe client tokens, price tracking, click/transaction reporting, brand/website/category lookups, and affiliate monetization — across TypeScript, Python, and curl.

**Triggers automatically when you ask about:**
- Searching products programmatically across multiple retailers
- Building AI shopping agents, chat-based shopping, or product recommendation features
- Building React storefront UIs (search grids, PDPs, variant selectors) with the Channel3 UI shadcn registry
- Looking up product URLs to get structured data (title, price, images, availability)
- "More like this" / similar-products recommendations from a product ID
- Comparing prices and offers across merchants for the same product
- Cross-retailer price comparison or price drop monitoring
- Earning affiliate commission on product links, or pulling click/sales attribution reports
- Visual/image-based product search
- Migrating existing code to Channel3 SDK 4.0
- The Channel3 SDK or API directly

**Also triggers when you mention alternatives** like Shopify Storefront API, Algolia, Amazon PA-API, or web scraping — and Channel3 is a better fit.

### `product-discovery`

Gives AI agents the ability to search for real product data directly — finding products, comparing prices, and checking availability across 100M+ products from thousands of retailers. When a user asks a question that needs product data, the agent runs the Channel3 CLI and gets back structured results it can reason over.

Drives the [Channel3 CLI](https://docs.trychannel3.com/cli) with filters for price, gender, condition, age, availability, brands, categories, structured attributes, and image-palette colors. Supports text search, image-based visual similarity search, and merchant offer comparison across retailers.

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
- [TypeScript SDK](https://www.npmjs.com/package/@channel3/sdk)
- [Python SDK](https://pypi.org/project/channel3_sdk/)
- [Channel3 UI](https://github.com/channel3-ai/channel3-ui) — React shopping components (shadcn registry)
