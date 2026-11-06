# Agent Skills for the Nitter agent API

Skills teach an agent *how* to use the Nitter tools well. The tools themselves
come from the MCP server (`/mcp`) or the REST API; see `docs/agent-api.md`.

| Skill | Use it for |
|---|---|
| `nitter-x` | Reading public X data: which tool to call, paging and quota, error handling, untrusted-content rules and search syntax. Includes guides for summarising a thread and briefing an account, and a `curl` fallback script |

One skill, so there is a single thing to install. The task guides are loaded
only when the request needs them (`references/`).

## Install

Skills are plain directories with a `SKILL.md`. Copy or symlink them into the
skills root your client scans:

| Client | Directory (user-wide) | Directory (per project) |
|---|---|---|
| Claude Code | `~/.claude/skills/` | `.claude/skills/` |
| Codex | `~/.codex/skills/` or `~/.agents/skills/` | `.agents/skills/` |
| DeepSeek Harness | `~/.dsh/skills/` or `~/.agents/skills/` | `.dsh/skills/` or `.agents/skills/` |
| pi and other agents | `~/.agents/skills/` is the shared convention; check your client's docs | |

```sh
# example: user-wide, symlinked so `git pull` updates it
mkdir -p ~/.agents/skills
ln -sfn "$PWD/skills/nitter-x" ~/.agents/skills/nitter-x
```

Paths for Claude Code and Codex follow their documentation as of writing;
confirm them against the client version you run. The DeepSeek Harness roots
were checked against its filesystem skill provider.

## Connect the tools

Pick one:

- **MCP (preferred)**: register `http://<host>:8080/mcp` with the header
  `Authorization: Bearer <token>`, or use the stdio bridge in
  `clients/mcp-stdio`.
- **No MCP**: set `NITTER_BASE_URL` and `NITTER_API_TOKEN` in the agent's
  environment. `nitter-x/scripts/nitter.sh` then works from any shell
  (needs only `curl`). The skill falls back to it automatically.

## Test a skill

Ask the agent, with the tools connected:

- "Summarise https://x.com/jack/status/20" (should read `references/thread-digest.md`)
- "What has @nim_lang posted about recently?" (`references/account-brief.md`)
- "Find tweets mentioning 'zig' from @ziglang since 2025-01-01" (`search_tweets`)

A good run calls few tools, cites tweet URLs, and reports how much it read.
