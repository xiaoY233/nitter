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
  if c.len > maxCursorLen:
    raise invalidArg("cursor is too long")
  for ch in c:
    if ch < ' ' or ch == '\x7f':
      raise invalidArg("cursor contains control characters")
  c

proc validateDate*(s, name: string): string =
  ## YYYY-MM-DD or empty.
  if s.len == 0: return ""
  let ok = s.len == 10 and s[4] == '-' and s[7] == '-' and
           s[0..3].allCharsInSet(Digits) and s[5..6].allCharsInSet(Digits) and
           s[8..9].allCharsInSet(Digits)
  if not ok:
    raise invalidArg(name & " must be a date formatted YYYY-MM-DD")
  let (m, d) = (parseInt(s[5..6]), parseInt(s[8..9]))
  if m notin 1 .. 12 or d notin 1 .. 31:
    raise invalidArg(name & " is not a valid date")
  s
