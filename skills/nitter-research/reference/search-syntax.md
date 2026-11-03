# Search syntax for `search_tweets`

`query` is passed to X's search. Dedicated arguments are safer than writing the operator yourself.

| Goal | Use |
|---|---|
| tweets by one or more accounts | `from=jack` or `from=jack,biz` (comma separated) |
| date range | `since=2025-01-01`, `until=2025-02-01` (YYYY-MM-DD, `until` is exclusive) |
| popularity | `min_likes=100` |
| only tweets with media / links / news / quotes / replies / mentions | `filter=media` etc. |
| newest first or most relevant | `mode=latest` (default) or `mode=top`; `mode=media` for media tweets |
| include native retweets | `include_retweets=true` (off by default) |

Operators you can put inside `query`:

| Operator | Example | Matches |
|---|---|---|
| words | `rust async` | both words |
| `"phrase"` | `"memory safety"` | exact phrase |
| `OR` | `nim OR zig` | either (uppercase) |
| `-word` | `python -snake` | excludes a word |
| `#tag`, `@name` | `#buildinpublic` | hashtag, mention |
| `lang:xx` | `lang:ja` | language code |
| `url:domain` | `url:github.com` | links to a domain |
| `to:name` | `to:jack` | replies to an account |
| `min_retweets:n` | `min_retweets:50` | reposts |

Tips:
- Combine few operators; each one narrows results and empty pages come back quickly.
- For one account's recent posts without a keyword, `get_user_timeline` is cheaper and more complete than `search_tweets from=...`.
- Search indexes are not exhaustive. An empty result does not prove a tweet does not exist.
- These operators are X's, not Nitter's. If one returns nothing unexpectedly, retry without it.
