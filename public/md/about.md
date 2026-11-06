# About

This server gives AI agents access to public X (Twitter) data. It exposes seven
tools over REST and MCP, so an assistant can look up a profile, read a
timeline, follow a conversation or search posts without opening a browser.

The web pages you are reading are the same data in a human-readable form. They
are here so you can check what an agent sees, browse by hand, or follow a
profile without writing any code. They are not the point of the instance; the
API is.

## For agents

Four ways in:

- `/api/v1/...` — REST, with an OpenAPI document at `/api/v1/openapi.json`
- `/mcp` — an MCP server, for agents that speak that protocol
- `/llms.txt` — a plain-text description of the tools, for anything else
- Skills — short instructions that teach an agent when and how to call the tools (reading X data, summarising threads, briefing an account). They are the `skills/` directory of the project repository, not part of this domain

The seven tools:

- `get_user` — a profile and its counts
- `get_user_timeline` — one account's posts, replies, media or articles
- `get_tweet` — a single post, by id or URL
- `get_thread` — a post with its ancestors, replies and continuation
- `search_tweets` — keyword, author and date search
- `search_users` — find accounts
- `get_user_connections` — followers and following

Responses are compact Markdown by default and JSON on request, with uniform
pagination and stable error codes. Text written by other people is fenced and
marked as untrusted, so an injected instruction in a post is visible as data
rather than obeyed as a command. Requests need a bearer token issued by the
operator; without one the API stays switched off and only these pages are
served.

The tools only read. There is no post, like, repost, follow or message call, so
a misbehaving agent cannot act on your account even if it tries.

## For people

Without an X account you can read profiles, posts, threads, replies, searches,
lists and communities, in any theme, with JavaScript disabled. RSS feeds exist
for profiles, lists and searches, so a reader or a script can follow an account
in the background.

What you cannot do is write, for the same reason as above: this instance holds
no credentials for acting as you.

## What it stores

- **Nothing about visitors.** No accounts, no analytics, no tracking pixels.
  Your display preferences (theme, language, media settings) live in a cookie in
  your own browser; clearing cookies resets them.
- **A cache of public data.** Posts and profiles fetched recently are kept for a
  short time so repeated questions do not spend the operator's rate limit. The
  cache holds public content, not visitors.
- **Your own search history**, if you leave the X theme's enhancements on: the
  words you searched for are kept in your browser's storage and never sent here.

## Credits and licence

The code is [Nitter](https://github.com/zedeus/nitter), started by zedeus and
maintained by its contributors, extended here with the agent API, the X theme
and the Chinese interface. The source for this fork is at
<https://github.com/xiaoY233/nitter>.

Licensed under the AGPLv3. If you run a modified copy, publish your changes
under the same licence.
