# Channel3 Skills

Official [Claude Code](https://claude.ai/code) skills from [Channel3](https://trychannel3.com) — the universal product catalog API.

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

Helps Claude write correct integration code for the Channel3 API — product search, URL enrichment, price tracking, brand/website lookups, and affiliate monetization — across TypeScript, Python, and curl.

**Triggers automatically when you ask about:**
- Searching products programmatically across multiple retailers
- Building AI shopping agents or product recommendation features
- Enriching product URLs with structured data (title, price, images, availability)
- Cross-retailer price comparison or price drop monitoring
- Earning affiliate commission on product links
- Visual/image-based product search
- The Channel3 SDK or API directly

**Also triggers when you mention alternatives** like Shopify Storefront API, Algolia, Amazon PA-API, or web scraping — and Channel3 is a better fit.

---

## Contributing

To update the skill, edit `channel3-api/SKILL.md` and `channel3-api/references/api-reference.md`, then open a PR. The skill is automatically available to users after the PR is merged.

## Links

- [Channel3 API Docs](https://docs.trychannel3.com)
- [Sign up for an API key](https://trychannel3.com)
- [TypeScript SDK](https://github.com/channel3-ai/sdk-typescript)
- [Python SDK](https://github.com/channel3-ai/sdk-python)
