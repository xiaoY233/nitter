# Agent API (REST + MCP)

Read-only access to public X/Twitter data for AI agents. It reuses Nitter's
upstream sessions, parsers and Redis cache. Disabled by default.

## Enable

```ini
[Api]
enabled = true
tokens = "me:<output of: openssl rand -hex 24>"
```

Nitter refuses to start with the API enabled and no token, unless
`allowAnonymous = true`. All options are listed in `nitter.example.conf`.
Tokens may also come from `NITTER_API_TOKENS` (same `name:secret,...` format).

Intended for a trusted network. Every call spends your upstream session quota.

## Tools

The same seven tools are served over REST and MCP. The registry in
`src/tools/registry.nim` is the single source of truth.

| Tool | REST | Purpose |
|---|---|---|
| `get_user` | `GET /api/v1/users/{username}` | Profile and counts |
| `get_user_timeline` | `GET /api/v1/users/{username}/tweets?tab=posts\|replies\|media\|articles` | One account's tweets |
| `get_tweet` | `GET /api/v1/tweets/{tweet}` | One tweet (id or URL) |
| `get_thread` | `GET /api/v1/tweets/{tweet}/thread` | Ancestors, continuation, replies |
| `search_tweets` | `GET /api/v1/search/tweets` | Keyword / author / date search |
| `search_users` | `GET /api/v1/search/users` | Find accounts |
| `get_user_connections` | `GET /api/v1/users/{username}/connections?kind=followers\|following` | Follower lists |

Also: `POST /api/v1/tools/{name}` (JSON body), `GET /api/v1/tools`,
`GET /api/v1/openapi.json`, `GET /api/v1/health`, `GET /llms.txt`.

Conventions:
- ids are strings, times ISO-8601 UTC.
- `format=markdown` (compact, MCP default) or `format=json` (REST default).
- Lists return `{items, next_cursor, has_more}`; pass `next_cursor` as `cursor`.
- `limit` is a minimum: whole upstream pages are fetched until it is met (at most `maxPages`).
- Errors: `{"error": {"code", "message", "retryable", "retry_after_s"}}`. Codes:
  `invalid_argument`, `unauthorized`, `forbidden_origin`, `not_found`, `user_suspended`,
  `protected_account`, `rate_limited`, `upstream_unavailable`, `upstream_error`, `internal_error`.

```sh
curl -H "Authorization: Bearer $TOKEN" \
  "http://nitter.lan:8080/api/v1/search/tweets?query=nim%20lang&since=2025-01-01&limit=10&format=markdown"
```

## MCP

Endpoint `POST /mcp` (Streamable HTTP, stateless, JSON responses; protocol
versions 2025-11-25, 2025-06-18, 2025-03-26). Tool failures come back as
results with `isError: true`, protocol failures as JSON-RPC errors.

Claude Code:

```sh
claude mcp add --transport http nitter http://nitter.lan:8080/mcp \
  --header "Authorization: Bearer $TOKEN"
```

Clients that only speak stdio use the bridge in `clients/mcp-stdio` (Node >= 18, no dependencies):

```json
{ "mcpServers": { "nitter": {
    "command": "node", "args": ["/path/to/nitter/clients/mcp-stdio/bridge.mjs"],
    "env": { "NITTER_BASE_URL": "http://nitter.lan:8080", "NITTER_API_TOKEN": "..." } } } }
```

## Data notes

Things that look like bugs but come from the upstream data:

- **`stats` fields can be `null`.** `null` means *X did not report it*, not zero.
  - `views` is only reported for newer tweets; older ones return `null`.
  - User search (`search_users`) returns profiles without counters, so every
    `stats` value is `null` there. Call `get_user` when counts matter.
- **Empty `bio`** is real for accounts that have none (for example `@nim_lang`).
- **`search_tweets` with `from=` and reposts.** `include_retweets=false` (the
  default) removes tweets the account merely reposted. Pass `true` to see them:
  they come back as the original tweet with `retweeted_by` set. `get_user_timeline`
  always includes reposts, marked the same way.
- **`get_thread` pages replies.** `max_replies` caps how many reply tweets are
  returned; `replies_omitted` says how many reply threads of this page were left
  out, and `next_cursor` continues with the following page. Raise `max_replies`
  to see the omitted ones.
- **A full URL in the REST path** must be percent-encoded
  (`/tweets/https%3A%2F%2Fx.com%2Fjack%2Fstatus%2F20`). `POST /api/v1/tools/get_tweet`
  and MCP take the URL as a plain argument.

## Skills

`skills/` holds agent skills (research, thread digest, account brief) that
teach clients when and how to call these tools. Install steps are in
`skills/README.md`. Without MCP, `skills/nitter-research/scripts/nitter.sh`
calls the REST API with `curl` only.

## Security notes

- Tweet text is attacker-controlled. Markdown output wraps each tweet in
  `<tweet ... untrusted>` and neutralises a forged wrapper tag inside the text.
  The tools are read-only, so a prompt injection cannot trigger side effects.
- Tokens are compared by SHA-256 digest. Requests carrying a browser `Origin`
  that is not the server's own host or in `allowedOrigins` get 403.
- Limits are per token: `requestsPerMinute` and `maxConcurrent` (429 with `Retry-After`).
- Nothing is fetched from user-supplied URLs; URLs are only parsed for ids.

## Tests

```sh
nim c -r tests/test_agent_api.nim   # offline: validation, auth, DTOs, MCP, pagination
```
