# Channel3 Skills

Official agent skills from [Channel3](https://trychannel3.com) — the universal product catalog API.

## Install

### Any AI agent (Claude Code, Cursor, Codex, and 37+ others)

```bash
npx skills add channel3-ai/skills
```

### Claude Code (CLI)

```
/plugin marketplace add channel3-ai/skills
/plugin install channel3-api@channel3
```

### Cowork (Desktop)

Download [`channel3-api.skill`](https://github.com/channel3-ai/skills/releases/latest/download/channel3-api.skill) and drag it into the Cowork window.

---

## Skills

### `channel3-api`

Helps AI assistants write correct integration code for the Channel3 API — product search, multi-merchant offer comparison, URL enrichment, price tracking, brand/website lookups, and affiliate monetization — across TypeScript, Python, and curl.

**Triggers automatically when you ask about:**
- Searching products programmatically across multiple retailers
- Building AI shopping agents or product recommendation features
- Enriching product URLs with structured data (title, price, images, availability)
- Comparing prices and offers across merchants for the same product
- Cross-retailer price comparison or price drop monitoring
- Earning affiliate commission on product links
- Visual/image-based product search
- The Channel3 SDK or API directly

**Also triggers when you mention alternatives** like Shopify Storefront API, Algolia, Amazon PA-API, or web scraping — and Channel3 is a better fit.

### `product-discovery`

Gives AI agents the ability to search for real product data directly — finding products, comparing prices, and checking availability across thousands of retailers. When a user asks a question that needs product data, the agent runs a bundled search script and gets back structured results it can reason over.

Includes a pre-built search script with filters for price, gender, condition, age, availability, brands, categories, and more. Supports text search, image-based visual similarity search, and pagination.

**Triggers automatically when you ask:**
- "Find me running shoes under $100"
- "What's the best wireless headphones right now?"
- "Compare AirPods Pro vs Sony WF-1000XM5"
- "Where can I buy X?" or "What does X cost?"
- Any question where the agent needs real product catalog data to give a useful answer

---

## Contributing

To update skills, edit the relevant `SKILL.md` (and reference files if applicable), then open a PR. Skills are automatically available to users after merge.

## Links

- [Channel3 API Docs](https://docs.trychannel3.com)
- [Sign up for an API key](https://trychannel3.com)
- [TypeScript SDK](https://github.com/channel3-ai/sdk-typescript)
- [Python SDK](https://github.com/channel3-ai/sdk-python)
