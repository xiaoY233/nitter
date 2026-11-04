# SPDX-License-Identifier: AGPL-3.0-only
## Interface translation (English -> Chinese).
##
## Views keep their English strings. When the "Language" preference is Chinese,
## renderMain walks the finished page tree once and replaces whole strings that
## exactly match an entry below. Tweet text, names, bios, cards and other
## content from X are never touched: their subtrees are skipped, and only exact
## matches (plus a few fixed sentence patterns) are translated.
import strutils, tables
import karax/vdom

const
  langZh* = "Chinese"

  dict = {
    # navigation and titles
    "Home": "首页", "Search": "搜索", "RSS Feed": "RSS 订阅", "RSS feed": "RSS 订阅",
    "Open in X": "在 X 中打开", "Open this page in X": "在 X 中打开此页",
    "About": "关于", "Preferences": "偏好设置", "Settings": "设置", "Error": "错误",
    "Chinese": "中文", "English": "English",
    "Light": "浅色", "Dark": "深色", "System": "跟随系统", "Appearance": "外观设置",

    # search
    "Top": "热门", "Latest": "最新", "Media": "媒体", "Users": "用户", "Lists": "列表",
    "Filter": "包含", "Exclude": "排除", "Time range": "时间范围",
    "Minimum likes": "最少点赞数", "Retweets": "转推", "Videos": "视频",
    "News": "新闻", "Native videos": "原生视频", "Replies": "回复", "Links": "链接",
    "Images": "图片", "Quotes": "引用", "Spaces": "空间",
    "Enter search...": "输入搜索内容…", "Enter username...": "输入用户名…",
    "Number...": "数字…", "Search...": "搜索…",

    # timelines and profiles
    "Load newest": "加载最新", "Load more": "加载更多",
    "No more items": "没有更多内容", "No items found": "未找到内容",
    "Type a name or username above to find accounts.": "在上方输入名称或用户名来查找账号。",
    "Type a word above to find lists.": "在上方输入关键词来查找列表。",
    "Type a word, phrase or hashtag above to find posts.": "在上方输入关键词、短语或话题标签来查找帖子。",
    "posts by an account": "某个账号发布的帖子",
    "posts containing the phrase": "包含该短语的帖子",
    "posts with a hashtag": "带有该话题标签的帖子",
    "Public X data for AI agents, with web pages to search, preview and read.":
      "面向 AI Agent 的 X 公开数据查询，提供可搜索、预览和阅读的 Web 页面。",
    "Connect an agent": "连接 Agent",
    "tools for agents": "个 Agent 工具", "one set of calls": "同一套调用",
    "for coding agents": "给编码 Agent", "Markdown": "Markdown",
    "or JSON output": "或 JSON 输出",
    "Seven tools over one set of calls: profiles, timelines, single posts, threads, post search, account search, followers. Responses are compact Markdown by default, JSON on request.":
      "七个工具共用同一套调用：资料、时间线、单条帖子、会话串、帖子搜索、账号搜索、关注者。默认返回精简的 Markdown，也可以要求 JSON。",
    "REST API; the OpenAPI document is at /api/v1/openapi.json":
      "REST API；OpenAPI 文档见 /api/v1/openapi.json",
    "Plain-text guide to the tools and search syntax": "工具和搜索语法的纯文本说明",
    "Requests need a bearer token from the operator of this instance. Post text is fenced as untrusted data, so instructions inside a post are not followed.":
      "请求需要携带此实例管理员发放的 Bearer 令牌。帖子正文会被标记为不可信数据，其中的指令不会被执行。",
    "Profiles, posts, threads and search in the browser, with an RSS feed for every profile, list and search.":
      "在浏览器里查看资料、帖子、会话串和搜索，每个资料页、列表和搜索都有 RSS 订阅。",
    "Theme, language and media preferences are stored in a cookie in your browser. Nothing about visitors is logged.":
      "主题、语言和媒体偏好保存在浏览器的 Cookie 里，不会记录访客信息。",
    "Read the pages": "浏览网页版",
    "About this instance": "关于这个实例",
    "tools and syntax": "工具与语法",
    "posts by one account": "某个账号发布的帖子",
    "posts containing the phrase": "包含该短语的帖子",
    "posts with a hashtag": "带有该话题标签的帖子",
    "posts with links or media": "包含链接或媒体的帖子",
    "Switch language": "切换语言", "Switch light and dark": "切换浅色和深色",
    "MCP server (Streamable HTTP)": "MCP 服务（Streamable HTTP）",
    "Requests need a bearer token from the operator of this instance.":
      "请求需要携带此实例管理员发放的 Bearer 令牌。",
    "The agent API is switched off on this instance. The operator can enable it with [Api] enabled = true.":
      "此实例未开启 Agent API。管理员可在配置中设置 [Api] enabled = true 来开启。",
    "Works with": "适用于", "What an agent can do": "Agent 能做什么",
    "Agent API is off": "Agent API 未开启",
    "A self-hosted gateway to public X data that reads through your own account sessions, with no official API required. One toolset serves REST, MCP and Skills, returning compact Markdown or JSON with consistent pagination and error codes. The service is strictly read-only, and post text is marked as untrusted content to reduce prompt-injection risk.":
      "自托管的 X 公开数据网关，通过自有账号会话读取，无需官方 API。同一套工具提供 REST、MCP 与 Skills 三种接入方式，返回精简的 Markdown 或 JSON，分页与错误码保持一致。服务严格只读，帖子正文标注为不可信内容，以降低提示注入风险。",
    "Profiles, posts, threads and search in the browser, with an RSS feed for every profile, list and search. Theme, language and media preferences are stored in a cookie in your browser. Nothing about visitors is logged.":
      "在浏览器中查看资料、帖子、对话串和搜索，每个资料、列表和搜索都有 RSS。主题、语言和媒体偏好保存在浏览器的 cookie 中，不记录任何访客信息。",
    "profile and counts": "资料与数据", "one account's posts": "某个账号的帖子",
    "one post by id or link": "按 ID 或链接取一条帖子", "ancestors and replies": "上文与回复",
    "keyword, author and date search": "按关键词、作者、日期搜索", "find accounts": "查找账号",
    "followers and following": "粉丝与关注",
    "Find accounts": "查找账号", "Find lists": "查找列表", "Find pictures and videos": "查找图片和视频",
    "Search posts": "搜索帖子", "Type a name or username above.": "在上方输入名称或用户名。",
    "Type a word above.": "在上方输入关键词。", "Type a word, phrase or hashtag above.": "在上方输入关键词、短语或话题标签。",
    "Search Tips": "搜索技巧", "one account": "指定账号", "exact match": "精确匹配",
    "hashtag": "话题标签", "links & media": "链接和媒体",
    "posts carrying a hashtag": "带有该话题标签的帖子",
    "posts that contain links or media": "包含链接或媒体的帖子",
    "Agent Cookbook": "Agent 手册", "tool guide": "工具说明",
    "REST API": "REST API", "MCP server": "MCP 服务", "agent Skills": "Agent Skills",
    "Back to home": "返回首页", "Light / Dark": "浅色 / 深色",
    "Switch light and dark": "切换浅色和深色", "Filters": "筛选",
    "Recent Search": "最近搜索", "Clear": "清除", "Source": "源码", "API": "API",
    "X data and tools for AI agents": "面向 AI Agent 的 X 数据与工具",
    "Enter a search before subscribing to its RSS feed.": "请先输入搜索内容，再订阅它的 RSS。",
    "Timeline": "时间线", "Grid": "网格", "Gallery": "画廊",
    "Tweets": "推文", "Tweets & Replies": "推文和回复", "Articles": "文章",
    "Following": "正在关注", "Followers": "关注者", "Likes": "喜欢",
    "Members": "成员", "This account's tweets are protected.": "该账号的推文受保护。",
    "Protected account": "受保护的账号", "Verified account": "已认证账号",

    # tweets and threads
    "Pinned Tweet": "置顶推文", "Pinned by Community mods": "社区管理员置顶",
    "Replying to": "回复", "Article": "文章", "Show this thread": "查看完整对话",
    "Community note": "社区笔记", "This tweet is unavailable": "此推文不可用",
    "There's a new version of this post.": "此帖有新版本。",
    "There's a new version of this post": "此帖有新版本",
    "See the latest post": "查看最新版本", "Latest post": "最新版本",
    "Version history": "版本历史", "Related tweets": "相关推文",
    "earlier replies": "更早的回复", "more replies": "更多回复",
    "Sort replies:": "回复排序：", "Relevant": "相关", "Recent": "最新", "Liked": "最多喜欢",
    "Made with AI": "由 AI 生成", "Paid partnership (ad)": "付费合作（广告）",
    "Download video": "下载视频",
    "Enable mp4 playback": "启用 mp4 播放", "Enable hls playback": "启用 hls 播放",
    "This media is unavailable": "此媒体不可用",
    "This media has been disabled in response to a report by the copyright owner":
      "应版权所有者的举报，此媒体已被禁用",
    "Audio stream unavailable": "音频流不可用", "Replay is not available": "无法回放",
    "Stream unavailable": "直播流不可用", "Broadcast not found": "未找到直播",

    # account info and communities
    "Date joined": "加入时间", "Account based in": "账号所在地", "Verified": "已认证",
    "ID Verified": "身份已验证", "Yes": "是", "An affiliate of": "隶属于",
    "Connected via": "连接来源",
    "Community Info": "社区信息", "Anyone can join this Community.": "任何人都可以加入此社区。",
    "Membership is by approval only.": "加入需要审批。",
    "All Communities are publicly visible.": "所有社区都公开可见。",
    "Rules": "规则", "Moderators": "管理员", "See all": "查看全部",
    "These are set and enforced by Community admins and are in addition to ":
      "这些规则由社区管理员制定并执行，是对以下规则的补充：",
    "X's rules": "X 的规则",
    "Instance info": "实例信息", "Version": "版本",
    "Unsupported feature": "暂不支持的功能",
    "Nitter doesn't support this feature yet, but it might in the future.":
      "Nitter 暂不支持此功能，将来可能会支持。",

    # preferences page
    "Display": "显示", "Link replacements (blank to disable)": "链接替换（留空则不替换）",
    "Theme": "主题", "Language": "语言（Language）",
    "Infinite scrolling (experimental, requires JavaScript)": "无限滚动（实验性，需要 JavaScript）",
    "X theme: photo viewer, keyboard shortcuts and search history (requires JavaScript)":
      "X 主题：图片查看器、键盘快捷键和搜索记录（需要 JavaScript）",
    "Make profile sidebar stick to top": "资料侧栏固定在顶部",
    "Keep navbar fixed to top": "导航栏固定在顶部",
    "Support bidirectional text (makes clicking on tweets harder)": "支持双向文字（会让点击推文更困难）",
    "Hide tweet stats (replies, retweets, likes)": "隐藏推文数据（回复、转推、喜欢）",
    "Hide profile banner": "隐藏个人主页横幅", "Hide pinned tweets": "隐藏置顶推文",
    "Hide tweet replies": "隐藏推文回复", "Hide related tweets under replies": "隐藏回复下方的相关推文",
    "Hide community notes": "隐藏社区笔记", "Square profile pictures": "方形头像",
    "Enable mp4 video playback (only for gifs)": "启用 mp4 视频播放（仅限 GIF）",
    "Enable HLS video streaming (requires JavaScript)": "启用 HLS 视频流（需要 JavaScript）",
    "Proxy video streaming through the server (might be slow)": "通过服务器代理视频流（可能较慢）",
    "Mute videos by default": "默认静音视频", "Autoplay gifs": "自动播放 GIF",
    "Compact media gallery (no profile info or text)": "紧凑媒体画廊（不显示资料和文字）",
    "Gallery column size": "画廊列宽", "Default media view": "默认媒体视图",
    "Small": "小", "Medium": "中", "Large": "大",
    "Twitter → Nitter": "Twitter → Nitter", "YouTube → Piped/Invidious": "YouTube → Piped/Invidious",
    "Reddit → Teddit/Libreddit": "Reddit → Teddit/Libreddit",
    "Nitter hostname": "Nitter 主机名", "Piped hostname": "Piped 主机名", "Teddit hostname": "Teddit 主机名",
    "Bookmark": "书签",
    "Save this URL to restore your preferences (?prefs works on all pages)":
      "保存此链接即可恢复你的偏好设置（?prefs 参数适用于所有页面）",
    "Preferences are stored client-side using cookies without any personal information.":
      "偏好设置通过 Cookie 保存在你的浏览器中，不包含任何个人信息。",
    "You can override preferences with query parameters (e.g. <code>?hlsPlayback=on</code>). These overrides aren't saved to cookies, and links won't retain the parameters. Intended for configuring RSS feeds and other cookieless environments. Hover over a preference to see its name.":
      "你可以通过查询参数临时覆盖偏好设置（例如 <code>?hlsPlayback=on</code>）。这些覆盖不会保存到 Cookie，链接也不会保留这些参数，主要用于配置 RSS 订阅等无 Cookie 的环境。把鼠标悬停在某个设置上可以看到它的参数名。",
    "Save preferences": "保存设置", "Reset preferences": "重置设置",

    # errors
    "Tweet not found": "未找到推文", "User not found": "未找到用户",
    "Invalid search": "无效的搜索", "Search input too long.": "搜索内容过长。",
    "Invalid tweet ID": "无效的推文 ID", "Article not found": "未找到文章",
    "Space not found": "未找到空间", "Tweet history not found": "未找到推文历史",
    "Missing screen_name parameter": "缺少 screen_name 参数",
    "Only Tweet searches are allowed for RSS feeds.": "RSS 订阅只支持推文搜索。",
    "RSS feed is disabled": "RSS 订阅已禁用",
    "No video in tweet": "推文中没有视频",
  }.toTable

  # (prefix, suffix, template) with "{}" standing for the text in between
  patterns = [
    ("Only confirmed followers have access to ", "'s tweets.", "只有已确认的关注者才能查看 {} 的推文。"),
    ("User \"", "\" not found", "未找到用户“{}”"),
    ("User \"", "\" has been suspended", "用户“{}”已被封禁"),
    ("List \"", "\" not found", "未找到列表“{}”"),
    ("Community \"", "\" not found", "未找到社区“{}”"),
    ("Verified ", " account", "已认证账号（{}）"),
    ("Last edited ", "", "最后编辑于 {}"),
    ("Joined ", "", "加入于 {}"),
    ("Based in ", "", "所在地：{}"),
    ("Since ", "", "自 {}"),
    ("Last on ", "", "最近一次：{}"),
    ("Created ", " by", "创建于 {}，创建者"),
    ("Version ", "", "版本 {}"),
    ("", " retweeted", "{} 转推了"),
    ("", " Photos and videos", "{} 张照片和视频"),
    ("", " Members", "{} 位成员"),
    ("", " username change", "更改过 {} 次用户名"),
    ("", " username changes", "更改过 {} 次用户名"),
  ]

  months = ["January", "February", "March", "April", "May", "June", "July",
            "August", "September", "October", "November", "December"]

  # classes whose subtrees hold content from X (never translated)
  skipClasses = ["tweet-content", "quote-text", "fullname", "username",
                 "profile-bio", "profile-card-fullname", "profile-card-username",
                 "card-title", "card-description", "card-content",
                 "community-note-text", "article-", "timeline-description",
                 "community-description", "community-name", "community-rule-content",
                 "community-mod-name", "alt-text", "poll-meter-label",
                 "list-result", "tweet-name"]

  translatedAttrs = ["title", "placeholder", "alt"]

proc monthYear(s: string): string =
  ## "March 2006" -> "2006年3月"
  let parts = s.split(' ')
  if parts.len != 2 or parts[1].len != 4 or not parts[1].allCharsInSet(Digits):
    return ""
  for i, m in months:
    if m == parts[0]: return parts[1] & "年" & $(i + 1) & "月"

proc translateString*(s: string): string =
  ## Translates `s` when it is a known UI string, otherwise returns it as is.
  let st = s.strip()
  if st.len == 0: return s
  let
    lead = s[0 ..< s.len - s.strip(trailing=false).len]
    trail = s[s.strip(leading=false).len .. ^1]

  var res = ""
  if st in dict:
    res = dict[st]
  else:
    res = monthYear(st)
    if res.len == 0:
      for (pre, suf, tmpl) in patterns:
        if st.len > pre.len + suf.len and st.startsWith(pre) and st.endsWith(suf):
          let mid = st[pre.len ..< st.len - suf.len]
          res = tmpl.replace("{}", translateString(mid))
          break
  if res.len == 0: s else: lead & res & trail

proc isContent(n: VNode): bool =
  var cls = $n.class
  if cls.len == 0: cls = $n.getAttr("class")
  if cls.len == 0: return false
  for c in skipClasses:
    if c in cls: return true

proc walk(n: VNode) =
  if n.isNil: return
  case n.kind
  of VNodeKind.text, VNodeKind.verbatim:
    n.text = translateString($n.text)
    return
  else: discard

  if n.isContent: return

  var changes: seq[(string, string)]
  for k, v in n.attrs:
    if $k in translatedAttrs:
      let t = translateString($v)
      if t != $v: changes.add (k, t)
  for (k, v) in changes: n.setAttr(k, v)

  for i in 0 ..< n.len: walk(n[i])

proc translatePage*(root: VNode) =
  walk(root)
