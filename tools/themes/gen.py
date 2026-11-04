#!/usr/bin/env python3
"""Generate public/css/themes/<name>.css from tweakcn theme definitions.

A tweakcn theme is a set of shadcn tokens (--background, --primary, ...) for a
light and a dark mode. The X layout reads a small set of Nitter variables, so
this script maps one onto the other and writes a stylesheet with the same
structure as x.css: light by default, dark when the system asks for it, and an
explicit html[data-x-scheme] choice that overrides both.

Usage:  python3 tools/themes/gen.py tools/themes/sources/*.json
Source files are the "registry:style" JSON served by tweakcn.com
(https://tweakcn.com/r/themes/<name or id>); only the colour tokens and the
radius are used. No fonts are loaded: every theme uses the system font stack.
"""
import json, math, os, re, sys

OUT = os.path.join(os.path.dirname(__file__), "..", "..", "public", "css", "themes")

# Palette keys used for the word cloud (CLOUD_COLORS in xtheme.js reads them)
CHARTS = ["chart-1", "chart-2", "chart-3", "chart-4", "chart-5"]


def strip(v):
    return v.strip()


def to_rgb(c):
    """#hex, rgb()/rgba() or oklch() -> (r, g, b) in 0..1, or None."""
    c = c.strip().lower()
    m = re.fullmatch(r"#([0-9a-f]{6})([0-9a-f]{2})?", c)
    if m:
        h = m.group(1)
        return tuple(int(h[i:i + 2], 16) / 255 for i in (0, 2, 4))
    m = re.match(r"rgba?\(\s*([\d.]+)[ ,]+([\d.]+)[ ,]+([\d.]+)", c)
    if m:
        return tuple(float(x) / 255 for x in m.groups())
    m = re.match(r"oklch\(\s*([\d.]+%?)\s+([\d.]+)\s+([\d.]+)", c)
    if m:
        L = float(m.group(1).rstrip("%")) / (100 if m.group(1).endswith("%") else 1)
        C, H = float(m.group(2)), math.radians(float(m.group(3)))
        a, b = C * math.cos(H), C * math.sin(H)
        l = (L + 0.3963377774 * a + 0.2158037573 * b) ** 3
        mm = (L - 0.1055613458 * a - 0.0638541728 * b) ** 3
        ss = (L - 0.0894841775 * a - 1.2914855480 * b) ** 3
        lin = (4.0767416621 * l - 3.3077115913 * mm + 0.2309699292 * ss,
               -1.2684380046 * l + 2.6097574011 * mm - 0.3413193965 * ss,
               -0.0041960863 * l - 0.7034186147 * mm + 1.7076147010 * ss)
        f = lambda x: 12.92 * x if x <= 0.0031308 else 1.055 * max(x, 0) ** (1 / 2.4) - 0.055
        return tuple(min(1, max(0, f(x))) for x in lin)
    return None


def luminance(rgb):
    f = lambda x: x / 12.92 if x <= 0.03928 else ((x + 0.055) / 1.055) ** 2.4
    r, g, b = (f(x) for x in rgb)
    return 0.2126 * r + 0.7152 * g + 0.0722 * b


def contrast(a, b):
    ra, rb = to_rgb(a), to_rgb(b)
    if not ra or not rb:
        return 0
    la, lb = sorted((luminance(ra), luminance(rb)), reverse=True)
    return (la + 0.05) / (lb + 0.05)


def mix(a, b, pct):
    """color-mix(in oklab, a pct%, b): lets the browser blend any two colours."""
    return f"color-mix(in oklab, {a} {pct}%, {b})"


def srgb_mix(a, b, pct):
    """Plain sRGB blend, so the contrast maths here matches color-mix(in srgb)."""
    ra, rb = to_rgb(a), to_rgb(b)
    return tuple(x * pct / 100 + y * (100 - pct) / 100 for x, y in zip(ra, rb))


def contrast_rgb(ra, rb):
    la, lb = sorted((luminance(ra), luminance(rb)), reverse=True)
    return (la + 0.05) / (lb + 0.05)


def readable(c, surfaces, fg, target):
    """c, or c blended toward the foreground until it reaches `target` contrast
    on every surface. Keeps the theme hue where it already reads, so only weak
    colours change (e.g. a bright brand colour used as link text)."""
    surfaces = [x for x in surfaces if to_rgb(x)]
    worst = lambda rgb: min(contrast_rgb(rgb, to_rgb(x)) for x in surfaces)
    if worst(to_rgb(c)) >= target:
        return c
    for pct in range(95, 0, -5):
        if worst(srgb_mix(c, fg, pct)) >= target:
            return f"color-mix(in srgb, {c} {pct}%, {fg})"
    return fg


def vars_for(t, mode):
    """The Nitter variables for one mode of one theme, as an ordered dict."""
    s = {k: strip(v) for k, v in t[mode].items() if isinstance(v, str)}
    bg, fg = s["background"], s["foreground"]
    card = s.get("card", bg)
    muted = s.get("muted", card)
    mfg = s.get("muted-foreground", fg)
    border = s.get("border", muted)
    # a border the same colour as the page (TikTok's) would draw nothing
    if contrast(border, bg) < 1.15:
        border = mix(fg, bg, 14)
    mfg = readable(mfg, [bg, card, muted], fg, 4.7)
    primary = s["primary"]
    on_primary = s["primary-foreground"]
    # --accent is for text and thin lines on the page background. For a
    # monochrome theme (primary == foreground) that is just the foreground.
    accent_text = readable(s.get("link") or primary, [bg, card], fg, 4.5)
    v = {
        "--bg_color": bg,
        "--fg_color": fg,
        "--fg_faded": mfg,
        "--fg_dark": "var(--fg_faded)",
        "--fg_nav": "var(--fg_color)",
        "--bg_panel": bg,
        "--bg_elements": card if card != bg else muted,
        "--bg_overlays": s.get("popover", bg),
        "--bg_hover": muted,
        "--grey": "var(--fg_faded)",
        "--dark_grey": border,
        "--darker_grey": border,
        "--darkest_grey": muted,
        "--border_grey": border,
        "--primary": primary,
        "--on_primary": on_primary,
        "--accent": accent_text,
        "--accent_light": accent_text,
        "--accent_dark": accent_text,
        "--accent_border": accent_text,
        "--accent_soft": mix(accent_text, bg, 10),
        "--ring": s.get("ring", primary),
        "--switch_off": s.get("input", border),
        "--play_button": "var(--primary)",
        "--play_button_hover": mix("var(--primary)", "var(--fg_color)", 88),
        "--more_replies_dots": "var(--accent)",
        "--error_red": s.get("destructive", "#F4212E"),
        "--verified_blue": primary,
        "--icon_text": on_primary,
        "--tab": "var(--fg_faded)",
        "--tab_selected": "var(--fg_color)",
        "--profile_stat": "var(--fg_color)",
        "--x_like": s.get("destructive", "#E0245E"),
        "--x_repost": s.get("chart-2", "#17BF63"),
        "--x_reply": "var(--accent)",
        "--x_hover_bg": mix(fg, bg, 6),
        "--x_blur_bg": f"color-mix(in oklab, {bg} 85%, transparent)",
    }
    return v


def block(v, indent="    "):
    return "\n".join(f"{indent}{k}: {val};" for k, val in v.items())


def dark_only(light, dark):
    """Only the variables whose dark value differs from the light one."""
    return {k: v for k, v in dark.items() if light.get(k) != v}


def radius_of(t):
    r = t["light"].get("radius") or t.get("theme", {}).get("radius") or "0.5rem"
    return strip(r)


SYSTEM_FONT = ('-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", '
               'Arial, "Noto Sans", "PingFang SC", "Microsoft YaHei", sans-serif')
MONO_FONT = ('ui-monospace, SFMono-Regular, "SF Mono", Menlo, Consolas, "Liberation Mono", '
             '"PingFang SC", "Microsoft YaHei", monospace')


def cloud_vars(t, mode, v):
    """Word-cloud colours: the theme's primary and chart colours that stay
    readable (contrast >= 3) on its page background, then the faded text."""
    s = t[mode]
    bg = strip(s["background"])
    cand = [strip(s["primary"])] + [strip(s[k]) for k in CHARTS if k in s]
    out = []
    for c in cand:
        if contrast(c, bg) >= 3 and c not in out:
            out.append(c)
    out.append(strip(s.get("muted-foreground", s["foreground"])))
    return {f"--x_cloud_{i + 1}": c for i, c in enumerate(out[:7])}


def radius_px(r):
    m = re.fullmatch(r"([\d.]+)(rem|px)", r)
    return float(m.group(1)) * (16 if m.group(2) == "rem" else 1) if m else 8


def font_of(t, name):
    """A named face the visitor may have installed, then the system stack."""
    raw = strip(t["light"].get("font-sans") or t.get("theme", {}).get("font-sans") or "")
    first = raw.split(",")[0].strip().strip("'\"")
    if name == "mono":
        return f'"Geist Mono", {MONO_FONT}'
    if not first or first.lower() in ("ui-sans-serif", "system-ui", "-apple-system"):
        return None
    return f'"{first}", {SYSTEM_FONT}'


def generate(name, label, t, credit):
    light, dark = vars_for(t, "light"), vars_for(t, "dark")
    light.update(cloud_vars(t, "light", light))
    dark.update(cloud_vars(t, "dark", dark))
    d = dark_only(light, dark)
    # a cloud colour present only in light must not leak into dark
    for k in list(light):
        if k.startswith("--x_cloud_") and k not in dark:
            d[k] = "unset"
    radius = radius_of(t)
    px = radius_px(radius)
    pill = "9999px" if px >= 16 else "calc(var(--radius) + 2px)"
    font = font_of(t, name)
    shape_lines = [
        f"--radius: {radius};",
        "--x_radius: calc(var(--radius) + 4px);",
        "--x_radius_sm: max(0px, calc(var(--radius) - 2px));",
        f"--x_pill: {pill};",
    ]
    if font:
        shape_lines.append(f"--x_font: {font};")
    ind = lambda n: "\n".join(" " * n + l for l in shape_lines)
    return f"""/* "{label}" theme for the X layout. {credit}
   Generated by tools/themes/gen.py from the tweakcn definition; the component
   styles live in src/sass/x and read only the variables below. */
body {{
{block(light)}

{ind(4)}
}}

/* without the script, the system setting alone decides */
:root {{ color-scheme: light dark; }}

@media (prefers-color-scheme: dark) {{
    body {{
{block(d, "        ")}
    }}
}}

/* the "t" shortcut and the theme button: an explicit choice overrides the
   system setting. Only set by public/js/xtheme.js. */
html[data-x-scheme="dark"] body {{
{block(d)}
}}
@media (prefers-color-scheme: dark) {{
    html[data-x-scheme="light"] body {{
{block(light, "        ")}
    }}
}}
"""


META = {
    "vercel": ("Vercel", "Colours follow the \"Vercel\" theme on tweakcn.com."),
    "mono": ("Mono", "Colours follow the \"Mono\" theme on tweakcn.com."),
    "claude": ("Claude", "Colours follow the \"Claude\" theme on tweakcn.com."),
    "codex": ("Codex", "Colours follow the \"Codex\" community theme on tweakcn.com."),
    "tiktok": ("TikTok", "Colours follow the \"TikTok\" community theme on tweakcn.com."),
}


def main(paths):
    for p in paths:
        name = os.path.splitext(os.path.basename(p))[0]
        j = json.load(open(p))
        cv = j["cssVars"]
        t = {"light": cv["light"], "dark": cv["dark"], "theme": cv.get("theme", {})}
        label, credit = META.get(name, (name.title(), ""))
        css = generate(name, label, t, credit)
        out = os.path.join(OUT, name + ".css")
        open(out, "w").write(css)
        print("wrote", os.path.normpath(out), len(css), "bytes")


if __name__ == "__main__":
    main(sys.argv[1:])
