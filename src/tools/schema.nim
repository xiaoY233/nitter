# SPDX-License-Identifier: AGPL-3.0-only
## Tiny JSON-Schema helper: builds schemas and validates + coerces arguments.
## Supported keywords: type (string/integer/boolean), enum, minimum, maximum,
## maxLength, default, required, additionalProperties=false.
import json, strutils
import errors

proc strProp*(desc: string; maxLen = 0; values: openArray[string] = []; default = ""): JsonNode =
  result = %*{"type": "string", "description": desc}
  if maxLen > 0: result["maxLength"] = % maxLen
  if values.len > 0:
    result["enum"] = % @values
  if default.len > 0: result["default"] = % default

proc intProp*(desc: string; minimum, maximum: int; default: int): JsonNode =
  %*{"type": "integer", "description": desc, "minimum": minimum,
     "maximum": maximum, "default": default}

proc boolProp*(desc: string; default: bool): JsonNode =
  %*{"type": "boolean", "description": desc, "default": default}

proc objectSchema*(props: openArray[(string, JsonNode)];
                   required: openArray[string] = []): JsonNode =
  ## Every tool also accepts `format`, injected here so it is declared once.
  var p = newJObject()
  for (k, v) in props: p[k] = v
  p["format"] = strProp(
    "Response rendering: 'markdown' is compact and cheap in tokens, " &
    "'json' is the full structured payload.", values = ["markdown", "json"])
  result = %*{"type": "object", "properties": p, "additionalProperties": false}
  if required.len > 0:
    result["required"] = % @required

proc parseBoolLoose(s: string; name: string): bool =
  case s.toLowerAscii
  of "true", "1", "yes", "on": true
  of "false", "0", "no", "off": false
  else: raise invalidArg(name & " must be a boolean (true or false)")

proc validateArgs*(schema, args: JsonNode): JsonNode =
  ## Returns a new object holding only declared properties, coerced to their
  ## declared type with defaults applied. Raises ToolError (invalid_argument).
  if args.isNil or args.kind == JNull:
    return validateArgs(schema, newJObject())
  if args.kind != JObject:
    raise invalidArg("arguments must be a JSON object")

  let props = schema["properties"]
  result = newJObject()

  for key in args.keys:
    if key notin props:
      var known: seq[string]
      for k in props.keys: known.add k
      raise invalidArg("Unknown argument '" & key & "'. Valid arguments: " & known.join(", "))

  for name, spec in props:
    let typ = spec{"type"}.getStr
    var v = args{name}
    # REST query strings deliver "" for absent values.
    if not v.isNil and v.kind == JString and v.getStr.len == 0 and typ != "string":
      v = nil
    if not v.isNil and v.kind == JNull: v = nil
    if not v.isNil and v.kind == JString and v.getStr.len == 0 and "default" in spec and
       typ == "string":
      v = nil

    if v.isNil:
      if "default" in spec: result[name] = spec["default"]
      continue

    case typ
    of "string":
      var s: string
      case v.kind
      of JString: s = v.getStr
      of JInt: s = $v.getBiggestInt   # ids passed as numbers
      else: raise invalidArg(name & " must be a string")
      s = s.strip()
      if "maxLength" in spec and s.len > spec["maxLength"].getInt:
        raise invalidArg(name & " is too long (max " & $spec["maxLength"].getInt & " characters)")
      if "enum" in spec:
        let low = s.toLowerAscii
        var ok = false
        var allowed: seq[string]
        for e in spec["enum"]:
          allowed.add e.getStr
          if e.getStr == low: ok = true
        if not ok:
          raise invalidArg(name & " must be one of: " & allowed.join(", "))
        s = low
      result[name] = % s
    of "integer":
      var n: int
      case v.kind
      of JInt: n = v.getInt
      of JString:
        try: n = parseInt(v.getStr.strip())
        except ValueError: raise invalidArg(name & " must be an integer")
      else: raise invalidArg(name & " must be an integer")
      let (lo, hi) = (spec{"minimum"}.getInt(low(int)), spec{"maximum"}.getInt(high(int)))
      if n < lo or n > hi:
        raise invalidArg(name & " must be between " & $lo & " and " & $hi)
      result[name] = % n
    of "boolean":
      case v.kind
      of JBool: result[name] = v
      of JString: result[name] = % parseBoolLoose(v.getStr, name)
      else: raise invalidArg(name & " must be a boolean")
    else:
      result[name] = v

  if "required" in schema:
    for r in schema["required"]:
      if r.getStr notin result or (result[r.getStr].kind == JString and
                                   result[r.getStr].getStr.len == 0):
        raise invalidArg("Missing required argument '" & r.getStr & "'")
