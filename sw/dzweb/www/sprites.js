// sprites.js - the board's sprites for the Media and Paint tabs (2026-11-20):
// what each sprite number holds (/sprite/list, /sprite/<id> -> w h src), a
// thumbnail for it, and ONE selected sprite number that both tabs use (kept
// in this browser). src from debazd: "file:<name>", "grab:<slot> x y w h",
// "text:#rrggbb:<text>", "ttf:#rrggbb:<text>", " +key" after a key.
import * as net from "./net.js";
import { h, store, toast } from "./ui.js";

export const N = 64;
let list = new Map();			// id -> { w, h, src }
let seen = null;			// ids seen since a /sprite/list was sent
let sel = Math.max(0, Math.min(N - 1, Number(store.get("sprite.sel", 0)) || 0));
const subs = new Set();

const notify = () => { for (const fn of subs) fn(); };
export const onChange = (fn) => { subs.add(fn); return () => subs.delete(fn); };
export const selected = () => sel;
export const info = (id) => list.get(id);
export const loaded = () => [...list.keys()].sort((a, b) => a - b);

export function select(id) {
  id = Math.max(0, Math.min(N - 1, Number(id) | 0));
  if (id === sel) return;
  sel = id;
  store.set("sprite.sel", sel);
  notify();
}

// the first number from `from` on that holds nothing (wraps; -1 = all full)
export function nextFree(from = 0) {
  for (let k = 0; k < N; k++) {
    const id = (from + k) % N;
    if (!list.has(id)) return id;
  }
  return -1;
}

export function refresh() {
  seen = new Set();
  net.msg("/sprite/list");
}

const query = (id) => net.message(`/sprite/${id}`);

// load an image file into sprite `id`; the query in the same bundle runs after the load
export function loadFile(id, name) {
  net.send(net.bundle(net.message(`/sprite/${id}/load`, name), query(id)));
}
// any /sprite/<id>/... operation, then the sprite's new state
export function op(id, verb, ...args) {
  net.send(net.bundle(net.message(`/sprite/${id}/${verb}`, ...args), query(id)));
}

net.on("/sprite", (m) => {
  const mm = m.path.match(/^\/sprite\/(\d+)$/);
  if (mm && m.args.length >= 2) {
    const id = Number(mm[1]);
    list.set(id, { w: m.args[0], h: m.args[1], src: m.args[2] || "" });
    if (seen) seen.add(id);
    notify();
  } else if (m.path === "/sprite/list" && seen) {
    for (const id of [...list.keys()]) if (!seen.has(id)) list.delete(id);
    seen = null;
    notify();
  }
});
net.on("/error", (m) => {
  const mm = String(m.args[1] || "").match(/^\/sprite\/(\d+)(\/load)?$/);
  if (!mm) return;
  if (m.args[0] === "no such sprite") { list.delete(Number(mm[1])); notify(); }
  else if (mm[2]) toast(`sprite #${mm[1]}: load failed`, true);
});
net.onConnect(refresh);

// what a src string means, for hover texts
export function describe(id) {
  const i = list.get(id);
  if (!i) return `sprite #${id}: empty`;
  const key = / \+key$/.test(i.src) ? " (colour keyed)" : "";
  const src = i.src.replace(/ \+key$/, "");
  const [kind, ...rest] = src.split(":");
  const what = kind === "file" ? rest.join(":") : kind === "grab" ? `grab of slot ${rest.join(":")}`
    : kind === "text" || kind === "ttf" ? `${kind} "${rest.slice(1).join(":")}"` : src || "?";
  return `sprite #${id}: ${what}, ${i.w} × ${i.h} px${key}`;
}

// a thumbnail of sprite `id` (px square): the image file, the text, or a label
export function thumb(id, px = 56) {
  const i = list.get(id);
  const box = h("div.sthumb", { title: describe(id), style: `width:${px}px;height:${px}px` });
  if (!i) { box.append(h("span.sthumb-empty", {}, "empty")); return box; }
  const src = i.src.replace(/ \+key$/, "");
  const [kind, ...rest] = src.split(":");
  if (kind === "file") {
    box.append(h("img", { src: `${net.httpBase()}/media/img/${encodeURIComponent(rest.join(":"))}`, alt: "", loading: "lazy" }));
  } else if (kind === "text" || kind === "ttf") {
    const col = rest[0] || "#ffffff", txt = rest.slice(1).join(":");
    box.append(h("span.sthumb-text", { style: `color:${col};font-family:${kind === "text" ? "var(--mono)" : "inherit"}` }, txt));
  } else {
    box.append(h("span.sthumb-empty", {}, kind === "grab" ? `grab\n${rest.join(":")}` : src));
  }
  return box;
}

// the image files on the board (for a picker)
export async function imageFiles() {
  const r = await fetch(`${net.httpBase()}/media`, { cache: "no-store" }).catch(() => null);
  if (!r || !r.ok) return [];
  const j = await r.json();
  return (j.img || []).map((f) => f.name).sort((a, b) => a.localeCompare(b));
}

// the palette: every loaded sprite plus a few empty numbers; click = select
export function palette() {
  const grid = h("div.spal");
  const render = () => {
    const ids = new Set(loaded());
    ids.add(sel);
    for (let id = nextFree(0), k = 0; id >= 0 && k < 3; id = nextFree(id + 1), k++) ids.add(id);
    grid.replaceChildren(...[...ids].sort((a, b) => a - b).map((id) => {
      const cell = h("button.spal-cell" + (id === sel ? ".on" : ""), { title: describe(id) + "\nclick: select", onclick: () => select(id) },
        thumb(id, 52), h("span.spal-id", {}, `#${id}`));
      return cell;
    }));
  };
  onChange(render);
  render();
  return grid;
}
