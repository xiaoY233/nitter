# SPDX-License-Identifier: AGPL-3.0-only
import unittest, strutils
import karax/[karaxdsl, vdom]
import ../src/i18n

suite "i18n":
  test "known strings are translated and keep surrounding whitespace":
    check translateString("Home") == "首页"
    check translateString("  Load more ") == "  加载更多 "

  test "unknown strings and content are left alone":
    check translateString("just setting up my twttr") == "just setting up my twttr"
    check translateString("Home sweet home") == "Home sweet home"
    check translateString("") == ""

  test "sentence patterns":
    check translateString("Joined March 2006") == "加入于 2006年3月"
    check translateString("User \"abc\" not found") == "未找到用户“abc”"
    check translateString("jack retweeted") == "jack 转推了"
    check translateString("2,976 Photos and videos") == "2,976 张照片和视频"

  test "tweet content subtrees are never translated":
    let page = buildHtml(tdiv):
      tdiv(class="tweet-content media-body"):
        text "Home"
      tdiv(class="tweet-name-row"):
        a(class="fullname"): text "Search"
      span: text "Home"
    translatePage(page)
    let html = $page
    check html.count("首页") == 1          # only the plain <span>
    check "Search" in html                  # the display name stays English

  test "attributes: title and placeholder are translated, others are not":
    let page = buildHtml(tdiv):
      input(placeholder="Search...", title="Settings", name="Search")
    translatePage(page)
    let html = $page
    check "搜索…" in html
    check "设置" in html
    check "name=\"Search\"" in html
