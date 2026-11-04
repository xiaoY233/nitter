# SPDX-License-Identifier: AGPL-3.0-only
import os, strformat
import karax/[karaxdsl, vdom]
import markdown

import ../utils

const
  date = staticExec("git show -s --format=\"%cd\" --date=format:\"%Y.%m.%d\"")
  hash = staticExec("git show -s --format=\"%h\"")
  link = repoUrl & "/commit/" & hash
  version = &"{date}-{hash}"

var aboutHtml: string

proc initAboutPage*(dir: string) =
  try:
    aboutHtml = readFile(dir/"md/about.html")
  except IOError:
    # `nimble md` was not run (for example in a custom image build): render
    # the Markdown source now instead of leaving the page empty
    try:
      aboutHtml = markdown(readFile(dir/"md/about.md"))
    except IOError:
      stderr.write (dir/"md/about.md") & " not found\n"
      aboutHtml = "<h1>About page is missing</h1><br><br>"

proc renderAbout*(): VNode =
  buildHtml(tdiv(class="overlay-panel")):
    verbatim aboutHtml
    h2: text "Instance info"
    p:
      text "Version "
      a(href=link): text version
