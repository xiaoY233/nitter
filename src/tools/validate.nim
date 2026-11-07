# SPDX-License-Identifier: AGPL-3.0-only
## Input validation / normalisation. Pure functions, no network access: URLs are
## only ever *parsed* to extract identifiers, never fetched.
import strutils, uri, sequtils
import errors

const
  reservedNames = ["i", "home", "search", "explore", "intent", "hashtag", "settings",
                   "login", "about", "pic", "share", "notifications", "messages"]
  maxCursorLen* = 2000
  maxQueryLen* = 500
  maxFromHandles* = 10

proc isUsername*(s: string): bool =
  s.len in 1 .. 15 and s.allCharsInSet({'a'..'z', 'A'..'Z', '0'..'9', '_'})

proc pathSegments(s: string): seq[string] =
  let u = parseUri(s)
  u.path.split('/').filterIt(it.len > 0)

proc looksLikeUrl(s: string): bool =
  "://" in s or s.toLowerAscii.startsWith("x.com/") or
    s.toLowerAscii.startsWith("twitter.com/") or s.toLowerAscii.startsWith("www.")

proc normalizeUsername*(raw: string): string =
  ## Accepts "jack", "@jack" or a profile/status URL and returns the bare name.
  var s = raw.strip()
  if s.len == 0:
    raise invalidArg("username must not be empty")
  if s.looksLikeUrl:
    if "://" notin s: s = "https://" & s
    let segs = pathSegments(s)
    if segs.len == 0:
      raise invalidArg("Could not find a username in URL '" & raw & "'")
    s = segs[0]
  s.removePrefix('@')
  if not s.isUsername or s.toLowerAscii in reservedNames:
    raise invalidArg("'" & raw & "' is not a valid username " &
                     "(1-15 letters, digits or underscores)")
  s

proc isTweetId*(s: string): bool =
  s.len in 1 .. 19 and s.allCharsInSet({'0'..'9'})

proc parseTweetRef*(raw: string): string =
  ## Accepts a numeric id or any tweet URL (x.com, twitter.com, nitter instances,
  ## /i/web/status/ID, ...) and returns the numeric id as a string.
  let s = raw.strip()
  if s.isTweetId:
    return s
  if s.looksLikeUrl or "/status/" in s or "/statuses/" in s:
    let url = if "://" in s: s else: "https://" & s
    let segs = pathSegments(url)
    for i, seg in segs:
      if seg in ["status", "statuses"] and i + 1 < segs.len and segs[i + 1].isTweetId:
        return segs[i + 1]
  raise invalidArg("'" & raw & "' is neither a numeric tweet id nor a tweet URL " &
                   "like https://x.com/<user>/status/<id>")

proc validateCursor*(c: string): string =
  ## Cursors are opaque tokens the upstream hands out: base64url text, a
  ## `maxid:<n>` marker (our own date-bounded search paging) or `<id>|<n>`
  ## (follower lists). A value with anything else in it was not issued by this
  ## server, and the upstream answers one with an empty page that looks exactly
  ## like the end of the results, so it is refused here.
  if c.len > maxCursorLen:
    raise invalidArg("cursor is too long")
  for ch in c:
    if ch < ' ' or ch == '\x7f':
      raise invalidArg("cursor contains control characters")
    if ch notin {'a'..'z', 'A'..'Z', '0'..'9', '_', '-', '=', '|', ':', '+', '/'}:
      raise invalidArg("cursor is not valid: pass back the next_cursor value " &
                       "from a previous response unchanged")
  c

proc daysInMonth(y, m: int): int =
  case m
  of 2: (if (y mod 4 == 0 and y mod 100 != 0) or y mod 400 == 0: 29 else: 28)
  of 4, 6, 9, 11: 30
  else: 31

proc validateDate*(s, name: string): string =
  ## YYYY-MM-DD or empty. The day is checked against the real calendar: X
  ## answers an impossible date such as 2024-02-31 with an empty result.
  if s.len == 0: return ""
  let ok = s.len == 10 and s[4] == '-' and s[7] == '-' and
           s[0..3].allCharsInSet(Digits) and s[5..6].allCharsInSet(Digits) and
           s[8..9].allCharsInSet(Digits)
  if not ok:
    raise invalidArg(name & " must be a date formatted YYYY-MM-DD")
  let (y, m, d) = (parseInt(s[0..3]), parseInt(s[5..6]), parseInt(s[8..9]))
  if m notin 1 .. 12 or d notin 1 .. daysInMonth(y, m):
    raise invalidArg(name & " is not a valid date")
  s

proc validateDateRange*(since, until: string) =
  ## Both are already validated YYYY-MM-DD, so string order is date order.
  if since.len > 0 and until.len > 0 and since >= until:
    raise invalidArg("since (" & since & ") must be earlier than until (" & until &
                     "); until is exclusive")

proc validateMinLikes*(s: string): string =
  ## A non-numeric value used to be dropped silently, which widened the search.
  if s.len > 0 and not s.allCharsInSet(Digits):
    raise invalidArg("min_likes must be a whole number of 0 or more")
  s
