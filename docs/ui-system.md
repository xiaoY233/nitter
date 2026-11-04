# UI system for the X theme

This page is the design spec for `body.theme-x`. New and reworked components
follow it; existing ones are moved over one at a time (see the status column).

The numbers come from the **shadcn/ui** `new-york-v4` component sources
(`button`, `input`, `select`, `switch`, `badge`, `kbd`, `card`, `tabs`,
`sidebar`) combined with the **tweakcn "Twitter"** theme tokens (by QJ BAO).
Only sizes, states and structure are reused. No shadcn or tweakcn code, icon
or font is shipped, and no library is installed. The implementation is
[`src/sass/x/_ui.scss`](../src/sass/x/_ui.scss): one mixin per component, used
by the page stylesheets, so a value lives in one place.

## Tokens

| Token | Value | Use |
| --- | --- | --- |
| `--radius` | `1.3rem` (20.8px) | base radius (tweakcn) |
| `--x_radius` | `radius + 4px` = 24.8px | cards |
| `--x_radius_sm` | `radius - 2px` = 18.8px | buttons, inputs, selects |
| pill | `9999px` | tabs, menu items, badges |
| `--primary` | `#1E9DF1` light, `#1C9CF0` dark | fills; text on it is `--on_primary` (dark) |
| `--accent` | `#1170B3` light, `#1C9CF0` dark | links, text on a tint, thin lines |
| `--accent_soft` | `#EAF3FB` light, `#061622` dark | hover and selected background |
| `--ring` | `#1DA1F2` | focus ring |
| `--bg_elements` | `#F7F8F8` / `#17181C` | card background (shadcn `card`) |
| `--border_grey` | `#E1EAEF` / `#242628` | borders (shadcn `border`) |
| `--switch_off` | `#CBD8E0` / `#3A3D42` | switch track, off |

Type: system font stack (the reference uses Open Sans, which is not bundled).
Base 14px / 20px. Weights: 400 body, 500 controls and labels, 600 titles.
Sizes: 12 badge, 14 body and controls, 16 card title and rail brand text, 24
home card title, 30 page title.

Contrast: `--accent` on `--accent_soft` is 4.7:1 and on the card background 4.9:1,
so text in those states meets WCAG AA. `--primary` is only used as a fill.

Spacing: 4px steps. Card padding 24px (main column) or 20px (side column), gap
between a card title and its body 16px.

## Components

Status: **done** follows this page, **todo** is still the older style.

| Component | Spec (shadcn source class → our value) | Mixin | Status |
| --- | --- | --- | --- |
| Focus ring | `focus-visible:border-ring ring-[3px] ring-ring/50` → 1px ring border + 3px halo at 40% | `ui-ring` | done |
| Input, Select | `h-9 px-3 py-1 text-sm rounded-md border` → 36px, `4px 12px`, 14px, 18.8px radius; select keeps a chevron | `ui-control`, `ui-select` | done in Settings; todo elsewhere |
| Button | `h-9 px-4 text-sm font-medium` → 36px, `8px 16px`; variants default, secondary, outline, ghost; sizes default, sm, icon | `ui-button` | done in Settings; todo elsewhere |
| Switch | `w-8 h-[1.15rem]`, thumb `size-4` → 32x18 track, 14px thumb, primary when on | `ui-switch` | done (Settings) |
| Toggle chip | outline toggle, filled when on → 32px pill | `ui-toggle` | todo (search filters) |
| Badge, Kbd | `rounded-full px-2 py-0.5 text-xs font-medium` → 12px/500, 1px 8px | `ui-badge` | done (right column code) |
| Card | `rounded-xl border py-6 px-6 gap-6`, title `font-semibold`, description `text-sm text-muted-foreground` | `ui-card`, `ui-card-title`, `ui-card-description` | done in Settings; todo elsewhere |
| Tabs | `TabsList` h-9 p-[3px] muted track; trigger px-2 py-1 text-sm font-medium; active = background + shadow-sm | `ui-tabs-list`, `ui-tabs-trigger`, `ui-tabs-active` | done (profile, search, followers) |
| Menu item | sidebar menu button, `text-sm font-medium`; hover and active use the accent colours → 40px pill, `--accent_soft` background, `--accent` text | `ui-menu-item` | done (left rail) |
| Dropdown menu | `DropdownMenuContent` / `Label` / `RadioItem` / `Separator` | `ui-popover`, `ui-menu-label`, `ui-menu-radio` | done (rail foot) |
| Card header | `CardHeader` grid gap-2, `CardTitle`, `CardDescription`, `CardAction` | `ui-card-header` | done (right column) |

## Appearance menu

Researched from the shadcn sidebar blocks (`sidebar-07` and the internal
`sidebar-footer`): settings that belong to the account or app go in the
**foot of the sidebar** as one menu button that opens a dropdown **upwards**,
with labelled groups and a tick on the current choice. A bare switch or a
floating widget has no label saying what it changes, so it is not used.

```
 [ 🎨  Appearance              ⌃ ]      <- last item of the left rail
   ┌──────────────────────────┐
   │ 🌐 Language              │
   │ A  English             ✓ │
   │ 文 中文                  │
   │ ──────────────────────── │
   │ ◐  Theme                 │
   │ ☼  Light                 │
   │ ☾  Dark                  │
   │ ▭  System              ✓ │
   └──────────────────────────┘
```

- The button is a normal rail item (40px, same type) pinned to the bottom of the
  rail. The panel is a `<details>`, so it opens and closes without JavaScript;
  `public/js/xtheme.js` adds close-on-outside-click and Escape.
- Panel: shadcn DropdownMenuContent (`rounded-md border p-1 shadow-md`), group
  label 14px/600 with a 16px icon, radio item 32px high, 14px, a 16px icon at the left and the tick at the right,
  hover = `--accent_soft` + `--accent`, separator 1px.
- Language: each option is a submit button of a `POST /setlang` form, so it
  works without JavaScript. Language names are shown in their own language.
- Theme: Light, Dark or System (follow the OS). Needs JavaScript, so the group
  is hidden without it. The choice is kept in `localStorage`. Shortcut `t`
  flips light and dark.
- Narrow rail (up to 1280px): only the globe icon; the panel opens to the right
  of it. Phones: the globe sits in the bottom bar and the panel opens upwards.

## Buttons and inputs

- Input and select: 36px high, `4px 12px`, 14px, 18.8px radius, 1px border, the
  3px ring on focus. In Settings rows they are 32px so the rows stay compact.
- The search boxes are the same Input with a 16px leading icon; the ring is drawn
  when the box has focus inside it.
- Buttons: 36px, `8px 16px`, 14px/500. Default (primary fill), outline (border,
  accent tint on hover) and ghost. Icon buttons are 36px or 32px squares.
- Used for: Settings *Save* (default) and *Reset* (outline), the search filter
  button (outline icon), *Load more* (outline), *Clear* in Recent Search (ghost).

## Home

Cards use the shadcn Card spec: 24px padding (20px on phones), a header with the
title, 16px between header and content. The agent names are outline pills with a
20px mark. The marks are from LobeHub Icons (MIT); see
`public/images/agents/README.md`. DeepSeek Harness uses the DeepSeek mark.

## Settings

Each preference group (Display, Media, Link replacements, Bookmark) is a card.
Inside it a row is 30px high with no divider lines: the label on the left, the
control on the right (a switch, a 32px select or a 32px text input). On phones
the control stays on the label's line and takes 46% of the width.

## Rules for new work

1. Use a mixin from `_ui.scss`; add one there before writing a one-off value.
2. Fills use `--primary` with `--on_primary`. Text and thin lines on a light
   background use `--accent`, never `--primary`.
3. No new radius values: pill, `--x_radius_sm` or `--x_radius`.
4. Hover and selected states use `--accent_soft` + `--accent`.
5. Check light and dark (`html[data-x-scheme]`) and widths 1440, 1100, 800, 390.
