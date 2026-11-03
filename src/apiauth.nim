# SPDX-License-Identifier: AGPL-3.0-only
## Authentication, rate limiting and concurrency limiting for the agent API.
## State is in-process (Nitter runs a single async event loop), which is exactly
## what a personal/intranet deployment needs.
import tables, times, strutils, uri
import nimcrypto
import types, tools/errors

type
  Bucket = object
    windowStart: int64
    count: int
    inflight: int

var
  buckets = initTable[string, Bucket]()
  lastPrune = 0'i64

const pruneEverySeconds = 300

proc pruneBuckets*(now: int64) =
  ## Drops principals that have nothing in flight and whose window has expired,
  ## so the table cannot grow without bound. Runs at most every 5 minutes.
  if now - lastPrune < pruneEverySeconds: return
  lastPrune = now
  var stale: seq[string]
  for k, b in buckets:
    if b.inflight == 0 and now - b.windowStart >= 60:
      stale.add k
  for k in stale: buckets.del k

proc bucketCount*(): int = buckets.len

proc digest(s: string): string =
  $sha256.digest(s)

proc safeEqual(a, b: string): bool =
  ## constant time over equal-length digests
  if a.len != b.len: return false
  var diff = 0
  for i in 0 ..< a.len:
    diff = diff or (ord(a[i]) xor ord(b[i]))
  diff == 0

proc extractToken*(authorization, apiKey: string): string =
  let a = authorization.strip()
  if a.len > 7 and a[0 .. 6].toLowerAscii == "bearer ":
    return a[7 .. ^1].strip()
  apiKey.strip()

proc authenticate*(cfg: Config; authorization, apiKey: string): string =
  ## Returns the principal name or raises unauthorized.
  let token = extractToken(authorization, apiKey)
  if token.len > 0:
    let d = digest(token)
    var found = ""
    for t in cfg.apiTokens:          # no early exit: keep timing uniform
      if safeEqual(d, digest(t.secret)): found = t.name
    if found.len > 0: return found
    raise unauthorized("Invalid API token")
  if cfg.apiAllowAnonymous:
    return "anonymous"
  raise unauthorized("Missing API token. Send 'Authorization: Bearer <token>' or 'X-API-Key: <token>'.")

proc checkOrigin*(cfg: Config; origin, host: string) =
  ## Blocks browser-driven cross-origin calls (DNS rebinding protection, MCP spec).
  ## Non-browser clients send no Origin header and are unaffected.
  if origin.len == 0: return
  if origin in cfg.apiOrigins: return
  let h = parseUri(origin).hostname.toLowerAscii
  let hostOnly = host.rsplit(':', maxsplit = 1)[0].strip(chars = {'[', ']'}).toLowerAscii
  if h.len > 0 and h == hostOnly: return
  raise toolError("forbidden_origin",
    "Cross-origin requests are not allowed. Add the origin to [Api] allowedOrigins.", 403)

proc acquire*(cfg: Config; principal: string): int =
  ## Counts the request against the principal's per-minute budget and reserves a
  ## concurrency slot. Returns remaining requests in the window.
  ## Every successful acquire must be paired with release().
  let now = getTime().toUnix
  pruneBuckets(now)
  var b = buckets.getOrDefault(principal, Bucket(windowStart: now))
  if now - b.windowStart >= 60:
    b.windowStart = now
    b.count = 0
  if cfg.apiRpm > 0 and b.count >= cfg.apiRpm:
    let wait = int(60 - (now - b.windowStart))
    buckets[principal] = b
    raise rateLimited("Request budget exhausted (" & $cfg.apiRpm & "/min). Slow down.",
                      max(wait, 1))
  if cfg.apiMaxConcurrent > 0 and b.inflight >= cfg.apiMaxConcurrent:
    buckets[principal] = b
    raise rateLimited("Too many concurrent requests (max " & $cfg.apiMaxConcurrent &
                      "). Wait for earlier calls to finish.", 2)
  inc b.count
  inc b.inflight
  buckets[principal] = b
  if cfg.apiRpm > 0: cfg.apiRpm - b.count else: -1

proc release*(principal: string) =
  if principal in buckets and buckets[principal].inflight > 0:
    dec buckets[principal].inflight
