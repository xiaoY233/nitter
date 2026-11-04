# Nitter Agent API

A self-hosted, read-only gateway that lets AI agents read public X (Twitter)
data. It serves one set of tools over **REST**, **MCP** and **agent Skills**,
and keeps Nitter's privacy-friendly web front-end alongside.

```
 agent (Claude Code, Codex, pi, DeepSeek Harness, ...)
   │  MCP (Streamable HTTP)  /  REST  /  Skills
   ▼
 Nitter Agent API ──► Redis cache ──► X (your own account sessions)
```

## What it does

Seven read-only tools, available through `POST /mcp` and `/api/v1/...`:

| Tool | Purpose |
|---|---|
| `get_user` | Profile and counts |
| `get_user_timeline` | One account's tweets, replies, media or articles |
| `get_tweet` | One tweet, by id or URL |
| `get_thread` | A tweet with its ancestors, continuation and replies |
| `search_tweets` | Keyword, author and date search |
| `search_users` | Find accounts |
| `get_user_connections` | Followers and following |

- **Built for agents.** Compact Markdown output by default, JSON on request,
  uniform pagination, stable error codes, and tweet text fenced as untrusted
  content to blunt prompt injection.
- **Read-only.** There is no write, post or DM tool.
- **Your own X sessions.** It reads X's web endpoints through the accounts you
  provide (see [docs/sessions.md](docs/sessions.md)).
- **Protected.** Bearer tokens, per-token rate limits, Origin checks, and a
  Redis cache that keeps repeated questions off your session quota.
- **Self-describing.** `GET /api/v1/openapi.json` and `GET /llms.txt` list the
  tools for any client.
- **Disabled by default.** Without `[Api] enabled = true` the server behaves as
  the plain Nitter web front-end.

The web pages (no JavaScript needed, no ads, RSS) are still served on the
same port. It shares the sessions and the cache with the API.

## Quick start

```sh
git clone https://github.com/xiaoY233/nitter.git && cd nitter
docker build -t vuldocker/nitter:latest .

cp nitter.example.conf nitter.conf     # set [Api] enabled = true, redisHost = "nitter-redis"
cp /path/to/sessions.jsonl .           # X account sessions
echo "NITTER_API_TOKENS=me:$(openssl rand -hex 24)" > .env
# uncomment the `environment` block in compose.yml, then:
docker compose up -d
```

Check it:

```sh
curl http://127.0.0.1:8080/api/v1/health
curl -H "Authorization: Bearer <secret>" \
  "http://127.0.0.1:8080/api/v1/users/jack?format=markdown"
```

`<secret>` is the part of the token after the colon. The full walk-through,
including building from source and systemd, is in
[docs/deployment.md](docs/deployment.md).

## Connect an agent

MCP, for example with Claude Code:

```sh
claude mcp add --transport http nitter http://<host>:8080/mcp \
  --header "Authorization: Bearer <secret>"
```

Clients that only speak stdio use the bridge in
[`clients/mcp-stdio`](clients/mcp-stdio). Skills that teach an agent how to
research with these tools are in [`skills/`](skills/README.md). Other clients
and the REST API are covered in [docs/agent-api.md](docs/agent-api.md).

## Documentation

| Document | Contents |
|---|---|
| [docs/deployment.md](docs/deployment.md) | Docker Compose, `docker run`, source build, systemd, troubleshooting |
| [docs/configuration.md](docs/configuration.md) | Every `nitter.conf` option and the environment variables |
| [docs/sessions.md](docs/sessions.md) | Account sessions, upstream and server rate limits, error meanings |
| [docs/web-ui.md](docs/web-ui.md) | The X theme, its optional keyboard shortcuts, and the Chinese interface |
| [docs/agent-api.md](docs/agent-api.md) | Tools, REST, MCP, data notes, Skills |
| [skills/README.md](skills/README.md) | Installing the agent Skills |

## Notes

- Intended for a trusted network. Every call spends your X session quota, and
  X may restrict the account behind a session.
- The API reports unknown numbers (for example views on old tweets) as `null`,
  not `0`. See "Data notes" in [docs/agent-api.md](docs/agent-api.md).

## License and origin

This project is a fork of [zedeus/nitter](https://github.com/zedeus/nitter),
licensed under the [GNU AGPL v3](LICENSE). The agent API, MCP server, Skills
and related changes are by the maintainers of this repository and are released
under the same license. If you offer this software over a network, the AGPL
requires you to make the source of your running version available to its users.
