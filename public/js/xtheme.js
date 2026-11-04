// @license http://www.gnu.org/licenses/agpl-3.0.html AGPL-3.0
// SPDX-License-Identifier: AGPL-3.0-only
//
// Optional enhancements for the "X" theme. Loaded only when the theme is X and
// the "X theme enhancements" preference is on. Every page works without it.
(function () {
  "use strict";

  const $ = (sel, root = document) => root.querySelector(sel);
  const $$ = (sel, root = document) => [...root.querySelectorAll(sel)];
  const typing = el =>
    el && (el.isContentEditable || ["INPUT", "TEXTAREA", "SELECT"].includes(el.tagName));

  // ---- image lightbox: click a photo to view it without leaving the page
  let box, boxImg, boxPrev, boxNext, gallery = [], index = 0;

  function buildBox() {
    box = document.createElement("div");
    box.className = "x-lightbox";
    box.setAttribute("role", "dialog");
    box.setAttribute("aria-modal", "true");
    box.hidden = true;
    box.innerHTML =
      '<button class="x-lb-close" aria-label="Close" type="button">\u00d7</button>' +
      '<button class="x-lb-nav x-lb-prev" aria-label="Previous" type="button">\u2039</button>' +
      '<img class="x-lb-img" alt="">' +
      '<button class="x-lb-nav x-lb-next" aria-label="Next" type="button">\u203a</button>';
    document.body.appendChild(box);
    boxImg = $(".x-lb-img", box);
    boxPrev = $(".x-lb-prev", box);
    boxNext = $(".x-lb-next", box);
    box.addEventListener("click", e => {
      if (e.target === box || e.target.classList.contains("x-lb-close")) closeBox();
      else if (e.target === boxPrev) step(-1);
      else if (e.target === boxNext) step(1);
    });
  }

  function show(i) {
    index = (i + gallery.length) % gallery.length;
    boxImg.src = gallery[index];
    boxPrev.hidden = boxNext.hidden = gallery.length < 2;
  }

  function step(d) { if (gallery.length > 1) show(index + d); }

  function openBox(links, start) {
    if (!box) buildBox();
    gallery = links;
    box.hidden = false;
    document.documentElement.classList.add("x-lb-open");
    show(start);
  }

  function closeBox() {
    if (!box || box.hidden) return;
    box.hidden = true;
    boxImg.removeAttribute("src");
    document.documentElement.classList.remove("x-lb-open");
  }

  document.addEventListener("click", e => {
    if (e.defaultPrevented || e.button !== 0 || e.metaKey || e.ctrlKey || e.shiftKey) return;
    const link = e.target.closest("a.still-image");
    if (!link) return;
    const group = $$("a.still-image", link.closest(".attachments") || document);
    e.preventDefault();
    openBox(group.map(a => a.href), Math.max(0, group.indexOf(link)));
  });

  // ---- keyboard shortcuts
  const items = () => $$(".timeline-item:not(.show-more)");
  let current = -1;

  function focusItem(i) {
    const list = items();
    if (!list.length) return;
    current = Math.max(0, Math.min(list.length - 1, i));
    list.forEach(el => el.classList.remove("x-current"));
    const el = list[current];
    el.classList.add("x-current");
    el.scrollIntoView({ block: "center", behavior: "auto" });
  }

  function openCurrent() {
    const el = items()[current];
    const a = el && $(".tweet-link", el);
    if (a) location.href = a.href;
  }

  // the page follows the system colour scheme unless a choice was saved. The
  // resolved value is mirrored in data-x-resolved so the toggle can show the
  // right icon.
  function resolvedScheme() {
    const forced = document.documentElement.dataset.xScheme;
    if (forced === "dark" || forced === "light") return forced;
    return matchMedia("(prefers-color-scheme: dark)").matches ? "dark" : "light";
  }

  function syncScheme() {
    const mode = resolvedScheme();
    document.documentElement.dataset.xResolved = mode;
    // native parts (scrollbars, date pickers, form controls) follow the page
    document.documentElement.style.colorScheme = mode;
    // the browser bar on phones
    const bar = document.querySelector('meta[name="theme-color"]');
    if (bar) {
      // the page's own background, so every theme gets a matching bar
      const bg = getComputedStyle(document.body).backgroundColor;
      bar.content = bg && bg !== "rgba(0, 0, 0, 0)" ? bg : (mode === "dark" ? "#000000" : "#FFFFFF");
    }
    const forced = document.documentElement.dataset.xScheme;
    const choice = forced === "dark" || forced === "light" ? forced : "system";
    document.querySelectorAll(".x-menu-item[data-scheme]").forEach(b => {
      const on = b.dataset.scheme === choice;
      b.dataset.state = on ? "on" : "off";
      b.setAttribute("aria-checked", on ? "true" : "false");
    });
  }

  function setScheme(v) {
    if (v === "system") {
      delete document.documentElement.dataset.xScheme;
      try { localStorage.removeItem("x-scheme"); } catch (_) {}
    } else {
      document.documentElement.dataset.xScheme = v;
      try { localStorage.setItem("x-scheme", v); } catch (_) {}
    }
    syncScheme();
  }

  function toggleScheme() {
    const next = resolvedScheme() === "dark" ? "light" : "dark";
    document.documentElement.dataset.xScheme = next;
    try { localStorage.setItem("x-scheme", next); } catch (_) {}
    syncScheme();
  }

  let gPending = 0;
  document.addEventListener("keydown", e => {
    if (e.metaKey || e.ctrlKey || e.altKey) return;
    if (e.key === "Escape") { closeBox(); if (typing(document.activeElement)) document.activeElement.blur(); return; }
    if (box && !box.hidden) {
      if (e.key === "ArrowLeft") step(-1);
      else if (e.key === "ArrowRight") step(1);
      return;
    }
    if (typing(e.target)) return;

    if (gPending && Date.now() - gPending < 1200) {
      gPending = 0;
      const go = { h: "/", s: "/search", p: "/settings" }[e.key];
      if (go) { e.preventDefault(); location.href = go; }
      return;
    }

    switch (e.key) {
      case "j": focusItem(current + 1); break;
      case "k": focusItem(current < 0 ? 0 : current - 1); break;
      case "o": case "Enter": if (current >= 0) openCurrent(); break;
      case "/": {
        // the search forms also carry a hidden "f" field, so match the text box
        const input = $(".x-aside-search input[name=q]") || $(".search-field input[name=q]") ||
                      $(".search-bar input[name=q]");
        if (input) { e.preventDefault(); input.focus(); input.select(); }
        break;
      }
      case "g": gPending = Date.now(); break;
      case "t": toggleScheme(); break;
      case "?": showHelp(); break;
    }
  });

  function showHelp() {
    let help = $(".x-help");
    if (help) { help.remove(); return; }
    help = document.createElement("div");
    help.className = "x-help";
    help.innerHTML =
      "<h2>Keyboard shortcuts</h2><dl>" +
      "<dt>j / k</dt><dd>Next / previous post</dd>" +
      "<dt>o or Enter</dt><dd>Open the selected post</dd>" +
      "<dt>/</dt><dd>Focus search</dd>" +
      "<dt>g h / g s / g p</dt><dd>Go to home / search / settings</dd>" +
      "<dt>t</dt><dd>Toggle light and dark</dd>" +
      "<dt>\u2190 \u2192 Esc</dt><dd>Browse or close photos</dd>" +
      "<dt>?</dt><dd>Show or hide this help</dd></dl>";
    help.addEventListener("click", () => help.remove());
    document.body.appendChild(help);
  }

  // ---- search history cloud in the right column
  // Only this browser's own searches are stored, and only when the
  // enhancement is enabled. Nothing is sent anywhere.
  const CLOUD_KEY = "x-searches";
  const CLOUD_MAX = 60;

  function readCloud() {
    try { return JSON.parse(localStorage.getItem(CLOUD_KEY)) || []; }
    catch (_) { return []; }
  }

  function writeCloud(list) {
    try { localStorage.setItem(CLOUD_KEY, JSON.stringify(list)); } catch (_) {}
  }

  function rememberSearch(term) {
    term = (term || "").trim();
    if (term.length < 2 || term.length > 60) return;
    const list = readCloud().filter(e => e.t.toLowerCase() !== term.toLowerCase());
    const old = readCloud().find(e => e.t.toLowerCase() === term.toLowerCase());
    list.unshift({ t: term, n: old ? old.n + 1 : 1 });
    writeCloud(list.slice(0, CLOUD_MAX));
  }

  // Palette for the words. Fixed order, so a word keeps its colour between
  // visits. A theme may define --x_cloud_1 .. --x_cloud_7 (colours that read on
  // its own background, one set per colour mode); without them, this list is
  // used. It is chosen to read on both the light and the dark card.
  const CLOUD_COLORS = ["#1D9BF0", "#4FB3BF", "#00B87A", "#8BC34A", "#F7B928", "#FF7A00", "#E0245E", "#7856FF", "#5B8DEF", "#8B9096"];

  // how many of the theme's --x_cloud_N variables exist (0 = use the list above)
  function themeCloudSize() {
    const cs = getComputedStyle(document.body);
    let n = 0;
    while (n < 7 && cs.getPropertyValue("--x_cloud_" + (n + 1)).trim()) n++;
    return n;
  }

  function hashWord(t) {
    let h = 0;
    for (let i = 0; i < t.length; i++) h = (h * 31 + t.charCodeAt(i)) | 0;
    return Math.abs(h);
  }

  // A packed word cloud, in the manner of the classic generators: every word is
  // drawn into an off-screen canvas, and its real glyph pixels (not a bounding
  // box) are tested against a bitmap of what is already placed. Small words
  // therefore settle into the gaps between and inside the big ones. Words go
  // biggest first along an outward spiral from the middle, inside a rounded
  // oval. The size of the largest word is found by bisection: the biggest value
  // at which every word still fits, so the oval is as full as the list allows.
  const CLOUD_MIN_PX = 10, CLOUD_TOP_PX = [14, 60];

  function layoutCloud(box, list) {
    const W = box.clientWidth, H = box.clientHeight;
    if (!W || !H) return;
    const family = getComputedStyle(box).fontFamily;
    const themeN = themeCloudSize();
    const cv = document.createElement("canvas");
    const ctx = cv.getContext("2d", { willReadFrequently: true });
    if (!ctx) return;

    // weight: how often, and how recently, a word was searched
    const max = Math.max(...list.map(e => e.n)), min = Math.min(...list.map(e => e.n));
    const last = Math.max(1, list.length - 1);
    const raw = list.map((e, i) => {
      const recent = 1 - i / last;
      return max === min ? recent : 0.65 * (e.n - min) / (max - min) + 0.35 * recent;
    });
    const lo = Math.min(...raw), hi = Math.max(...raw);
    const items = list.map((e, i) => ({ e, h: hashWord(e.t), t: hi === lo ? 1 : (raw[i] - lo) / (hi - lo) }));
    items.sort((a, b) => b.t - a.t || a.e.t.localeCompare(b.e.t));

    // glyph pixels of one word, horizontal or turned a quarter anticlockwise
    function mask(text, size, weight, vertical) {
      ctx.font = `${weight} ${size}px ${family}`;
      const tw = Math.ceil(ctx.measureText(text).width) + 2, th = Math.ceil(size * 1.2);
      const cw = vertical ? th : tw, ch = vertical ? tw : th;
      cv.width = cw; cv.height = ch;
      ctx.font = `${weight} ${size}px ${family}`;
      ctx.textBaseline = "middle";
      if (vertical) { ctx.translate(0, ch); ctx.rotate(-Math.PI / 2); }
      ctx.fillText(text, 1, th / 2);
      // each word is solid from its first to its last pixel along its own
      // direction, so a smaller word cannot slip into the space inside it
      const data = ctx.getImageData(0, 0, cw, ch).data, pts = [];
      if (vertical) {
        for (let x = 0; x < cw; x++) {
          let a = -1, z = -1;
          for (let y = 0; y < ch; y++) if (data[(y * cw + x) * 4 + 3] > 50) { if (a < 0) a = y; z = y; }
          for (let y = a; a >= 0 && y <= z; y++) pts.push(x, y);
        }
      } else {
        for (let y = 0; y < ch; y++) {
          let a = -1, z = -1;
          for (let x = 0; x < cw; x++) if (data[(y * cw + x) * 4 + 3] > 50) { if (a < 0) a = x; z = x; }
          for (let x = a; a >= 0 && x <= z; x++) pts.push(x, y);
        }
      }
      return { w: cw, h: ch, tw, th, pts };
    }

    const cx = W / 2, cy = H / 2, ra = W / 2, rb = H / 2, N = 2.7;
    // the half width of the oval on every row, computed once
    const span = new Float32Array(H + 1);
    for (let y = 0; y <= H; y++) {
      const v = Math.pow(Math.abs(y - cy) / rb, N);
      span[y] = v >= 1 ? -1 : ra * Math.pow(1 - v, 1 / N);
    }
    const inside = (x, y, w, h) => {
      const a = span[y], b = span[y + h];
      return a >= 0 && b >= 0 && x >= cx - a && x + w <= cx + a && x >= cx - b && x + w <= cx + b;
    };
    const masks = new Map();

    function pack(top) {
      const occ = new Uint8Array(W * H), out = [];
      for (let i = 0; i < items.length; i++) {
        const { e, h, t } = items[i];
        const size = Math.round(CLOUD_MIN_PX + (top - CLOUD_MIN_PX) * Math.pow(t, 1.45));
        const weight = size > 28 ? "700" : size > 17 ? "600" : "500";
        const prefer = i > 0 && h % 6 === 0 && size < 30;
        let hit = null;
        for (const vertical of prefer ? [true, false] : [false, true]) {
          const mk = e.t + "|" + size + "|" + weight + "|" + vertical;
          let m = masks.get(mk);
          if (!m) { m = mask(e.t, size, weight, vertical); masks.set(mk, m); }
          if (m.w > W || m.h > H) continue;
          const phase = (h % 628) / 100, sgn = h % 2 ? 1 : -1;
          for (let th = 0, r = 0; r <= Math.max(ra, rb) * 1.05; th += 3 / Math.max(r, 3)) {
            r = 0.55 * th;
            const x = Math.round(cx + Math.cos(phase + sgn * th) * r * (ra / rb) - m.w / 2);
            const y = Math.round(cy + Math.sin(phase + sgn * th) * r - m.h / 2);
            if (x < 0 || y < 0 || x + m.w > W || y + m.h > H || !inside(x, y, m.w, m.h)) continue;
            let free = true;
            for (let k = 0; k < m.pts.length; k += 2) if (occ[(y + m.pts[k + 1]) * W + x + m.pts[k]]) { free = false; break; }
            if (free) { hit = { x, y, m, vertical }; break; }
          }
          if (hit) break;
        }
        if (!hit) continue;
        const { x, y, m } = hit;
        for (let k = 0; k < m.pts.length; k += 2)           // mark, grown by one pixel
          for (let dy = -1; dy <= 1; dy++) for (let dx = -1; dx <= 1; dx++) {
            const px = x + m.pts[k] + dx, py = y + m.pts[k + 1] + dy;
            if (px >= 0 && py >= 0 && px < W && py < H) occ[py * W + px] = 1;
          }
        out.push({ e, h, size, weight, x, y, m, vertical: hit.vertical });
      }
      return out;
    }

    // bisection on the largest word's size
    let best = null, lowTop = CLOUD_TOP_PX[0], highTop = CLOUD_TOP_PX[1];
    const small = pack(lowTop);
    if (small.length < items.length) best = small;
    else {
      best = small;
      for (let i = 0; i < 5; i++) {
        const mid = (lowTop + highTop) / 2, r = pack(mid);
        if (r.length === items.length) { best = r; lowTop = mid; } else highTop = mid;
      }
    }

    best.forEach(({ e, h, size, weight, x, y, m, vertical }) => {
      const a = document.createElement("a");
      a.className = "x-cloud-word";
      a.href = "/search?f=tweets&q=" + encodeURIComponent(e.t);
      a.textContent = e.t;
      a.title = e.n === 1 ? "1 search" : e.n + " searches";
      const color = themeN
        ? `var(--x_cloud_${h % themeN + 1}, var(--fg_faded))`
        : CLOUD_COLORS[h % CLOUD_COLORS.length];
      a.style.cssText = `width:${m.tw}px;height:${m.th}px;line-height:${m.th}px;font-size:${size}px;` +
        `font-weight:${weight};color:${color};` +
        (vertical ? `left:${x}px;top:${y + m.h}px;` : `left:${x}px;top:${y}px;`);
      if (vertical) a.dataset.v = "1";
      box.appendChild(a);
    });
  }

  function renderCloud() {
    const card = $(".x-cloud");
    if (!card) return;
    clearTimeout(renderCloud.t);
    const list = readCloud();
    const box = $(".x-cloud-list", card);
    if (!box) return;
    box.textContent = "";
    if (!list.length) { card.hidden = true; return; }
    card.hidden = false;
    // after the first paint, so a long list never delays the page itself
    renderCloud.t = setTimeout(() => { box.textContent = ""; layoutCloud(box, list); }, 30);
  }

  // record what was searched, then draw the cloud. Done on the results page
  // rather than on submit so hashtag links and typed URLs count too; a reload
  // of the same page is not counted again.
  (function () {
    if (!/^\/search\/?$/.test(location.pathname)) return;
    const params = new URLSearchParams(location.search);
    if (!["tweets", "top", "media", null].includes(params.get("f"))) return;
    const nav = performance.getEntriesByType("navigation")[0];
    if (nav && nav.type === "reload") return;
    rememberSearch(params.get("q"));
  })();
  const clearBtn = $(".x-cloud-clear");
  if (clearBtn) clearBtn.addEventListener("click", () => { writeCloud([]); renderCloud(); });

  renderCloud();
  addEventListener("storage", e => { if (e.key === CLOUD_KEY) renderCloud(); });
  let cloudW = 0, cloudH = 0;
  addEventListener("resize", () => {
    const box = $(".x-cloud-list");
    if (box && (box.clientWidth !== cloudW || box.clientHeight !== cloudH)) { cloudW = box.clientWidth; cloudH = box.clientHeight; renderCloud(); }
  });

  // ---- restore a remembered light/dark choice and show the switch
  try {
    const saved = localStorage.getItem("x-scheme");
    if (saved === "dark" || saved === "light") document.documentElement.dataset.xScheme = saved;
  } catch (_) {}
  syncScheme();
  matchMedia("(prefers-color-scheme: dark)").addEventListener("change", syncScheme);
  const themeGroup = $(".x-menu-theme");
  if (themeGroup) {
    themeGroup.hidden = false;
    $(".x-menu-sep").hidden = false;
    themeGroup.addEventListener("click", e => {
      const b = e.target.closest(".x-menu-item[data-scheme]");
      if (b) setScheme(b.dataset.scheme);
    });
  }
  // the panel closes on an outside click or Escape, like a dropdown menu
  const menu = $(".x-menu");
  if (menu) {
    document.addEventListener("click", e => { if (menu.open && !menu.contains(e.target)) menu.open = false; });
    document.addEventListener("keydown", e => { if (e.key === "Escape" && menu.open) { menu.open = false; $(".x-menu-button", menu).focus(); } });
  }

  // ---- hide the bottom bar while scrolling down on phones
  let lastY = scrollY, ticking = false;
  const nav = $(".x-nav");
  addEventListener("scroll", () => {
    if (ticking || !nav) return;
    ticking = true;
    requestAnimationFrame(() => {
      const y = scrollY;
      if (Math.abs(y - lastY) > 8) nav.classList.toggle("x-nav-hidden", y > lastY && y > 120);
      lastY = y;
      ticking = false;
    });
  }, { passive: true });
})();
