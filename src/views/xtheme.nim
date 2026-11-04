# SPDX-License-Identifier: AGPL-3.0-only
## Page shell for the "X" theme: a left navigation rail, the content column and
## a right-hand column with search. Only rendered when the theme is "X"; every
## other theme keeps the original top bar (see renderMain in general.nim).
## The icons here are original drawings, not assets of any other service.
import strutils
import karax/[karaxdsl, vdom]

import renderutils
import ../types, ../utils, ../formatters, ../i18n

const
  svgHead* = """<svg class="x-svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">"""
  homeIcon = svgHead & """<path d="M3.5 10.8 12 3.6l8.5 7.2V20a.9.9 0 0 1-.9.9H15v-6h-6v6H4.4a.9.9 0 0 1-.9-.9z"/></svg>"""
  searchIcon* = svgHead & """<circle cx="10.6" cy="10.6" r="6.6"/><path d="m15.6 15.6 5 5"/></svg>"""
  rssIcon = svgHead & """<path d="M4.5 11a8.5 8.5 0 0 1 8.5 8.5M4.5 4.5A15 15 0 0 1 19.5 19.5"/><circle cx="5.6" cy="18.4" r="1.4" fill="currentColor" stroke="none"/></svg>"""
  openIcon = svgHead & """<path d="M14 4h6v6M20 4l-9 9"/><path d="M18 14v4.5a1.5 1.5 0 0 1-1.5 1.5h-11A1.5 1.5 0 0 1 4 18.5v-11A1.5 1.5 0 0 1 5.5 6H10"/></svg>"""
  aboutIcon = svgHead & """<circle cx="12" cy="12" r="9"/><path d="M12 11v5.2"/><circle cx="12" cy="7.8" r=".6" fill="currentColor"/></svg>"""
  # a gear, not a rayed circle: the sun icon sits next to it in the rail
  settingsIcon = svgHead & """<circle cx="12" cy="12" r="3.1"/><path d="M19.2 14.4a1.6 1.6 0 0 0 .3 1.8l.1.1a1.9 1.9 0 1 1-2.7 2.7l-.1-.1a1.6 1.6 0 0 0-1.8-.3 1.6 1.6 0 0 0-1 1.5v.2a1.9 1.9 0 1 1-3.8 0v-.1a1.6 1.6 0 0 0-1-1.5 1.6 1.6 0 0 0-1.8.3l-.1.1a1.9 1.9 0 1 1-2.7-2.7l.1-.1a1.6 1.6 0 0 0 .3-1.8 1.6 1.6 0 0 0-1.5-1H3.3a1.9 1.9 0 1 1 0-3.8h.1a1.6 1.6 0 0 0 1.5-1 1.6 1.6 0 0 0-.3-1.8l-.1-.1a1.9 1.9 0 1 1 2.7-2.7l.1.1a1.6 1.6 0 0 0 1.8.3h.1a1.6 1.6 0 0 0 1-1.5V3.3a1.9 1.9 0 1 1 3.8 0v.1a1.6 1.6 0 0 0 1 1.5 1.6 1.6 0 0 0 1.8-.3l.1-.1a1.9 1.9 0 1 1 2.7 2.7l-.1.1a1.6 1.6 0 0 0-.3 1.8v.1a1.6 1.6 0 0 0 1.5 1h.2a1.9 1.9 0 1 1 0 3.8h-.1a1.6 1.6 0 0 0-1.5 1z"/></svg>"""

const
  filterIcon* = svgHead & """<path d="M4 6.5h16M7 12h10M10 17.5h4"/></svg>"""
  copyIcon* = svgHead & """<rect x="9" y="9" width="11" height="11" rx="2.5"/><path d="M15 5.5A2.5 2.5 0 0 0 12.5 3H6.5A2.5 2.5 0 0 0 4 5.5v6A2.5 2.5 0 0 0 6.5 14"/></svg>"""
  globeIcon* = svgHead & """<circle cx="12" cy="12" r="8.4"/><path d="M3.6 12h16.8M12 3.6c2.2 2.3 3.3 5.2 3.3 8.4s-1.1 6.1-3.3 8.4c-2.2-2.3-3.3-5.2-3.3-8.4s1.1-6.1 3.3-8.4z"/></svg>"""
  errorIcon* = svgHead & """<circle cx="12" cy="12" r="9"/><path d="M12 7.5v5.2"/><circle cx="12" cy="16.4" r=".7" fill="currentColor"/></svg>"""
  sunIcon = svgHead & """<circle cx="12" cy="12" r="4.2"/><path d="M12 2.6v2M12 19.4v2M2.6 12h2M19.4 12h2M5.3 5.3l1.4 1.4M17.3 17.3l1.4 1.4M5.3 18.7l1.4-1.4M17.3 6.7l1.4-1.4"/></svg>"""
  moonIcon = svgHead & """<path d="M20 14.2A8 8 0 0 1 9.8 4a8 8 0 1 0 10.2 10.2z"/></svg>"""
  paletteIcon = svgHead & """<path d="M12 3a9 9 0 1 0 0 18c1.4 0 2-1 1.6-2.1-.5-1.3.4-2.4 1.8-2.4H17a4 4 0 0 0 4-4C21 6.9 17 3 12 3z"/><circle cx="7.6" cy="11.4" r=".9" fill="currentColor" stroke="none"/><circle cx="10.4" cy="7.6" r=".9" fill="currentColor" stroke="none"/><circle cx="15.2" cy="7.9" r=".9" fill="currentColor" stroke="none"/></svg>"""
  contrastIcon = svgHead & """<circle cx="12" cy="12" r="8.4"/><path d="M12 3.6a8.4 8.4 0 0 1 0 16.8z" fill="currentColor"/></svg>"""
  monitorIcon = svgHead & """<rect x="3.5" y="4.5" width="17" height="11.5" rx="2"/><path d="M8.5 20h7M12 16v4"/></svg>"""
  glyphEn = """<span class="x-menu-glyph" aria-hidden="true">A</span>"""
  glyphZh = """<span class="x-menu-glyph" aria-hidden="true">文</span>"""
  checkIcon* = svgHead & """<path d="m5 12.5 4.5 4.5L19 7.5"/></svg>"""
  chevronIcon* = svgHead & """<path d="m6 9.5 6 6 6-6"/></svg>"""
  # the mark: a rounded square holding an "N" whose diagonal ends in a node,
  # a nod to a graph of linked posts
  brandSvg = """<svg class="x-brand-svg" viewBox="190 62 645 645" aria-hidden="true"><path fill="#FF6D70" d="M768.6,253c0.4,5.7,0.4,11.5,0.4,17.2c0,174.7-133,376-376,376c-74.9,0-144.4-21.7-202.9-59.3c10.6,1.2,20.9,1.6,31.9,1.6c61.8,0,118.7-20.9,164.1-56.5c-58.1-1.2-106.8-39.3-123.6-91.7c8.2,1.2,16.4,2,25,2c11.9,0,23.7-1.6,34.8-4.5c-60.6-12.3-106-65.5-106-129.7v-1.6c17.6,9.8,38.1,16,59.7,16.8c-35.6-23.7-58.9-64.2-58.9-110.1c0-24.5,6.5-47.1,18-66.7c65.1,80.2,162.8,132.6,272.5,138.3c-2-9.8-3.3-20-3.3-30.3c0-72.8,58.9-132.2,132.2-132.2c38.1,0,72.4,16,96.6,41.7c29.9-5.7,58.5-16.8,83.9-31.9c-9.8,30.7-30.7,56.5-58.1,72.8c26.6-2.9,52.4-10.2,76.1-20.5C816.9,210.9,794.4,234.2,768.6,253L768.6,253z"/></svg>"""

func isTheme*(theme: string): bool =
  theme.toLowerAscii == "x"

proc navItem(href, label: string; active: bool; icon="", svg="", extra=""): VNode =
  var cls = if active: "x-nav-item active" else: "x-nav-item"
  if extra.len > 0: cls = cls & " " & extra
  buildHtml(a(class=cls, href=href, title=label)):
    if svg.len > 0:
      verbatim svg
    else:
      span(class=("x-nav-icon icon-" & icon))
    span(class="x-nav-label"): text label

proc navItemOff(label, svg: string): VNode =
  buildHtml(span(class="x-nav-item disabled", title=label, `aria-disabled`="true")):
    verbatim svg
    span(class="x-nav-label"): text label

proc menuLabel(icon, label: string): VNode =
  buildHtml(tdiv(class="x-menu-label")):
    verbatim icon
    span: text label

proc menuItem(icon, label, state: string; extra: openArray[(string, string)]): VNode =
  result = buildHtml(button(`type`=(if extra.len > 0 and extra[0][0] == "name": "submit" else: "button"),
                           role="menuitemradio", class="x-menu-item",
                           `aria-checked`=(if state == "on": "true" else: "false"),
                           `data-state`=state)):
    span(class="x-menu-icon"): verbatim icon
    span(class="x-menu-text"): text label
    span(class="x-menu-check"): verbatim checkIcon
  for (k, v) in extra:
    result.setAttr(k, v)

proc navControls(prefs: Prefs; reqPath: string): VNode =
  ## The foot of the left rail, as in the shadcn sidebar blocks: one menu item
  ## that opens a panel upwards, holding two radio groups, "Language" and
  ## "Theme". Every option is spelled out and the current one has a tick.
  ## Language is a plain POST, so it works without JavaScript. The theme group
  ## is shown by public/js/xtheme.js, which also sets the ticks.
  ## <details> gives the open and close behaviour without a script.
  let zh = prefs.language == langZh
  buildHtml(tdiv(class="x-nav-foot")):
    details(class="x-menu"):
      summary(class="x-nav-item x-menu-button", title="Appearance"):
        verbatim paletteIcon
        span(class="x-nav-label"): text "Appearance"
        span(class="x-menu-chevron"): verbatim chevronIcon
      tdiv(class="x-menu-panel", role="menu"):
        form(`method`="post", action="/setlang", class="x-menu-group"):
          hiddenField("referer", reqPath)
          menuLabel(globeIcon, "Language")
          menuItem(glyphEn, "English", (if zh: "off" else: "on"),
                   {"name": "language", "value": "English"})
          menuItem(glyphZh, "中文", (if zh: "on" else: "off"),
                   {"name": "language", "value": "Chinese"})
        tdiv(class="x-menu-sep", hidden="hidden")
        tdiv(class="x-menu-group x-menu-theme", hidden="hidden"):
          menuLabel(contrastIcon, "Theme")
          menuItem(sunIcon, "Light", "off", {"data-scheme": "light"})
          menuItem(moonIcon, "Dark", "off", {"data-scheme": "dark"})
          menuItem(monitorIcon, "System", "off", {"data-scheme": "system"})

proc renderXNav*(cfg: Config; prefs: Prefs; reqPath, rss, canonical,
                 settingsHref: string): VNode =
  let
    onHome = reqPath == "/"
    onSearch = reqPath.startsWith("/search")
  buildHtml(nav(class="x-nav")):
    a(class="x-brand", href="/", title=cfg.title):
      span(class="x-brand-mark"): verbatim brandSvg
      span(class="x-nav-label"): text cfg.title
    navItem("/", "Home", onHome, svg=homeIcon)
    navItem("/search", "Search", onSearch, svg=searchIcon)
    if rss.len > 0:
      navItem(rss, "RSS feed", false, svg=rssIcon, extra="x-nav-rss")
    else:
      # keep the rail the same height on every page; this one has no feed
      navItemOff("RSS feed", rssIcon)
    navItem(canonical, "Open in X", false, svg=openIcon)
    navItem("/about", "About", reqPath == "/about", svg=aboutIcon)
    navItem(settingsHref, "Settings", reqPath.startsWith("/settings"), svg=settingsIcon)
    navControls(prefs, reqPath)

proc renderXAside*(cfg: Config; prefs: Prefs; reqPath, rss, canonical: string): VNode =
  buildHtml(aside(class="x-aside")):
    # the search page has its own search box in the content column
    if not reqPath.startsWith("/search"):
      form(`method`="get", action="/search", class="x-search x-aside-search", autocomplete="off"):
        hiddenField("f", "tweets")
        label(class="x-search-inner"):
          span(class="x-search-icon"): verbatim searchIcon
          input(`type`="text", name="q", placeholder="Search", dir="auto")
        button(`type`="submit", class="x-search-submit", tabindex="-1",
               `aria-hidden`="true"): text "Search"

    tdiv(class="x-aside-card x-aside-tips"):
      tdiv(class="x-card-header"):
        h2: text "Search Tips"
      dl:
        dt: code: text "from:jack"
        dd: text "one account"
        dt: code: text "\"exact phrase\""
        dd: text "exact match"
        dt: code: text "#nim"
        dd: text "hashtag"
        dt: code: text "filter:links"
        dd: text "links & media"

    # the heading and the clear button are rendered here so they are translated
    # like every other label; public/js/xtheme.js fills the list from this
    # browser's own search history
    tdiv(class="x-cloud", hidden="hidden"):
      tdiv(class="x-card-header x-cloud-head"):
        h2: text "Recent Search"
        button(`type`="button", class="x-cloud-clear"): text "Clear"
      tdiv(class="x-cloud-list")

    tdiv(class="x-aside-card"):
      tdiv(class="x-card-header"):
        h2: text "Agent Cookbook"
      ul:
        li:
          a(href="/llms.txt"): code: text "/llms.txt"
          span: text "tools and syntax"
        li:
          a(href="/api/v1/openapi.json"): code: text "/api/v1"
          span: text "REST API"
        li:
          # POST-only endpoint: nothing useful to open in a browser
          code: text "/mcp"
          span: text "MCP server"
        li:
          a(href=(repoUrl & "/tree/master/skills")): code: text "skills/"
          span: text "agent Skills"

    tdiv(class="x-footer"):
      tdiv(class="x-footer-links"):
        a(href="/about"): text "About"
        a(href=repoUrl): text "Source"
        a(href="/llms.txt"): text "API"
        a(href="/settings"): text "Settings"
        if rss.len > 0:
          a(href=rss): text "RSS feed"
      p(class="x-footer-note"): text "X data and tools for AI agents"

const
  agentIcons = [
    ("Claude Code", staticRead("../../public/images/agents/claude-code.svg")),
    ("Codex", staticRead("../../public/images/agents/codex.svg")),
    ("Pi", staticRead("../../public/images/agents/pi.svg")),
    ("DeepSeek Harness", staticRead("../../public/images/agents/deepseek-harness.svg"))]
  homeTools = [
    ("get_user", "profile and counts"),
    ("get_user_timeline", "one account's posts"),
    ("get_tweet", "one post by id or link"),
    ("get_thread", "ancestors and replies"),
    ("search_tweets", "keyword, author and date search"),
    ("search_users", "find accounts"),
    ("get_user_connections", "followers and following")]

proc renderXHome*(cfg: Config; prefs: Prefs; apiEnabled: bool): VNode =
  ## Home page. This server is an AI tool first, so the page says which agents
  ## it works with and what they can do here. It carries no connect commands:
  ## those differ per client and live in docs/agent-api.md.
  buildHtml(tdiv(class="x-home")):
    h1: text cfg.title
    p(class="x-home-lead"):
      text "Public X data for AI agents, with web pages to search, preview and read."

    if apiEnabled:
      tdiv(class="x-card"):
        tdiv(class="x-card-header"):
          h2: text "Works with"
        ul(class="x-agents"):
          for (name, icon) in agentIcons:
            li:
              verbatim icon
              span: text name
        p(class="x-card-note"):
          text "A self-hosted gateway to public X data that reads through your own account sessions, with no official API required. One toolset serves REST, MCP and Skills, returning compact Markdown or JSON with consistent pagination and error codes. The service is strictly read-only, and post text is marked as untrusted content to reduce prompt-injection risk."

      tdiv(class="x-card"):
        tdiv(class="x-card-header"):
          h2: text "What an agent can do"
        dl(class="x-tools"):
          for (name, what) in homeTools:
            dt: code: text name
            dd: text what
        tdiv(class="x-card-foot"):
          a(href="/llms.txt"): code: text "/llms.txt"
          a(href="/api/v1/openapi.json"): code: text "/api/v1"
          code: text "/mcp"
          a(href=(repoUrl & "/tree/master/skills")): code: text "skills/"
    else:
      tdiv(class="x-card"):
        tdiv(class="x-card-header"):
          h2: text "Agent API is off"
        p(class="x-card-note"):
          text "The agent API is switched off on this instance. The operator can enable it with [Api] enabled = true."

    tdiv(class="x-card"):
      tdiv(class="x-card-header"):
        h2: text "Read the pages"
      p(class="x-card-note"):
        text "Profiles, posts, threads and search in the browser, with an RSS feed for every profile, list and search. Theme, language and media preferences are stored in a cookie in your browser. Nothing about visitors is logged."
      tdiv(class="x-card-foot"):
        a(href="/about", class="x-home-link"): text "About this instance"
        a(href="/settings", class="x-home-link"): text "Settings"

proc renderXLayout*(cfg: Config; prefs: Prefs; reqPath, rss, canonical, settingsHref: string;
                    content: VNode): VNode =
  buildHtml(tdiv(class="x-layout")):
    renderXNav(cfg, prefs, reqPath, rss, canonical, settingsHref)
    tdiv(class="container"):
      content
    renderXAside(cfg, prefs, reqPath, rss, canonical)
