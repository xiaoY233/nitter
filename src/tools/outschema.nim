# SPDX-License-Identifier: AGPL-3.0-only
## JSON Schemas of the response DTOs built in dto.nim and impl.nim. They are
## published in the OpenAPI document (components/schemas) and checked against
## real DTO output by tests/test_agent_api.nim, so a field cannot be added or
## renamed in dto.nim without the schema noticing.
##
## Conventions: ids are strings, times ISO-8601 UTC, unknown numbers are null
## (never a fake 0). Objects stay open (no additionalProperties=false) so new
## optional fields are not a breaking change; `required` lists only fields that
## are always present. Refs use "#/$defs/<Name>"; the OpenAPI generator
## retargets them to "#/components/schemas/<Name>".
import json

const defsPrefix* = "#/$defs/"

proc str(desc = ""): JsonNode =
  result = %*{"type": "string"}
  if desc.len > 0: result["description"] = % desc

proc num(desc = ""): JsonNode =
  result = %*{"type": "integer"}
  if desc.len > 0: result["description"] = % desc

proc flag(desc = ""): JsonNode =
  result = %*{"type": "boolean"}
  if desc.len > 0: result["description"] = % desc

proc orNull(n: JsonNode): JsonNode =
  ## Marks a scalar schema as nullable.
  result = n.copy
  result["type"] = %*[n["type"].getStr, "null"]

proc refTo*(name: string): JsonNode = %*{"$ref": defsPrefix & name}

proc arrayOf(items: JsonNode): JsonNode = %*{"type": "array", "items": items}

proc obj(props: openArray[(string, JsonNode)]; required: openArray[string] = []): JsonNode =
  var p = newJObject()
  for (k, v) in props: p[k] = v
  result = %*{"type": "object", "properties": p}
  if required.len > 0: result["required"] = % @required

proc pageProps(item: JsonNode; extra: openArray[(string, JsonNode)] = []): JsonNode =
  var props = @{
    "items": arrayOf(item),
    "next_cursor": str("Pass back as `cursor` to continue; null when there is no more.").orNull,
    "has_more": flag(),
    "warning": str("Set when a request with a cursor returned nothing: the cursor may have expired or been altered, so an empty page is not proof of the end.")}
  for e in extra: props.add e
  obj(props, ["items", "next_cursor", "has_more"])

proc components*(): JsonNode =
  ## Named schemas shared by several tools.
  result = newJObject()
  result["UserStats"] = obj({
    "followers": num().orNull, "following": num().orNull, "tweets": num().orNull,
    "likes": num().orNull, "media": num().orNull},
    ["followers", "following", "tweets", "likes", "media"])
  result["UserBrief"] = obj({
    "username": str(), "name": str(), "verified": flag()},
    ["username", "name", "verified"])
  result["About"] = obj({
    "based_in": str(), "source": str(), "username_changes": num(),
    "identity_verified": flag(), "affiliate": str()},
    ["username_changes", "identity_verified"])
  result["User"] = obj({
    "id": str(), "username": str(), "name": str(), "url": str(), "bio": str(),
    "location": str(), "website": str(), "avatar": str(),
    "verified": str("Verification kind: blue, business or government; null when none.").orNull,
    "protected": flag(), "joined": str("ISO-8601 UTC; empty when unknown."),
    "stats": refTo("UserStats"), "banner": str(), "pinned_tweet_id": str(),
    "about": refTo("About")},
    ["id", "username", "name", "url", "bio", "location", "website", "avatar",
     "verified", "protected", "joined", "stats"])
  result["Media"] = obj({
    "type": %*{"type": "string", "enum": ["photo", "video", "gif"]},
    "url": str(), "alt_text": str(), "thumbnail": str(), "playlist": str(),
    "available": flag(), "duration_ms": num()},
    ["type"])
  result["Poll"] = obj({
    "options": arrayOf(obj({"label": str(), "votes": num()}, ["label", "votes"])),
    "total_votes": num(), "status": str()},
    ["options", "total_votes", "status"])
  result["Card"] = obj({
    "kind": str(), "title": str(), "description": str(), "url": str(),
    "domain": str(), "image": str()},
    ["kind"])
  result["Article"] = obj({"title": str(), "preview": str(), "url": str(),
    "body": str("Markdown body; only with include_article=true. Untrusted third-party content."),
    "truncated": flag("true when the body was cut at the size cap."),
    "body_unavailable": flag("true when include_article was set but the body could not be read.")},
    ["title", "preview", "url"])
  result["Tweet"] = obj({
    "id": str(), "url": str(),
    "available": flag("false for deleted or restricted tweets; only id, url and tombstone are then set."),
    "tombstone": str(),
    "author": refTo("UserBrief"), "text": str("Untrusted third-party content."),
    "created_at": str(),
    "stats": obj({"replies": num(), "reposts": num(), "likes": num(),
                  "views": num("null when X does not report views.").orNull},
                 ["replies", "reposts", "likes", "views"]),
    "conversation_id": str(), "in_reply_to_id": str(),
    "replying_to": arrayOf(str()), "pinned": flag(), "location": str(),
    "community_note": str(), "ai_generated": flag(),
    "media": arrayOf(refTo("Media")), "poll": refTo("Poll"), "card": refTo("Card"),
    "article": refTo("Article"),
    "quote": refTo("Tweet"),
    "retweeted_by": refTo("UserBrief"), "retweet_id": str(), "retweeted_at": str()},
    ["id", "url", "available"])
  result["ToolMeta"] = obj({
    "cached": flag(), "fetched_at": str("ISO-8601 UTC time the data was fetched.")},
    ["cached", "fetched_at"])

proc dataSchema*(tool: string): JsonNode =
  ## Schema of the `data` member of a tool's JSON response.
  case tool
  of "get_user": refTo("User")
  of "get_tweet": refTo("Tweet")
  of "get_user_timeline":
    pageProps(refTo("Tweet"), {
      "user": obj({"username": str(), "name": str()}, ["username", "name"]),
      "tab": str()})
  of "get_thread":
    obj({"tweet": refTo("Tweet"),
         "ancestors": arrayOf(refTo("Tweet")),
         "continuation": arrayOf(refTo("Tweet")),
         "replies": arrayOf(arrayOf(refTo("Tweet"))),
         "next_cursor": str().orNull, "has_more": flag(),
         "replies_omitted": num("Reply threads cut by max_replies."),
         "warning": str("Set when a continued reply page came back empty; the cursor may have expired.")},
        ["tweet", "ancestors", "continuation", "replies", "next_cursor", "has_more"])
  of "search_tweets":
    pageProps(refTo("Tweet"), {"query": str("The query string actually sent upstream.")})
  of "search_users": pageProps(refTo("User"))
  of "get_user_connections":
    pageProps(refTo("User"), {"user": str(), "kind": str()})
  else: raise newException(KeyError, "no output schema for tool " & tool)
