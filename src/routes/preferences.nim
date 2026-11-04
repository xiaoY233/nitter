# SPDX-License-Identifier: AGPL-3.0-only
import strutils, uri, os, algorithm

import jester

import router_utils
import ".."/[types, formatters]
import ../views/[general, preferences]

export preferences

proc findThemes*(dir: string): seq[string] =
  for kind, path in walkDir(dir / "css" / "themes"):
    let theme = path.splitFile.name
    result.add theme.replace("_", " ").titleize
  sort(result)

proc createPrefRouter*(cfg: Config) =
  router preferences:
    get "/settings":
      let
        prefs = requestPrefs()
        prefsCode = encodePrefs(prefs)
        prefsUrl = getUrlPrefix(cfg) & "/?prefs=" & prefsCode
        html = renderPreferences(prefs, refPath(), findThemes(cfg.staticDir), prefsUrl)
      resp renderMain(html, request, cfg, prefs, "Preferences")

    get "/settings/@i?":
      redirect("/settings")

    post "/saveprefs":
      genUpdatePrefs()
      redirect(refPath())

    post "/setlang":
      # one button that flips between the two shipped languages; the empty
      # value means "the default", so the cookie is expired instead of stored
      if @"language" == "Chinese":
        savePref("language", "Chinese", request)
      else:
        savePref("language", "", request, expire=true)
      redirect(refPath())

    post "/resetprefs":
      genResetPrefs()
      redirect("/settings?referer=" & encodeUrl(refPath()))

    post "/enablehls":
      savePref("hlsPlayback", "on", request)
      redirect(refPath())

    post "/enablemp4":
      savePref("mp4Playback", "on", request)
      redirect(refPath())
