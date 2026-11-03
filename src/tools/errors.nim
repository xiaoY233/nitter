# SPDX-License-Identifier: AGPL-3.0-only
## Error model shared by the REST API and the MCP server.
import json, strutils
import ../types

type
  ToolError* = object of CatchableError
    code*: string        # stable, machine readable
    status*: int         # HTTP status for the REST API
    retryable*: bool
    retryAfter*: int     # seconds, 0 = unknown

proc cleanMsg*(msg: string): string =
  ## Async exceptions get "\nAsync traceback:..." appended; never expose it.
  let i = msg.find("\nAsync traceback")
  result = (if i >= 0: msg[0 ..< i] else: msg).strip()

proc toolError*(code, msg: string; status = 400; retryable = false;
                retryAfter = 0): ref ToolError =
  result = newException(ToolError, cleanMsg(msg))
  result.code = code
  result.status = status
  result.retryable = retryable
  result.retryAfter = retryAfter

proc invalidArg*(msg: string): ref ToolError =
  toolError("invalid_argument", msg, 400)

proc notFound*(msg: string): ref ToolError =
  toolError("not_found", msg, 404)

proc unauthorized*(msg: string): ref ToolError =
  toolError("unauthorized", msg, 401)

proc rateLimited*(msg: string; retryAfter: int): ref ToolError =
  toolError("rate_limited", msg, 429, true, retryAfter)

proc toJson*(e: ref ToolError): JsonNode =
  var err = %*{"code": e.code, "message": cleanMsg(e.msg), "retryable": e.retryable}
  if e.retryAfter > 0:
    err["retry_after_s"] = % e.retryAfter
  %*{"error": err}

proc toToolError*(e: ref Exception): ref ToolError =
  ## Maps any exception raised while serving a tool call to a ToolError.
  if e of ToolError:
    return (ref ToolError)(e)
  if e of RateLimitError:
    return toolError("rate_limited",
      "The upstream is rate limiting this instance. Retry later.", 429, true, 60)
  if e of NoSessionsError:
    return toolError("upstream_unavailable",
      "No upstream sessions are available (all rate limited or none configured). Retry later.",
      503, true, 60)
  if e of BadClientError:
    return toolError("upstream_unavailable", "Network error talking to the upstream. Retry.",
      503, true, 5)
  if e of InternalError:
    return toolError("upstream_error",
      "The upstream returned an unexpected response: " & cleanMsg(e.msg), 502, false)
  toolError("internal_error", "Unexpected error: " & cleanMsg(e.msg), 500, false)
