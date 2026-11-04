# Sessions and rate limits

Nitter does not use the official X API. It calls X's web endpoints with the
cookies of a real X account. That cookie set is called a *session*, and every
request this server makes to X spends one session's quota.

## `sessions.jsonl`

One JSON object per line. Cookie sessions look like this:

```json
{"kind": "cookie", "username": "alice", "id": "", "auth_token": "...", "ct0": "..."}
```

`auth_token` and `ct0` are the values of the cookies of the same names, taken
from a logged-in browser session on x.com. Treat the file like a password:
anyone who holds it can act as that account. It is listed in `.gitignore` and
`.dockerignore`.

The `tools/` directory has helper scripts that create sessions
(`create_session_browser.py`, `create_session_curl.py`, `get_session.py`).
Their usage is documented at the top of each script, for example:

```sh
python3 tools/create_session_curl.py <username> <password> [totp_seed] --append sessions.jsonl
```

On start-up Nitter prints how many sessions it accepted:

```
[sessions] successfully added 1 valid account sessions
```

Use an account you can afford to lose. X may lock or suspend accounts used this
way.

## Limits

Two independent layers apply.

### X (upstream)

X limits each session per endpoint. Nitter records the limit headers X returns
(`x-rate-limit-limit`, `-remaining`, `-reset`) and works with them:

- An endpoint with 10 or fewer requests remaining is skipped for that session
  until its reset time.
- When X refuses a request, the session is marked limited for one hour.
- Each session carries at most `maxConcurrentReqs` requests at a time (default 2).
- A failed request is retried `maxRetries` times (default 1) after `retryDelayMs`.
- With several sessions, requests are spread across them, so more sessions
  give more total quota.

The numbers differ per endpoint and X changes them without notice. Nitter does
not publish a fixed value. To see the real values for your account, set
`enableDebug = true` and open `/.sessions`, or check `requests.apis` in
`/.health` after some traffic. Responses served from the cache do not update
these counters.

### This server (agent API)

Set in the `[Api]` section, applied per token:

| Option | Default | Meaning |
|---|---|---|
| `requestsPerMinute` | 120 | Requests per minute, 0 = unlimited. Over the limit returns HTTP 429 with `retry_after_s`. |
| `maxConcurrent` | 4 | Requests in flight at once, 0 = unlimited |
| `maxPages` | 5 | Upstream pages fetched for one call that asks for a large `limit` |

Cached answers still count against `requestsPerMinute` but cost no upstream
quota. Cache lifetimes: profiles 900 s, tweets 300 s, timelines 120 s,
searches 60 s (`cache*Seconds`).

The per-token limit is much larger than what one session sustains, so X is the
real bottleneck. Lower `requestsPerMinute` (for example to 30) if you want a
runaway agent loop to be stopped early.

## Reading errors

| Error code | Meaning |
|---|---|
| `rate_limited` | Either this server's per-token limit or X's limit on the session. Check `/.health`: if `requests.total` is 0 the cause is the network, not a limit. |
| `upstream_unavailable` | X could not be reached or returned an error page. Retryable. |
| `not_found` | The account or tweet does not exist, or the session cannot see it. |
| `protected_account` / `user_suspended` | Reported as such; nothing to retry. |

The full list of error codes is in [agent-api.md](agent-api.md).
