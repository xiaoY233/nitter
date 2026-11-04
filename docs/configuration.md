# Configuration

Settings live in `nitter.conf` (INI format). Start from `nitter.example.conf`.
Missing options use the defaults below, so a config file written for an older
version keeps working.

Two values can come from the environment instead of the file:

| Variable | Replaces |
|---|---|
| `NITTER_API_TOKENS` | `[Api] tokens` (the two are merged) |
| `NITTER_SESSIONS_FILE` | the default `./sessions.jsonl` path |
| `NITTER_CONF_FILE` | the default `./nitter.conf` path |

## `[Server]`

| Option | Default | Meaning |
|---|---|---|
| `hostname` | `nitter.net` | Public host name, used when generating links. Set it to your own domain or IP. |
| `title` | `Nitter` | Page title of the web interface |
| `address` | `0.0.0.0` | Listen address |
| `port` | `8080` | Listen port |
| `https` | `true` in code, `false` in the example file | Whether the public URL is https. Must match how users reach the site, or cookies fail. |
| `httpMaxConnections` | `100` | Maximum simultaneous HTTP connections |
| `staticDir` | `./public` | Directory with the web interface's static files |

## `[Cache]`

| Option | Default | Meaning |
|---|---|---|
| `redisHost` | `localhost` | Redis host. Use `nitter-redis` with `compose.yml`. |
| `redisPort` | `6379` | |
| `redisPassword` | empty | |
| `redisConnections` | `20` | Minimum open connections |
| `redisMaxConnections` | `30` | Pool size above which extra connections are closed after use |
| `listMinutes` | `120` | Cache time for list info |
| `rssMinutes` | `10` | Cache time for RSS queries |

## `[Config]`

| Option | Default | Meaning |
|---|---|---|
| `hmacKey` | `secretkey` | Signs media URLs. **Change it** to a random value (`openssl rand -hex 32`). A warning is printed while the default is in use. |
| `base64Media` | `false` | Base64-encode proxied media URLs |
| `enableDebug` | `false` | Request logs and the `/.sessions` endpoint. Exposes session details; troubleshooting only. |
| `proxy`, `proxyAuth` | empty | HTTP/HTTPS proxy for requests to X. SOCKS is not supported. |
| `apiProxy` | empty | Address of a `nitter-proxy`, for example `localhost:7000` |
| `disableTid` | `false` | Turn on if cookie authentication keeps failing |
| `maxConcurrentReqs` | `2` | Requests in flight per session |
| `maxRetries` | `1` | Retries after an upstream rate-limit error |
| `retryDelayMs` | `150` | Delay between retries |
| `enableRSS` and `enableRSS*` | `true` | Switches for the RSS feeds of the web interface |

## `[Api]`

The agent API. See [agent-api.md](agent-api.md) for what it serves.

| Option | Default | Meaning |
|---|---|---|
| `enabled` | `false` | Turns on `/api/v1` and `/mcp`. There is no environment variable for this switch. |
| `enableMcp` | `true` | Serve `/mcp` when the API is enabled |
| `tokens` | empty | Bearer tokens as `name:secret`, comma separated, for example `claude:abc,codex:def`. Give each agent its own. |
| `allowAnonymous` | `false` | Serve the API without a token. Anyone who can reach the port then spends your sessions. The server refuses to start with the API enabled, no token and this set to `false`. |
| `requestsPerMinute` | `120` | Per token, 0 = unlimited |
| `maxConcurrent` | `4` | Per token, 0 = unlimited |
| `maxPages` | `5` | Upstream pages fetched for one call |
| `allowedOrigins` | empty | Extra browser origins allowed to call the API, comma separated. Requests without an `Origin` header (command line tools, desktop clients) are not affected. |
| `proxyMedia` | `false` | Make media links in results point at this server's `/pic` and `/video` proxy instead of X's CDN |
| `cacheUserSeconds` | `900` | Cache time for profiles |
| `cacheTimelineSeconds` | `120` | Cache time for timelines |
| `cacheTweetSeconds` | `300` | Cache time for tweets and threads |
| `cacheSearchSeconds` | `60` | Cache time for searches |

### Tokens

A token has a name and a secret: `me:9f3c...`. The name appears in logs and
tells tokens apart for rate limiting. Clients send only the secret:

```
Authorization: Bearer 9f3c...
```

`X-API-Key: 9f3c...` is accepted as well. Generate a secret with
`openssl rand -hex 24`. To rotate one, replace it, restart, and update the
clients.

## `[Preferences]`

Default settings of the web interface (theme, media proxying, and so on). The
full list is in `src/prefs_impl.nim`. They do not affect the agent API.

Two of them are described in [web-ui.md](web-ui.md): `theme = "X"` and
`language = "Chinese"`.
