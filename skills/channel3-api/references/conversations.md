# Conversations API

> Canonical docs: [docs.trychannel3.com/conversations](https://docs.trychannel3.com/conversations/quickstart). This file is the offline reference — auth model, turn lifecycle, SSE events, and copy-paste examples.

The Conversations API is a turn-based shopping agent: you send the shopper's message, Channel3 plans and runs catalog searches server-side, and streams back an assistant reply (text + product cards + follow-up suggestions). Conversation state lives on the server — you only carry a `conversation_id`.

**The API key never ships to the browser.** Server code uses the API key; browser code uses a short-lived **client token** (`c3_ct_…`) minted by your server.

| Endpoint | Auth | Purpose |
|---|---|---|
| `POST /v1/conversations` | API key **or** client token | Create a turn (streams SSE by default) |
| `POST /v1/conversations/client_tokens` | API key only | Mint a browser-safe client token |
| `POST /v1/conversations/client_tokens/revoke` | API key only | Revoke a token immediately |
| `GET /v1/conversations/{conversation_id}` | API key **or** bound client token | Read thread history (paginated) |

## Auth model

- **Client token** (`c3_ct_…`): can only run turns and read the one conversation it is bound to. The minting API key pays for those turns. Sent as `Authorization: Bearer c3_ct_…`.
- **Mint server-side only.** Default lifetime 30 minutes; `ttl_seconds` from 60 to 7200.
- **Pinning:** mint with no `conversation_id` → the token's first turn creates the thread and binds the token to it. Mint with `conversation_id` → the token can only continue/read that thread (any other id returns 404) — use this when re-minting for an existing chat (e.g. page refresh).
- An expired or revoked token returns `401` — mint a fresh one (passing the existing `conversation_id`) and retry.
- **Revoke on session end.** The token travels in the request body (not the URL) so it stays out of access logs.

```typescript
// Server — mint
const created = await server.conversations.clientTokens.create({
  conversation_id: conversationId, // optional; omit for a new thread
  ttl_seconds: 600,                // optional; 60–7200, default 1800
});
// created.token (c3_ct_…), created.token_id, created.expires_at

// Server — revoke
await server.conversations.clientTokens.revoke({ token: 'c3_ct_...' });
```

```python
# Server — mint
created = server.conversations.client_tokens.create(
    conversation_id=conversation_id,  # optional
    ttl_seconds=600,
)

# Server — revoke
server.conversations.client_tokens.revoke(token="c3_ct_...")
```

```bash
curl -X POST https://api.trychannel3.com/v1/conversations/client_tokens \
  -H "x-api-key: $CHANNEL3_API_KEY" -H "Content-Type: application/json" \
  -d '{"conversation_id": "conv_123", "ttl_seconds": 600}'
```

## Creating a turn

Request body (`CreateTurnRequest`):

| Field | Type | Notes |
|---|---|---|
| `message` | `{ role: "user", parts: UserPart[] }` | `UserPart` is `{ type: "text", text }` or `{ type: "image", ... }` |
| `conversation_id` | `string?` | Omit to create a thread; the id comes back on `turn.started` |
| `filters` | `SearchFilters?` | Pinned catalog filters applied to every product search in the turn |
| `context` | `ConversationContext?` | Extra context for the agent |
| `stream` | `boolean?` | Default `true` (SSE). `false` → buffered `TurnResult` |

The `x-user-id` header works here too — the id is appended to buy URLs in the reply for attribution.

### Streaming (TS, browser)

```typescript
import { Channel3 } from '@channel3/sdk';

// Browser client — auth is a function returning the Bearer header.
// Fetch a fresh token from your server; never embed the API key.
const client = new Channel3({
  auth: () => Promise.resolve({ headers: { Authorization: `Bearer ${token}` } }),
});

let conversationId: string | undefined;

const stream = await client.conversations.createTurnStream({
  message: {
    role: 'user',
    parts: [{ type: 'text', text: 'I need waterproof hiking boots under $200' }],
  },
  conversation_id: conversationId, // omit on the first turn
});

for await (const event of stream) {
  switch (event.type) {
    case 'turn.started':
      conversationId = event.conversation_id; // conv_… — save it
      break;
    case 'part.delta':
      text += event.delta; // append to the text block at event.part_index
      break;
    case 'part.completed':
      parts[event.part_index] = event.part; // text or tool part (product cards)
      break;
    case 'turn.completed':
      done(event.message); // full AssistantMessage + event.usage
      break;
    case 'error':
      if (event.retryable) retry(); else showError(event.message);
  }
}
```

The SDK stream auto-reconnects by default (`stream: { reconnectionEnabled, maxReconnectionAttempts }` in client options to tune).

### Streaming (Python)

```python
stream = client.conversations.create_turn_stream(
    message={"role": "user", "parts": [{"type": "text", "text": "..."}]},
    conversation_id=conversation_id,  # omit on the first turn
)

for event in stream:
    if event.type == "turn.started":
        conversation_id = event.conversation_id
    elif event.type == "part.delta":
        text += event.delta
    elif event.type == "part.completed":
        parts[event.part_index] = event.part
    elif event.type == "turn.completed":
        done(event.message)
    elif event.type == "error":
        retry() if event.retryable else show_error(event.message)
```

### Raw HTTP (SSE)

```bash
curl -N -X POST https://api.trychannel3.com/v1/conversations \
  -H "Authorization: Bearer c3_ct_..." \
  -H "Content-Type: application/json" \
  -d '{
    "message": { "role": "user", "parts": [{ "type": "text", "text": "in brown instead" }] },
    "conversation_id": "conv_123"
  }'
```

### Buffered (non-streaming)

Pass `stream: false` (HTTP body) or call `createTurn` / `create_turn` (SDK) to get the whole reply in one response:

```typescript
const result = await client.conversations.createTurn({
  message: { role: 'user', parts: [{ type: 'text', text: '...' }] },
  conversation_id: conversationId,
});
// result: { conversation_id, turn_id, usage, message: AssistantMessage }
```

## SSE events

A streamed turn is `text/event-stream`; the stream ends after a terminal event and `[DONE]`. The stream sends a heartbeat about every 15 seconds — silence between tokens is not a dead connection.

| Event | When | Payload | What to do |
|---|---|---|---|
| `turn.started` | First, once | `conversation_id`, `turn_id`, `message_id` | Save `conversation_id` for follow-up turns |
| `part.started` | A text or tool block begins | `part_index`, `part` | Add a block at `part_index` |
| `part.delta` | Text is generating | `part_index`, `delta` | Append `delta` to the text at `part_index` |
| `part.completed` | A block is done | `part_index`, `part` | Replace the block at `part_index` with the final part |
| `turn.completed` | Success, once | `message`, `usage` (`credits_charged`, `searches_run`) | Render the finished message |
| `error` | The turn failed | `code`, `message`, `retryable` | Retry if `retryable`, else surface |

`part_index` is the block's position in the final message; order within one reply is stable. Tool parts (`{ type: "tool", tool_name: "search_products", ... }`) carry the product cards — render those as results UI, not as raw text. A turn that fails **before** it starts returns a normal HTTP error, not an `error` event.

Raw frames look like:

```text
event: turn.started
data: {"type":"turn.started","conversation_id":"conv_123","turn_id":"turn_…","message_id":"msg_…"}

event: part.delta
data: {"type":"part.delta","part_index":0,"delta":"Let me pull up some options."}

event: turn.completed
data: {"type":"turn.completed","message":{"parts":[ … ]},"usage":{"credits_charged":2,"searches_run":1}}
```

## Messages

The assistant's reply (`AssistantMessage`) has `parts` and `suggestions`:

- **`parts`** — ordered blocks: `{ type: "text", text }` and `{ type: "tool", ... }` (tool parts carry the product results to render as cards).
- **`suggestions`** — `string[]` of tap-ready follow-up messages ("only show waterproof ones") to render as quick-reply chips.

## Thread history

```typescript
const page = await client.conversations.retrieve({ conversation_id: 'conv_123' });
// paginated message items — .data (TS) / .items (Python)
```

Use it to rebuild UI after a refresh. Client tokens can only read the conversation they're bound to.

## Common pitfalls

- **Don't ship the API key to the browser** — mint a client token on your server instead.
- **Save `conversation_id` from `turn.started`** on the first turn; pass it on every follow-up. Losing it forks the thread.
- **Don't poll `GET /v1/conversations/{id}` during a turn** — the stream (or the buffered `TurnResult`) is the reply.
- **Handle `401` by re-minting**, not by retrying the same token.
