# SPDX-License-Identifier: AGPL-3.0-only
## Converts Nitter's internal objects into compact, stable, LLM-friendly DTOs
## and renders those DTOs as Markdown. ids are always strings (int64 loses
## precision in JS clients), times are ISO-8601 UTC, urls are absolute.
import json, strutils, sequtils, options, times, algorithm
import std/re
import ../[types, formatters, utils]

const
  xHost = "https://x.com"
  twimgBase = "https://pbs.twimg.com/"

let
  tagRe = re"<[^>]*>"
  wrapperRe = re"(?i)<(/?)tweet"

# ---------------------------------------------------------------- helpers

proc iso(t: DateTime): string =
  if t.year < 2006: return ""     # zero value => unknown
  t.utc.format("yyyy-MM-dd'T'HH:mm:ss'Z'")

proc plainText*(html: string): string =
  ## Tweet text is stored as HTML (anchors for links/mentions/hashtags).
  ## Returns plain text with t.co links already expanded.
  if html.len == 0: return ""
  try:
    result = stripHtml(html)
  except CatchableError:
    result = html.replace(tagRe, "")
  result = result.replace("\r\n", "\n").strip()

proc absMedia(url: string): string =
  if url.len == 0 or url.startsWith("http"): return url
  if "twimg.com" in url: https & url else: twimgBase & url

proc picUrl(cfg: Config; url: string; orig = false): string =
  let full = absMedia(url)
  if full.len == 0: return ""
  if cfg.apiMediaProxy:
    getUrlPrefix(cfg) & (if orig: getOrigPicUrl(full) else: getPicUrl(full))
  elif orig and full.startsWith(twimgBase):
    full & "?name=orig"
  else:
    full

proc videoUrl(cfg: Config; url: string): string =
  let full = absMedia(url)
  if cfg.apiMediaProxy and full.startsWith("http"):
    getUrlPrefix(cfg) & getVidUrl(full)
  else:
    full

proc tweetUrl*(username: string; id: int64): string =
  xHost & "/" & (if username.len > 0: username else: "i") & "/status/" & $id

# ------------------------------------------------------------------- users

proc userDto*(u: User; cfg: Config): JsonNode =
  result = %*{
    "id": u.id,
    "username": u.username,
    "name": u.fullname,
    "url": xHost & "/" & u.username,
    "bio": plainText(u.bio),
    "location": u.location,
    "website": u.website,
    "avatar": picUrl(cfg, u.getUserPic("_400x400")),
    "verified": (if u.verifiedType == VerifiedType.none: newJNull()
                 else: % toLowerAscii($u.verifiedType)),
    "protected": u.protected,
    "joined": iso(u.joinDate),
    "stats": {"followers": u.followers, "following": u.following,
              "tweets": u.tweets, "likes": u.likes, "media": u.media}
  }
  if u.banner.len > 0:
    result["banner"] = % picUrl(cfg, u.banner)
  if u.pinnedTweet != 0:
    result["pinned_tweet_id"] = % $u.pinnedTweet

proc userBrief(u: User): JsonNode =
  %*{"username": u.username, "name": u.fullname,
     "verified": u.verifiedType != VerifiedType.none}

proc aboutDto*(a: AccountInfo): JsonNode =
  result = newJObject()
  if a.basedIn.len > 0: result["based_in"] = % a.basedIn
  if a.source.len > 0: result["source"] = % a.source
  result["username_changes"] = % a.usernameChanges
  result["identity_verified"] = % a.isIdentityVerified
  if a.affiliateLabel.len > 0: result["affiliate"] = % a.affiliateLabel

# ------------------------------------------------------------------ tweets

proc mediaDto(cfg: Config; m: Media): JsonNode =
  case m.kind
  of photoMedia:
    result = %*{"type": "photo", "url": picUrl(cfg, m.photo.url, orig = true)}
    if m.photo.altText.len > 0: result["alt_text"] = % m.photo.altText
  of videoMedia:
    let v = m.video
    let mp4s = v.variants.filterIt(it.contentType == mp4).sortedByIt(it.bitrate)
    let m3u8s = v.variants.filterIt(it.contentType == VideoType.m3u8)
    result = %*{"type": "video", "available": v.available,
                "thumbnail": picUrl(cfg, v.thumb),
                "duration_ms": v.durationMs}
    if mp4s.len > 0: result["url"] = % videoUrl(cfg, mp4s[^1].url)
    if m3u8s.len > 0: result["playlist"] = % videoUrl(cfg, m3u8s[0].url)
    if v.title.len > 0: result["alt_text"] = % v.title
  of gifMedia:
    result = %*{"type": "gif", "url": picUrl(cfg, m.gif.url),
                "thumbnail": picUrl(cfg, m.gif.thumb)}
    if m.gif.altText.len > 0: result["alt_text"] = % m.gif.altText

proc tweetDto*(t: Tweet; cfg: Config; depth = 0): JsonNode =
  if t.isNil: return newJNull()

  # A retweet wrapper: present the original, record who retweeted it.
  if t.retweet.isSome and t.retweet.get.id != 0:
    result = tweetDto(t.retweet.get, cfg, depth)
    result["retweeted_by"] = userBrief(t.user)
    result["retweet_id"] = % $t.id
    let at = iso(t.time)
    if at.len > 0: result["retweeted_at"] = % at
    return

  result = %*{"id": $t.id, "url": tweetUrl(t.user.username, t.id),
              "available": t.available}
  if not t.available:
    if t.tombstone.len > 0: result["tombstone"] = % t.tombstone
    elif t.text.len > 0: result["tombstone"] = % plainText(t.text)
    return

  result["author"] = userBrief(t.user)
  result["text"] = % plainText(t.text)
  let at = iso(t.time)
  if at.len > 0: result["created_at"] = % at
  result["stats"] = %*{"replies": t.stats.replies, "reposts": t.stats.retweets,
                       "likes": t.stats.likes, "views": t.stats.views}
  if t.threadId != 0: result["conversation_id"] = % $t.threadId
  if t.replyId != 0: result["in_reply_to_id"] = % $t.replyId
  if t.reply.len > 0: result["replying_to"] = % t.reply
  if t.pinned: result["pinned"] = % true
  if t.location.len > 0: result["location"] = % t.location
  if t.note.len > 0: result["community_note"] = % plainText(t.note)
  if t.isAI: result["ai_generated"] = % true

  if t.media.len > 0:
    result["media"] = % t.media.mapIt(mediaDto(cfg, it))

  if t.poll.isSome:
    let p = t.poll.get
    var opts = newJArray()
    for i, o in p.options:
      opts.add %*{"label": o, "votes": (if i < p.values.len: p.values[i] else: 0)}
    result["poll"] = %*{"options": opts, "total_votes": p.votes, "status": p.status}

  if t.card.isSome:
    let c = t.card.get
    if c.kind notin {CardKind.hidden, CardKind.unknown}:
      var card = %*{"kind": $c.kind}
      if c.title.len > 0: card["title"] = % c.title
      if c.text.len > 0: card["description"] = % c.text
      if c.url.len > 0 and not c.url.startsWith("card://"): card["url"] = % c.url
      if c.dest.len > 0: card["domain"] = % c.dest
      if c.image.len > 0: card["image"] = % picUrl(cfg, c.image)
      result["card"] = card

  if t.articlePreview.isSome:
    let a = t.articlePreview.get
    result["article"] = %*{"title": a.title, "preview": a.previewText,
                           "url": xHost & "/i/article/" & $a.tweetId}

  if t.quote.isSome and depth < 1:       # quotes nest one level only
    let q = t.quote.get
    if q.id != 0:
      result["quote"] = tweetDto(q, cfg, depth + 1)

proc tweetsDto*(tweets: seq[Tweet]; cfg: Config): JsonNode =
  result = newJArray()
  for t in tweets:
    if not t.isNil and not t.isAd:
      result.add tweetDto(t, cfg)

# --------------------------------------------------------------- Markdown
# Tweet text is attacker-controlled. Every tweet is wrapped in an explicit
# <tweet untrusted> block and the wrapper tag is neutralised inside the text.

proc fence(text: string): string =
  text.replace(wrapperRe, "‹$1tweet")

proc num(n: int): string =
  if n >= 1_000_000: formatFloat(n / 1_000_000, ffDecimal, 1) & "M"
  elif n >= 10_000: formatFloat(n / 1_000, ffDecimal, 1) & "K"
  else: $n

proc shortTime(iso: string): string =
  if iso.len >= 16: iso[0..9] & " " & iso[11..15] & " UTC" else: iso

proc tweetBody(t: JsonNode; quoted: bool): seq[string] =
  let a = t{"author"}
  if t{"available"}.getBool(true) == false:
    result.add "[unavailable] " & fence(t{"tombstone"}.getStr("Tweet is unavailable"))
    return

  var head = "**" & fence(a{"name"}.getStr) & "** @" & a{"username"}.getStr
  if a{"verified"}.getBool: head &= " ✓"
  if t.hasKey("created_at"): head &= " · " & shortTime(t["created_at"].getStr)
  result.add head

  if t.hasKey("replying_to") and not quoted:
    result.add "replying to " & t["replying_to"].mapIt("@" & it.getStr).join(" ")
  let text = t{"text"}.getStr
  if text.len > 0: result.add fence(text)

  for m in (if t.hasKey("media"): t["media"].getElems else: @[]):
    var line = "[" & m["type"].getStr & "] " & m{"url"}.getStr(m{"playlist"}.getStr)
    if m.hasKey("alt_text"): line &= " (alt: " & fence(m["alt_text"].getStr) & ")"
    result.add line
  if t.hasKey("poll"):
    result.add "[poll] " & t["poll"]["options"].mapIt(
      fence(it["label"].getStr) & " " & $it["votes"].getInt).join(" | ")
  if t.hasKey("card"):
    let c = t["card"]
    result.add "[link] " & fence(c{"title"}.getStr) &
      (if c.hasKey("url"): " <" & c["url"].getStr & ">" else: "")
  if t.hasKey("article"):
    result.add "[article] " & fence(t["article"]["title"].getStr) & " <" &
      t["article"]["url"].getStr & ">"
  if t.hasKey("community_note"):
    result.add "[community note] " & fence(t["community_note"].getStr)

  if t.hasKey("quote"):
    let inner = tweetBody(t["quote"], true)
    result.add "> quoting: " & inner[0]
    for l in inner[1 .. ^1]:
      result.add "> " & l

  if not quoted:
    let s = t["stats"]
    result.add "likes " & num(s["likes"].getInt) & " · reposts " &
      num(s["reposts"].getInt) & " · replies " & num(s["replies"].getInt) &
      " · views " & num(s["views"].getInt)

proc tweetMd*(t: JsonNode; indent = ""): string =
  if t.kind == JNull: return ""
  var lines: seq[string]
  var open = "<tweet id=\"" & t{"id"}.getStr & "\" url=\"" & t{"url"}.getStr &
             "\" untrusted>"
  if t.hasKey("retweeted_by"):
    open = open[0 .. ^2] & " reposted_by=\"@" & t["retweeted_by"]["username"].getStr & "\">"
  lines.add open
  lines.add tweetBody(t, false)
  lines.add "</tweet>"
  lines.mapIt(indent & it).join("\n")

proc footer*(nextCursor: string; hasMore: bool; extra = ""): string =
  result = "---\n"
  if extra.len > 0: result &= extra & "\n"
  result &= (if hasMore and nextCursor.len > 0: "next_cursor: " & nextCursor
             else: "next_cursor: none (end of results)")

proc userMd*(u: JsonNode): string =
  var lines = @["<user untrusted>"]
  var head = "**" & fence(u["name"].getStr) & "** @" & u["username"].getStr
  if u["verified"].kind == JString: head &= " ✓(" & u["verified"].getStr & ")"
  if u["protected"].getBool: head &= " [protected]"
  lines.add head
  if u["bio"].getStr.len > 0: lines.add fence(u["bio"].getStr)
  var meta: seq[string]
  if u["location"].getStr.len > 0: meta.add "location: " & fence(u["location"].getStr)
  if u["website"].getStr.len > 0: meta.add "website: " & u["website"].getStr
  if u["joined"].getStr.len > 0: meta.add "joined: " & u["joined"].getStr[0..9]
  if meta.len > 0: lines.add meta.join(" · ")
  let s = u["stats"]
  lines.add "followers " & num(s["followers"].getInt) & " · following " &
    num(s["following"].getInt) & " · tweets " & num(s["tweets"].getInt)
  lines.add "url: " & u["url"].getStr & " · id: " & u["id"].getStr
  if u.hasKey("pinned_tweet_id"): lines.add "pinned_tweet_id: " & u["pinned_tweet_id"].getStr
  if u.hasKey("about"):
    lines.add "about: " & ($u["about"]).replace("\"", "")
  lines.add "</user>"
  lines.join("\n")
