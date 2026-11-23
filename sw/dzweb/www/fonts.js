// fonts.js - the board's TrueType fonts in the web app (2026-11-22).
// dzweb serves them at /fonts/<name> (any subfolder of /usr/share/fonts, as
// /files fonts lists them). fontFamily(name) adds a FontFace once and gives a
// CSS font-family; the browser loads the file only when text uses it (and
// caches it for a day). fontPicker() = a font select whose list shows each
// name in its own font: only the rows in view load (a board has up to ~800
// fonts, 68 MB), so it is a list, not a native <select>.
import { h } from "./ui.js";
import * as net from "./net.js";

export const DEFAULT_FONT = "LiberationSans-Regular.ttf"; // lib/dz_text.h DZ_FONT_DEFAULT
const faces = new Map(); // name -> { fam, face }

function face(name) {
  name = name || DEFAULT_FONT;
  let f = faces.get(name);
  if (!f) {
    const fam = "dz-" + name.replace(/[^A-Za-z0-9_-]/g, "_");
    const ff = new FontFace(fam, `url(/fonts/${encodeURIComponent(name)})`);
    document.fonts.add(ff);
    f = { fam, face: ff };
    faces.set(name, f);
  }
  return f;
}
// CSS font-family of a board font ("" = the default font)
export function fontFamily(name, fallback = "sans-serif") {
  return `"${face(name).fam}", ${fallback}`;
}
// a canvas / CSS font shorthand
export function fontCss(px, name) {
  return `${px}px ${fontFamily(name)}`;
}
// canvas text does not start a font load: call cb once the font is there
// (at once, false, when it is already loaded; cb(true) after a load)
export function whenFont(name, cb) {
  const ff = face(name).face;
  if (ff.status === "loaded") return true;
  if (ff.status !== "error") ff.load().then(() => cb(true), () => {});
  return false;
}
// vertical metrics (head unitsPerEm, hhea ascent / descent / lineGap) as the
// board uses them: stb_truetype scales a font so ascent - descent = the px
// size (stbtt_ScaleForPixelHeight), CSS so the em = the px size; the board's
// line pitch = ascent - descent + lineGap, the baseline = top + ascent
// (lib/dz_text.c line_metrics; measured on .236, LiberationSans 200 px: cap H
// 123 px, pitch 205 px). Read from the font file (the same cached /fonts URL).
const LIB = { em: 2048, asc: 1854, desc: -434, gap: 67 }; // LiberationSans until a file is read
const mets = new Map(); // name -> metrics | Promise
function parseMetrics(buf) {
  const v = new DataView(buf);
  let base = 0;
  if (v.getUint32(0) === 0x74746366) base = v.getUint32(12); // "ttcf": the first font, as the board
  const n = v.getUint16(base + 4), t = {};
  for (let i = 0; i < n; i++) {
    const r = base + 12 + i * 16;
    t[String.fromCharCode(v.getUint8(r), v.getUint8(r + 1), v.getUint8(r + 2), v.getUint8(r + 3))] = v.getUint32(r + 8);
  }
  if (t.head === undefined || t.hhea === undefined) throw new Error("no head/hhea");
  return { em: v.getUint16(t.head + 18), asc: v.getInt16(t.hhea + 4), desc: v.getInt16(t.hhea + 6), gap: v.getInt16(t.hhea + 8) };
}
function metrics(name, cb) {
  name = name || DEFAULT_FONT;
  const m = mets.get(name);
  if (m && !(m instanceof Promise)) return m;
  if (!m) {
    const p = fetch(`/fonts/${encodeURIComponent(name)}`).then((r) => (r.ok ? r.arrayBuffer() : Promise.reject()))
      .then(parseMetrics).catch(() => LIB).then((x) => { mets.set(name, x); return x; });
    mets.set(name, p);
  }
  if (cb) mets.get(name).then(() => cb(true));
  return null;
}
// a board TrueType text of size px in the browser: { font (CSS shorthand),
// lh (line pitch), asc (top -> baseline) }, all in board pixels. Draw with
// textBaseline "alphabetic" at y + asc + k * lh. Until the file is read it
// uses LiberationSans; cb() runs when the real numbers (and the face) are in.
export function boardText(px, name, cb) {
  const m = metrics(name, cb) || LIB, k = px / (m.asc - m.desc);
  if (cb) whenFont(name, cb);
  return { font: `${px * m.em / (m.asc - m.desc)}px ${fontFamily(name)}`, lh: k * (m.asc - m.desc + m.gap), asc: k * m.asc };
}
export const fontLabel = (n) => (n || DEFAULT_FONT).replace(/\.(ttf|otf|ttc)$/i, "");

// the board's font list, once per page (bare names, sorted)
let listP = null;
export function boardFonts(again = false) {
  if (!listP || again)
    listP = net.collect(net.message("/files", "fonts"), "/file", "/file/end")
      .then((l) => { if (!l.length) listP = null; return [...new Set(l.map((a) => a[0]))].sort((a, b) => a.localeCompare(b)); })
      .catch(() => { listP = null; return []; });
  return listP;
}

// a font picker: { el, value (get/set), setList(names), refresh() }.
// opts: title, onchange(value), defaultLabel. value "" = the default font.
export function fontPicker(opts = {}) {
  const dflt = opts.defaultLabel || "default font";
  let value = "", names = [], hi = -1, shown = [];
  const btn = h("button.fontpick-btn", { type: "button", title: opts.title || "" });
  const filter = h("input.fontpick-filter", { type: "search", placeholder: "filter", spellcheck: false });
  const list = h("div.fontpick-list", { role: "listbox" });
  const pop = h("div.fontpick-pop", { hidden: true }, filter, list);
  const el = h("span.fontpick", {}, btn, pop);
  // load a row's font when it scrolls into view
  const io = new IntersectionObserver((ents) => {
    for (const e of ents) if (e.isIntersecting) {
      e.target.style.fontFamily = fontFamily(e.target.dataset.font);
      io.unobserve(e.target);
    }
  }, { root: list, rootMargin: "200px 0px" });

  const label = () => {
    btn.textContent = value ? fontLabel(value) : `${dflt} (${fontLabel("")})`;
    btn.style.fontFamily = fontFamily(value);
  };
  const mark = () => shown.forEach((r, k) => r.classList.toggle("hi", k === hi));
  const build = () => {
    io.disconnect();
    const q = filter.value.trim().toLowerCase();
    const all = [""].concat(names.filter((n) => n !== ""));
    shown = all.filter((n) => !q || (n || dflt).toLowerCase().includes(q)).map((n) => {
      const r = h("div.fontpick-row", { role: "option", title: n || `${dflt}: ${DEFAULT_FONT}`,
        onmousedown: (e) => { e.preventDefault(); pick(n); } }, n ? fontLabel(n) : `${dflt} (${fontLabel("")})`);
      r.dataset.font = n;
      if (n === value) r.classList.add("sel");
      io.observe(r);
      return r;
    });
    list.replaceChildren(...shown);
    hi = Math.max(0, shown.findIndex((r) => r.dataset.font === value));
    mark();
  };
  const open = () => {
    if (names.length < 2) boardFonts(true).then((l) => { if (l.length) api.setList(l); }); // no list yet (socket was not up)
    pop.hidden = false;
    filter.value = "";
    build();
    shown[hi]?.scrollIntoView({ block: "center" });
    filter.focus();
  };
  const close = () => { pop.hidden = true; io.disconnect(); };
  const pick = (n) => {
    close();
    if (n === value) return;
    value = n;
    label();
    opts.onchange?.(value);
  };
  btn.onclick = () => (pop.hidden ? open() : close());
  filter.oninput = build;
  filter.onkeydown = (e) => {
    if (e.key === "ArrowDown" || e.key === "ArrowUp") {
      e.preventDefault();
      hi = Math.max(0, Math.min(shown.length - 1, hi + (e.key === "ArrowDown" ? 1 : -1)));
      mark();
      shown[hi]?.scrollIntoView({ block: "nearest" });
    } else if (e.key === "Enter") {
      e.preventDefault();
      if (shown[hi]) pick(shown[hi].dataset.font);
    } else if (e.key === "Escape") {
      e.preventDefault();
      e.stopPropagation();
      close();
      btn.focus();
    }
  };
  filter.onblur = () => setTimeout(() => { if (!el.contains(document.activeElement)) close(); }, 0);
  label();
  const api = {
    el,
    get value() { return value; },
    set value(v) { value = v || ""; label(); },
    setList(l) {
      names = l.slice();
      if (value && !names.includes(value)) names.push(value);
      if (!pop.hidden) build();
    },
    async refresh(again = false) { api.setList(await boardFonts(again)); },
  };
  return api;
}
