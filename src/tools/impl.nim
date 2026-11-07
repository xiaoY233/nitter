# SPDX-License-Identifier: AGPL-3.0-only
## Tool implementations. Each handler validates nothing itself (the registry
## already applied the JSON schema) but normalises ids/usernames, calls the
## existing Nitter data layer and returns a DTO plus a Markdown rendering.
import asyncdispatch, json, strutils, sequtils, options, times, sets
import ../[types, api, redis_cache, query, utils]
import core, errors, validate, dto

type TimelineFetcher* = proc (cursor: string): Future[Timeline] {.closure.}

# ----------------------------------------------------------------- helpers

proc nowIso(): string = now().utc.format("yyyy-MM-dd'T'HH:mm:ss'Z'")

const emptyCursorWarning* =
  "No results for a request that carried a cursor. The cursor may have expired or " &
  "been altered; this is not proof that there is nothing more. Repeat the original " &
  "request without `cursor` to start again."

proc page*(items: JsonNode; next: string; more: bool; cursor = ""): JsonNode =
  ## A page that is empty although a cursor was passed is ambiguous: the
  ## upstream answers an expired or foreign cursor the same way as the end of
  ## the list, so say which it might be instead of leaving the agent to guess.
  result = %*{"items": items, "next_cursor": (if more and next.len > 0: % next else: newJNull()),
              "has_more": more and next.len > 0}
  if cursor.len > 0 and items.len == 0:
    result["warning"] = % emptyCursorWarning

template done(d: JsonNode; md: string): ToolResult =
  ToolResult(data: d, markdown: md, fetchedAt: nowIso())

proc resolveUser(name: string): Future[tuple[id: string, user: User]] {.async.} =
  ## Shared lookup: maps "missing"/"suspended"/"protected" to precise errors.
  let id = await getUserId(name)
  if id.len == 0:
    raise notFound("User @" & name & " was not found. Check the spelling; if the handle " &
                   "is certainly valid the upstream may be rejecting this instance's " &
                   "sessions (see /api/v1/health).")
  if id == "suspended":
    raise toolError("user_suspended", "User @" & name & " has been suspended.", 404)
  result.id = id
  result.user = await getCachedUser(name)

proc requireVisible(u: User; what: string) =
  if u.protected:
    raise toolError("protected_account",
      "@" & u.username & " is a protected account; " & what & " are not publicly visible.", 403)

proc nextSearchCursor*(tl: Timeline; q: Query): string =
  ## Mirrors views/timeline.getSearchMaxId: date-bounded searches must page by
  ## max_id because the upstream cursor repeats the last page.
  if q.kind == QueryKind.tweets and q.until.len > 0 and tl.content.len > 0:
    let last = tl.content[^1]
    if last.len > 0 and last[^1].id != 0:
      var maxId = last[^1].id - 2_000_000'i64
      if maxId <= 0: maxId = last[^1].id - 1
      if maxId > 0: return "maxid:" & $maxId
  tl.bottom

proc collect*(fetch: TimelineFetcher; cursor: string; limit, maxPages: int;
             q: Query; useMaxId: bool; dropRetweets = false):
    Future[tuple[tweets: seq[Tweet], next: string, more: bool]] {.async.} =
  ## Fetches whole pages until at least `limit` tweets were collected.
  ## dropRetweets: X's search keeps returning native retweets for `from:` queries
  ## even when `include:nativeretweets` is absent, so the filter is applied here.
  var cur = cursor
  var seen = initHashSet[int64]()
  for i in 0 ..< max(maxPages, 1):
    let tl = await fetch(cur)
    var added = 0
    var skipped = 0
    for thread in tl.content:
      for t in thread:
        if t.isNil or t.id == 0 or t.isAd or t.id in seen: continue
        seen.incl t.id
        if dropRetweets and t.retweet.isSome:
          inc skipped
          continue
        result.tweets.add t
        inc added
    let nxt = if useMaxId: nextSearchCursor(tl, q) else: tl.bottom
    result.next = nxt
    # A page that held only retweets still means "keep going".
    result.more = added + skipped > 0 and nxt.len > 0 and nxt != cur
    if not result.more or result.tweets.len >= limit: break
    cur = nxt
  if not result.more: result.next = ""

proc tweetList(title: string; items: JsonNode; next: string; more: bool;
               note = ""): string =
  var parts = @[title]
  if items.len == 0:
    parts.add "(no tweets found)"
  for t in items: parts.add tweetMd(t)
  parts.join("\n\n") & "\n\n" &
    footer(next, more, (if note.len > 0: "note: " & note else: ""))

# ------------------------------------------------------------------- tools

proc getUserTool*(ctx: ToolCtx; args: JsonNode): Future[ToolResult] {.async.} =
  let name = normalizeUsername(args{"username"}.getStr)
  let (_, user) = await resolveUser(name)
  var d = userDto(user, ctx.cfg)
  if args{"include_about"}.getBool:
    let info = await getCachedAccountInfo(name)
    if info.username.len > 0:
      d["about"] = aboutDto(info)
  done(d, userMd(d))

proc getUserTimelineTool*(ctx: ToolCtx; args: JsonNode): Future[ToolResult] {.async.} =
  let
    name = normalizeUsername(args{"username"}.getStr)
    tab = args{"tab"}.getStr
    cursor = validateCursor(args{"cursor"}.getStr)
    limit = args{"limit"}.getInt
  let (id, user) = await resolveUser(name)
  requireVisible(user, "tweets")

  let kind = case tab
    of "replies": TimelineKind.replies
    of "media": TimelineKind.media
    of "articles": TimelineKind.articles
    else: TimelineKind.tweets

  var pinned: Option[Tweet]
  let fetcher = proc (c: string): Future[Timeline] {.async.} =
    let p = await getGraphUserTweets(id, kind, c)
    if c.len == 0 and p.pinned.isSome: pinned = p.pinned
    return p.tweets

  var r = await collect(fetcher, cursor, limit, ctx.cfg.apiMaxPages, Query(), false)
  if pinned.isSome and cursor.len == 0 and kind == TimelineKind.tweets:
    let pt = pinned.get
    if pt.id != 0 and pt.id notin r.tweets.mapIt(it.id):
      pt.pinned = true
      r.tweets.insert(pt, 0)

  let items = tweetsDto(r.tweets, ctx.cfg)
  var d = page(items, r.next, r.more, cursor)
  d["user"] = %*{"username": user.username, "name": user.fullname}
  d["tab"] = % tab
  done(d, tweetList("# @" & user.username & " — " & tab & " (" & $items.len & " tweets)",
                    items, r.next, r.more, d{"warning"}.getStr))

proc loadConversation(id: string; cursor, sort: string): Future[Conversation] {.async.} =
  let mode = parseEnum[RankingMode](sort.capitalizeAscii, Relevance)
  result = await getTweet(id, cursor, mode)
  if result.isNil or result.tweet.isNil or result.tweet.id == 0:
    var msg = "Tweet " & id & " was not found."
    if not result.isNil and not result.tweet.isNil and result.tweet.tombstone.len > 0:
      msg = "Tweet " & id & " is unavailable: " & plainText(result.tweet.tombstone)
    raise notFound(msg)

proc attachArticle(d: JsonNode; id: string) {.async.} =
  ## An article tweet has no text of its own: the body is a separate upstream
  ## document. Adds it as article.body (Markdown) when the tweet is an article.
  if not d.hasKey("article"): return
  let art = await getGraphArticle(id)
  if art.isNil or art.paragraphs.len == 0:
    d["article"]["body_unavailable"] = % true
    return
  let (md, cut) = articleMarkdown(art)
  d["article"]["body"] = % md
  d["article"]["truncated"] = % cut

proc articleNote(d: JsonNode): string =
  if not d.hasKey("article"): return ""
  let a = d["article"]
  if a.hasKey("body"):
    result = "\n\n## Article body (untrusted)\n\n" & fence(a["body"].getStr)
    if a["truncated"].getBool:
      result &= "\n\n[article truncated at " & $articleBodyMax & " characters; read the rest at " &
                a["url"].getStr & "]"
  elif a{"body_unavailable"}.getBool:
    result = "\n\n[article body could not be read; open " & a["url"].getStr & "]"
  elif d{"text"}.getStr.len == 0:
    result = "\n\n[this tweet is an article; call again with include_article=true to read it]"

proc getTweetTool*(ctx: ToolCtx; args: JsonNode): Future[ToolResult] {.async.} =
  let id = parseTweetRef(args{"tweet"}.getStr)
  let conv = await loadConversation(id, "", "relevance")
  let d = tweetDto(conv.tweet, ctx.cfg)
  if args{"include_article"}.getBool:
    await attachArticle(d, id)
  done(d, tweetMd(d) & articleNote(d))

proc limitReplies*(chains: seq[Chain]; cfg: Config; maxReplies: int):
    tuple[kept: JsonNode, dropped: int] =
  ## Keeps whole reply threads until `maxReplies` tweets are reached (the first
  ## thread is always kept so a long one cannot yield an empty result) and
  ## counts the threads left out.
  result.kept = newJArray()
  var count = 0
  for chain in chains:
    let tweets = tweetsDto(chain.content, cfg)
    if tweets.len == 0: continue
    if count + tweets.len > maxReplies and count > 0:
      inc result.dropped
      continue
    count += tweets.len
    result.kept.add tweets

proc getThreadTool*(ctx: ToolCtx; args: JsonNode): Future[ToolResult] {.async.} =
  let
    id = parseTweetRef(args{"tweet"}.getStr)
    cursor = validateCursor(args{"cursor"}.getStr)
    withReplies = args{"include_replies"}.getBool
    maxReplies = args{"max_replies"}.getInt
  let conv = await loadConversation(id, cursor, args{"sort"}.getStr)
  let cfg = ctx.cfg

  var d = %*{
    "tweet": tweetDto(conv.tweet, cfg),
    "ancestors": tweetsDto(conv.before.content, cfg),
    "continuation": tweetsDto(conv.after.content, cfg)
  }

  if args{"include_article"}.getBool:
    await attachArticle(d["tweet"], id)

  var replyChains = newJArray()
  var dropped = 0
  var next = ""
  var more = false
  if withReplies:
    (replyChains, dropped) = limitReplies(conv.replies.content, cfg, maxReplies)
    # The upstream cursor continues *after* the whole page we fetched, so threads
    # dropped here cannot be reached with it. Say so instead of hiding it; the
    # agent can raise max_replies to see them.
    next = conv.replies.bottom
    more = conv.replies.content.len > 0 and next.len > 0
  d["replies"] = replyChains
  d["next_cursor"] = if more: % next else: newJNull()
  d["has_more"] = % more
  if dropped > 0:
    d["replies_omitted"] = % dropped
  if withReplies and cursor.len > 0 and replyChains.len == 0:
    d["warning"] = % emptyCursorWarning

  var parts: seq[string]
  if d["ancestors"].len > 0:
    parts.add "## Earlier in the conversation"
    for t in d["ancestors"]: parts.add tweetMd(t)
  parts.add "## Tweet"
  parts.add tweetMd(d["tweet"]) & articleNote(d["tweet"])
  if d["continuation"].len > 0:
    parts.add "## Author's continuation"
    for t in d["continuation"]: parts.add tweetMd(t)
  if withReplies:
    parts.add "## Replies (" & $replyChains.len & " threads" &
              (if cursor.len > 0: ", continued page" else: "") & ")"
    if replyChains.len == 0: parts.add "(no replies)"
    var n = 0
    for chain in replyChains:
      inc n
      parts.add "### Reply thread " & $n
      for t in chain: parts.add tweetMd(t, "")
  let note = if dropped > 0:
      "omitted " & $dropped & " more reply thread(s) on this page because of max_replies; " &
      "raise max_replies to see them (next_cursor continues with the following page)"
    elif d.hasKey("warning"): emptyCursorWarning
    else: ""
  done(d, parts.join("\n\n") & "\n\n" & footer(next, more, (if note.len > 0: "note: " & note else: "")))

proc searchTweetsTool*(ctx: ToolCtx; args: JsonNode): Future[ToolResult] {.async.} =
  let
    text = args{"query"}.getStr
    fromRaw = args{"from"}.getStr
    cursor = validateCursor(args{"cursor"}.getStr)
    limit = args{"limit"}.getInt
    mode = args{"mode"}.getStr

  var users: seq[string]
  for part in fromRaw.split(','):
    if part.strip().len > 0: users.add normalizeUsername(part)
  if users.len > maxFromHandles:
    raise invalidArg("'from' takes at most " & $maxFromHandles & " handles, got " & $users.len)
  if text.len == 0 and users.len == 0:
    raise invalidArg("Provide 'query' and/or 'from'.")

  var q = Query(
    kind: (case mode
           of "top": QueryKind.top
           of "media": QueryKind.media
           else: QueryKind.tweets),
    text: text,
    fromUser: users,
    since: validateDate(args{"since"}.getStr, "since"),
    until: validateDate(args{"until"}.getStr, "until"),
    minLikes: validateMinLikes(args{"min_likes"}.getStr),
    sep: "OR")
  if args{"filter"}.getStr.len > 0:
    q.filters = @[args{"filter"}.getStr]
  if not args{"include_retweets"}.getBool:
    q.excludes = @["nativeretweets"]

  validateDateRange(q.since, q.until)
  let fetcher = proc (c: string): Future[Timeline] = getGraphTweetSearch(q, c)
  let r = await collect(fetcher, cursor, limit, ctx.cfg.apiMaxPages, q, true,
                        dropRetweets = not args{"include_retweets"}.getBool)
  let items = tweetsDto(r.tweets, ctx.cfg)
  var d = page(items, r.next, r.more, cursor)
  d["query"] = % genQueryParam(q)
  done(d, tweetList("# Search: `" & genQueryParam(q) & "` (" & $items.len & " tweets)",
                    items, r.next, r.more, d{"warning"}.getStr))

proc searchUsersTool*(ctx: ToolCtx; args: JsonNode): Future[ToolResult] {.async.} =
  let
    text = args{"query"}.getStr
    cursor = validateCursor(args{"cursor"}.getStr)
  let res = await getGraphUserSearch(Query(kind: users, text: text), cursor)
  var items = newJArray()
  for u in res.content:
    if u.username.len > 0: items.add userDto(u, ctx.cfg)
  let more = items.len > 0 and res.bottom.len > 0
  var parts = @["# People matching `" & text & "` (" & $items.len & ")"]
  if items.len == 0: parts.add "(no users found)"
  for u in items: parts.add userMd(u)
  let d = page(items, res.bottom, more, cursor)
  done(d, parts.join("\n\n") & "\n\n" &
       footer(res.bottom, more, (if d.hasKey("warning"): "note: " & emptyCursorWarning else: "")))

proc connectionsTool*(ctx: ToolCtx; args: JsonNode): Future[ToolResult] {.async.} =
  let
    name = normalizeUsername(args{"username"}.getStr)
    kind = args{"kind"}.getStr
    cursor = validateCursor(args{"cursor"}.getStr)
  let (id, user) = await resolveUser(name)
  requireVisible(user, kind)
  let res = if kind == "followers": await getGraphFollowers(id, cursor)
            else: await getGraphFollowing(id, cursor)
  var items = newJArray()
  for u in res.content:
    if u.username.len > 0: items.add userDto(u, ctx.cfg)
  let more = items.len > 0 and res.bottom.len > 0
  var parts = @["# @" & name & " — " & kind & " (" & $items.len & " on this page)"]
  if items.len == 0: parts.add "(none)"
  for u in items: parts.add userMd(u)
  var d = page(items, res.bottom, more, cursor)
  d["user"] = % name
  d["kind"] = % kind
  done(d, parts.join("\n\n") & "\n\n" &
       footer(res.bottom, more, (if d.hasKey("warning"): "note: " & emptyCursorWarning else: "")))
