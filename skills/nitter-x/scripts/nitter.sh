#!/usr/bin/env bash
# SPDX-License-Identifier: AGPL-3.0-only
# Shell fallback for the Nitter agent API when no MCP tools are available.
#   nitter.sh <tool> [key=value ...]
#   nitter.sh get_tweet tweet=https://x.com/jack/status/20
#   nitter.sh search_tweets query='nim lang' from=nim_lang since=2025-01-01 limit=10
#   nitter.sh --tools          # list tools and their arguments
# Env: NITTER_BASE_URL (required), NITTER_API_TOKEN (required),
#      NITTER_FORMAT=markdown|json (default markdown), NITTER_TIMEOUT=seconds (default 60)
set -euo pipefail

die() { echo "nitter.sh: $*" >&2; exit 2; }

: "${NITTER_BASE_URL:?set NITTER_BASE_URL, e.g. http://nitter.lan:8080}"
: "${NITTER_API_TOKEN:?set NITTER_API_TOKEN}"
command -v curl >/dev/null || die "curl is required"
base="${NITTER_BASE_URL%/}"
format="${NITTER_FORMAT:-markdown}"
timeout="${NITTER_TIMEOUT:-60}"

# Token goes through a curl config on stdin so it never appears in `ps` output.
curl_auth() { printf 'header = "Authorization: Bearer %s"\n' "$NITTER_API_TOKEN" | curl -K - "$@"; }

[[ $# -ge 1 ]] || die "usage: nitter.sh <tool> [key=value ...] | --tools"

if [[ "$1" == "--tools" ]]; then
  curl_auth -sS --max-time "$timeout" "$base/api/v1/tools"
  echo
  exit 0
fi

tool="$1"; shift
[[ "$tool" =~ ^[a-z_]+$ ]] || die "invalid tool name '$tool'"

# Build the JSON body with a tiny, injection-safe encoder (no eval, no shell interpolation).
json_escape() {
  local s=$1
  s=${s//\\/\\\\}; s=${s//\"/\\\"}; s=${s//$'\n'/\\n}; s=${s//$'\r'/\\r}; s=${s//$'\t'/\\t}
  printf '%s' "$s"
}
body='{'
sep=''
has_format=0
for kv in "$@"; do
  [[ "$kv" == *=* ]] || die "argument '$kv' must look like key=value"
  k=${kv%%=*}; v=${kv#*=}
  [[ "$k" =~ ^[a-z_]+$ ]] || die "invalid argument name '$k'"
  [[ "$k" == "format" ]] && has_format=1
  body+="$sep\"$k\":\"$(json_escape "$v")\""
  sep=','
done
[[ $has_format -eq 1 ]] || { body+="$sep\"format\":\"$(json_escape "$format")\""; }
body+='}'

# The server coerces string values to the declared types ("10" -> 10, "true" -> true).
tmp=$(mktemp); trap 'rm -f "$tmp"' EXIT
code=$(curl_auth -sS --max-time "$timeout" -o "$tmp" -w '%{http_code}' \
  -H 'Content-Type: application/json' -X POST --data-binary "$body" \
  "$base/api/v1/tools/$tool") || die "cannot reach $base"
cat "$tmp"
[[ "$code" == 200 ]] || { echo >&2; echo "nitter.sh: HTTP $code" >&2; exit 1; }
