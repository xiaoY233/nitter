# Web interface

The agent API is the main feature, but the web pages are still there. This
page covers the two things you can change about them: the **X theme** and the
**language**. Both are ordinary preferences, so they are stored in a cookie and
can be set per browser on the settings page (the gear icon).

## The X theme

**X** is the interface of this project, and the only theme shipped. It lays the
web pages out after the X website: a left navigation rail, a 600px content
column and a right-hand column with search.

| Area | What changes |
|---|---|
| Tweets and threads | Compact rows, round avatars, hover colours on the action row, a larger focused tweet. A hovered row gets a rounded background; its radius is the theme's `--x_radius_sm`, so a theme restyles it by changing `--radius`. There are no divider lines between rows: timeline rows, user and list results, replies and the reply-sort strip are told apart by spacing, and a hovered row gets a rounded background. Only a colour band (8px) separates the focused tweet from its replies. Rows stay flush; the card shapes are used in the columns and on the home page |
| Profiles | Banner, round avatar over the banner, one-line stats, a row of media thumbnails, a row of pill tabs whose active tab is filled with the text colour |
| Home | A landing page for the agent side of the instance, as three cards: *Works with* (Claude Code, Codex, Pi, DeepSeek Harness, with their marks, then a short description of the project), *What an agent can do* (the seven tools and the three endpoints) and *Read the pages*. It has no connect commands (they differ per client, see [agent-api.md](agent-api.md)) and no search box. The heading starts on the same line as the logo in the rail and the search box in the right column |
| Search results | Result tabs as pills, user cards, filter chips, a tinted search pill that rings in the primary colour on focus |
| Page shell | Left rail with the menu (icons only on narrower screens, a bottom bar on phones), right column on wide screens. The right column is hidden when it does not fit |
| Colours | White and `#0F1419` ink, cards on `#F7F8F8`, borders `#E1EAEF`, primary `#1E9DF1` used for fills, links `#1170B3` for contrast on white; dark mode switches to `#000`, cards on `#17181C`, borders `#242628`. Taken from the *Twitter* theme by QJ BAO on tweakcn.com (colours only). Language and theme are one menu at the foot of the rail: Language (English, 中文) and Theme (Light, Dark, System), the current choice ticked (see [ui-system.md](ui-system.md)) |
| Settings | One card per group (Display, Media, Link replacements, Bookmark); switches instead of checkboxes, compact rows without divider lines |
| Search | One pill search box (Enter submits, no button inside the box), a filter button that opens the filter chips |
| Right column | A search box and three cards: *Search Tips* (four prefixes, one line each), *Recent Search* (word cloud) and *Agent Cookbook* (the agent endpoints). Cards have a title and content only. The search page drops only the search box (it has its own) |

Shapes: cards use a 24.8px radius, controls 18.8px, chips and pills are fully
round, and text on a primary fill is the ink colour. Sizes, states and the
rules for new work are in [ui-system.md](ui-system.md). Shadows are off.

Notes:

- It is the default. The *Theme* preference is kept so that more themes can be
  added later: drop a stylesheet into `public/css/themes/` and it appears in the
  list. A stored theme whose stylesheet no longer exists falls back to X, so old
  cookies keep working.
- Nitter is read-only. There are no like, follow or compose buttons, and no
  "For you" timeline, notifications or messages.
- The icons are drawn for this project. It does not use the X logo, its icon
  set or its typeface; text uses the system font stack.

### JavaScript enhancements

The pages work without any JavaScript. With the X theme, `/js/xtheme.js` is
loaded by default and adds the features below. Untick *X theme: photo viewer,
keyboard shortcuts and search history* on the settings page to turn it off, or
set `xEnhancements = false` under `[Preferences]` in `nitter.conf` to change the
default for everyone.

| Key | Action |
|---|---|
| `j` / `k` | Select the next / previous post |
| `o` or `Enter` | Open the selected post |
| `/` | Focus the search box |
| `g h`, `g s`, `g p` | Go to home, search, settings |
| `t` | Switch light and dark (remembered in the browser) |
| `?` | Show or hide the shortcut list |
| `←` `→` `Esc` | Browse and close photos |

Clicking a photo opens it in a viewer instead of a new tab. Ctrl, Shift and
Cmd clicks still behave like normal links.

**Recent Search.** The right-hand column shows the words you searched for as a
packed word cloud: larger the more often and the more recently you searched for
them, each in its own colour, some turned on their side. Every word is drawn into
a canvas and placed by its real glyph shape, so small words settle into the gaps
between the big ones; the largest size is found by bisection, which fills the
rounded oval as far as the list allows (up to 60 words). The box is 210px high,
or 150px in windows lower than 880px. Click one to search again, or
*Clear* to forget them all. The list is stored in this browser's `localStorage`
and is never sent to the server. Only post searches count, a reload does not
count twice, and words shorter than two or longer than 60 characters are
ignored.

## Language

The *Language* group of the menu at the foot of the left rail (or *Language* on the
settings page) changes the interface between **English** and **Chinese**.
English is the default.

Only the interface is translated: menus, tabs, settings, buttons, empty states
and common error messages. Tweets, names, bios, link cards and every other piece
of content from X stay as they are. The translation happens on the finished
page, and a string is only replaced when it matches the dictionary exactly. A
string that is not in the dictionary simply stays in English.

To make Chinese the default:

```ini
[Preferences]
language = "Chinese"
```

To add or fix a translation, edit the `dict` table in `src/i18n.nim`. The agent
API, MCP server and `/llms.txt` are not translated.
