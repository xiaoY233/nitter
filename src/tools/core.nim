# SPDX-License-Identifier: AGPL-3.0-only
## Types shared by every tool and every transport (REST, MCP).
import asyncdispatch, json
import ../types

const
  serverVersion* = "1.1.0"  ## Software release; keep equal to `version` in nitter.nimble.
  apiVersion* = "v1"        ## Path prefix generation. Clients check compatibility on this.

type
  ToolCtx* = object
    cfg*: Config
    principal*: string

  ToolResult* = object
    data*: JsonNode       # structured payload
    markdown*: string     # compact, LLM-friendly rendering of the same payload
    cached*: bool
    fetchedAt*: string

  ToolHandler* = proc (ctx: ToolCtx; args: JsonNode): Future[ToolResult] {.closure.}

  ToolDef* = object
    name*: string         # snake_case, used by MCP and POST /api/v1/tools/{name}
    title*: string
    description*: string  # written for the model: when to use / when not to
    schema*: JsonNode     # JSON Schema (draft 2020-12 subset) of the arguments
    rest*: string         # REST path template, e.g. "/users/{username}"
    ttl*: int             # result cache time in seconds (0 = no cache)
    handler*: ToolHandler

proc findTool*(tools: openArray[ToolDef]; name: string): int =
  result = -1
  for i, t in tools:
    if t.name == name: return i
