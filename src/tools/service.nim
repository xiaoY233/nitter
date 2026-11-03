# SPDX-License-Identifier: AGPL-3.0-only
## The one entry point both transports use to run a tool: applies the
## per-principal rate/concurrency budget, then dispatches via the registry.
import asyncdispatch, json
import ../apiauth
import core, errors, registry

proc runGuarded*(ctx: ToolCtx; name: string; args: JsonNode):
    Future[tuple[res: ToolResult, remaining: int]] {.async.} =
  let remaining = acquire(ctx.cfg, ctx.principal)
  try:
    result.res = await callTool(ctx, name, args)
    result.remaining = remaining
  finally:
    release(ctx.principal)

proc errorText*(e: ref ToolError): string =
  result = "Error [" & e.code & "]: " & cleanMsg(e.msg)
  if e.retryable:
    result &= " (retryable"
    if e.retryAfter > 0: result &= ", retry after " & $e.retryAfter & "s"
    result &= ")"
  else:
    result &= " (not retryable)"
