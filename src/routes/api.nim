# SPDX-License-Identifier: AGPL-3.0-only
## Agent API: REST (/api/v1/*) and MCP (/mcp). Read-only. Disabled unless
## [Api] enabled = true. All behaviour lives in src/tools; this file only maps
## HTTP onto it.
import asyncdispatch, json, strutils, tables, httpcore, uri

import jester

import ../[types, apiauth, auth]
import ../tools/[core, errors, registry, service, mcp, openapi]

export json, httpcore, core, errors, registry, openapi

type Reply* = object
  code: HttpCode
  headers: seq[(string, string)]
  body: string

proc reply*(code: HttpCode; headers: seq[(string, string)]; body: string): Reply =
  Reply(code: code, headers: headers, body: body)

const
  jsonType* = "application/json; charset=utf-8"
  mdType* = "text/markdown; charset=utf-8"

proc baseHeaders*(contentType: string): seq[(string, string)] =
  @[("Content-Type", contentType), ("Cache-Control", "no-store"),
    ("X-Content-Type-Options", "nosniff")]

proc errorReply*(e: ref ToolError): Reply =
  var h = baseHeaders(jsonType)
  if e.retryAfter > 0: h.add ("Retry-After", $e.retryAfter)
  if e.status == 401: h.add ("WWW-Authenticate", "Bearer")
  reply(HttpCode(e.status), h, $toJson(e))

proc serverUrl*(cfg: Config; host: string): string =
  (if cfg.useHttps: "https://" else: "http://") & cfg.hostname

proc authorize*(cfg: Config; req: Request): string =
  checkOrigin(cfg, req.headers.getOrDefault("Origin"), req.headers.getOrDefault("Host"))
  authenticate(cfg, req.headers.getOrDefault("Authorization"),
               req.headers.getOrDefault("X-API-Key"))

proc paramsToJson*(p: Table[string, string]; pathKeys: openArray[string] = []): JsonNode =
  ## Query-string values are already decoded by Jester, path captures are not.
  ## Decode only the latter (and keep '+' literal) so that e.g.
  ## /tweets/https%3A%2F%2Fx.com%2Fjack%2Fstatus%2F20 works.
  result = newJObject()
  for k, v in p:
    result[k] = % (if k in pathKeys: decodeUrl(v, decodePlus = false) else: v)

proc serveTool*(cfg: Config; req: Request; name: string; args: JsonNode): Future[Reply] {.async.} =
  ## Never raises.
  try:
    let principal = authorize(cfg, req)
    let ctx = ToolCtx(cfg: cfg, principal: principal)
    let (res, remaining) = await runGuarded(ctx, name, args)
    let format = (if args.hasKey("format"): args["format"].getStr else: "json").toLowerAscii
    var h = baseHeaders(if format == "markdown": mdType else: jsonType)
    h.add ("X-Cache", if res.cached: "HIT" else: "MISS")
    if remaining >= 0: h.add ("X-RateLimit-Remaining", $remaining)
    if format == "markdown":
      return reply(Http200, h, res.markdown)
    return reply(Http200, h, $(%*{"data": res.data,
                             "meta": {"cached": res.cached, "fetched_at": res.fetchedAt}}))
  except CatchableError as e:
    return errorReply(toToolError(e))

proc serveMcp*(cfg: Config; req: Request): Future[Reply] {.async.} =
  try:
    let principal = authorize(cfg, req)

    let ver = req.headers.getOrDefault("MCP-Protocol-Version")
    if ver.len > 0 and $ver notin supportedVersions:
      raise toolError("unsupported_protocol_version",
        "Unsupported MCP-Protocol-Version '" & $ver & "'. Supported: " &
        supportedVersions.join(", "), 400)

    var msg: JsonNode
    try:
      msg = parseJson(req.body)
    except CatchableError:
      return reply(Http400, baseHeaders(jsonType),
              $(%*{"jsonrpc": "2.0", "id": nil,
                   "error": {"code": -32700, "message": "Parse error"}}))

    let ctx = ToolCtx(cfg: cfg, principal: principal)
    if msg.kind == JArray:                 # JSON-RPC batch (2025-03-26 clients)
      var outs = newJArray()
      for m in msg:
        let r = await handleMessage(ctx, m)
        if r.kind != JNull: outs.add r
      if outs.len == 0: return reply(Http202, baseHeaders(jsonType), "")
      return reply(Http200, baseHeaders(jsonType), $outs)

    let r = await handleMessage(ctx, msg)
    if r.kind == JNull:
      return reply(Http202, baseHeaders(jsonType), "")
    return reply(Http200, baseHeaders(jsonType), $r)
  except CatchableError as e:
    let te = toToolError(e)
    var rep = errorReply(te)
    rep.body = $(%*{"jsonrpc": "2.0", "id": nil,
                    "error": {"code": -32000, "message": cleanMsg(te.msg), "data": toJson(te)["error"]}})
    return rep

proc healthReply*(cfg: Config): Reply =
  let s = getSessionPoolHealth(){"sessions"}
  let total = s{"total"}.getInt
  let limited = s{"limited"}.getInt
  let status = if total == 0: "no_sessions" elif limited >= total: "all_limited" else: "ok"
  let code = if status == "ok": Http200 else: Http503
  reply(code, baseHeaders(jsonType),
   $(%*{"status": status, "sessions": {"total": total, "limited": limited}}))

template send*(r: Reply) =
  let apiReply = r
  resp(apiReply.code, apiReply.headers, apiReply.body)

proc createApiRouter*(cfg: Config) =
  router api:
    get "/api/v1/health":
      cond cfg.apiEnabled
      send healthReply(cfg)

    get "/api/v1/openapi.json":
      cond cfg.apiEnabled
      var h = baseHeaders(jsonType)
      send(reply(Http200, h, $openApiDoc(serverUrl(cfg, ""))))

    get "/llms.txt":
      cond cfg.apiEnabled
      send(reply(Http200, baseHeaders("text/plain; charset=utf-8"), llmsTxt(serverUrl(cfg, ""))))

    get "/api/v1/tools":
      cond cfg.apiEnabled
      try:
        discard authorize(cfg, request)
      except CatchableError as e:
        send errorReply(toToolError(e))
      var arr = newJArray()
      for t in tools:
        arr.add %*{"name": t.name, "title": t.title, "description": t.description,
                   "inputSchema": t.schema, "rest": "/api/v1" & t.rest}
      send(reply(Http200, baseHeaders(jsonType), $(%*{"tools": arr})))

    post "/api/v1/tools/@name":
      cond cfg.apiEnabled
      var args = newJObject()
      if request.body.len > 0:
        try:
          args = parseJson(request.body)
        except CatchableError:
          send errorReply(invalidArg("Request body must be a JSON object"))
      send await serveTool(cfg, request, @"name", args)

    get "/api/v1/users/@username":
      cond cfg.apiEnabled
      send await serveTool(cfg, request, "get_user", paramsToJson(params(request), ["username"]))

    get "/api/v1/users/@username/tweets":
      cond cfg.apiEnabled
      send await serveTool(cfg, request, "get_user_timeline", paramsToJson(params(request), ["username"]))

    get "/api/v1/users/@username/connections":
      cond cfg.apiEnabled
      send await serveTool(cfg, request, "get_user_connections", paramsToJson(params(request), ["username"]))

    get "/api/v1/tweets/@tweet":
      cond cfg.apiEnabled
      send await serveTool(cfg, request, "get_tweet", paramsToJson(params(request), ["tweet"]))

    get "/api/v1/tweets/@tweet/thread":
      cond cfg.apiEnabled
      send await serveTool(cfg, request, "get_thread", paramsToJson(params(request), ["tweet"]))

    get "/api/v1/search/tweets":
      cond cfg.apiEnabled
      send await serveTool(cfg, request, "search_tweets", paramsToJson(params(request)))

    get "/api/v1/search/users":
      cond cfg.apiEnabled
      send await serveTool(cfg, request, "search_users", paramsToJson(params(request)))

    post "/mcp":
      cond cfg.apiEnabled and cfg.apiMcpEnabled
      send await serveMcp(cfg, request)

    get "/mcp":
      cond cfg.apiEnabled and cfg.apiMcpEnabled
      var h = baseHeaders(jsonType)
      h.add ("Allow", "POST")
      send(reply(Http405, h, ""))

    delete "/mcp":
      cond cfg.apiEnabled and cfg.apiMcpEnabled
      var h = baseHeaders(jsonType)
      h.add ("Allow", "POST")
      send(reply(Http405, h, ""))
