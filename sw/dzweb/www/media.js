// media.js - images, movies and sprites on the board. File transfer (upload,
// download, delete) uses dzweb's HTTP /media; drawing and playback use OSC.
import * as net from "./net.js";
import { h, card, row, hexToRgb, toast } from "./ui.js";

const KINDS = {
  img: { title: "Images", dir: "/home/ebaz/img", accept: "image/*,.ppm" },
  movies: { title: "Movies", dir: "/home/ebaz/movies", accept: "video/*,.mkv,.ts" },
};
let lists = {}, uploads = {}, freeEl, spriteId, slotSel, info;
let state = { free: -1, keep: 0, max: 0, img: [], movies: [] };
let queue = Promise.resolve(); // one upload at a time: the SD card is slow

const mb = (n) => (n >= 1 << 30 ? `${(n / (1 << 30)).toFixed(2)} GB` : `${(n / (1 << 20)).toFixed(1)} MB`);
const url = (kind, name) => `${net.httpBase()}/media/${kind}/${encodeURIComponent(name)}`;

// the board accepts A-Z a-z 0-9 . _ - only (same rule as debazd)
function cleanName(n) {
  n = n.replace(/[^A-Za-z0-9._-]+/g, "_").replace(/^[._]+/, "").replace(/\.{2,}/g, ".");
  return n.slice(-96) || "file";
}

function slotPicker() {
  return h("select", {}, [...Array(12).keys()].map((i) => h("option", { value: i, selected: i === 6 }, `slot ${i}`)));
}

async function refresh() {
  try {
    const r = await fetch(`${net.httpBase()}/media`, { cache: "no-store" });
    if (!r.ok) throw new Error(r.status);
    state = await r.json();
  } catch {
    freeEl.textContent = "file list not available (old dzweb?)";
    return;
  }
  freeEl.textContent = state.free >= 0 ? `${mb(state.free)} free on the board` : "";
  freeEl.className = "hint" + (state.free >= 0 && state.free < state.keep * 3 ? " warn-text" : "");
  for (const kind of Object.keys(KINDS)) draw(kind);
}

function actions(kind, name) {
  if (kind === "img")
    return [
      h("button", { title: "load as sprite #", onclick: () => {
        net.msg(`/sprite/${spriteId.value}/load`, name);
        setTimeout(() => net.msg(`/sprite/${spriteId.value}`), 1500);
      } }, "→ sprite"),
      h("button", { title: "draw into the target slot", onclick: () => net.msg(`/img/${slotSel.value}/load`, name) }, "draw"),
    ];
  return [h("button.primary", { title: "play into the target slot",
    onclick: () => net.msg(`/movie/${slotSel.value}/play`, name) }, "play")];
}

function draw(kind) {
  const files = [...(state[kind] || [])].sort((a, b) => a.name.localeCompare(b.name));
  lists[kind].replaceChildren(...files.map((f) => h("div.item", {},
    kind === "img" ? h("img", { src: url(kind, f.name) + `?t=${f.mtime}`, loading: "lazy", alt: "" }) : null,
    h("span", { title: f.name }, f.name),
    h("span.size", {}, mb(f.size)),
    ...actions(kind, f.name),
    h("a.button", { href: url(kind, f.name) + "?dl", download: f.name, title: "download to this computer" }, "save"),
    h("button.danger", { title: "delete from the board", onclick: () => remove(kind, f.name) }, "✕"))));
  if (!files.length) lists[kind].append(h("p.hint", {}, `No files in ${KINDS[kind].dir}.`));
}

async function remove(kind, name) {
  if (!confirm(`Delete ${name} from the board?`)) return;
  const r = await fetch(url(kind, name), { method: "DELETE" }).catch(() => null);
  toast(r && r.ok ? `${name} deleted` : `delete failed: ${r ? await r.text() : "no connection"}`, !(r && r.ok));
  refresh();
}

// XMLHttpRequest, not fetch: fetch gives no upload progress
function put(kind, name, file, bar, label) {
  return new Promise((resolve) => {
    const x = new XMLHttpRequest();
    const t0 = performance.now();
    x.open("PUT", url(kind, name));
    x.upload.onprogress = (e) => {
      if (!e.lengthComputable) return;
      const s = (performance.now() - t0) / 1000;
      bar.style.width = `${(e.loaded / e.total) * 100}%`;
      label.textContent = `${Math.round((e.loaded / e.total) * 100)}% · ${mb(e.loaded / Math.max(s, 0.1))}/s`;
    };
    x.onload = () => resolve({ ok: x.status === 201, msg: x.responseText.trim() || String(x.status) });
    x.onerror = () => resolve({ ok: false, msg: "connection failed (no space, or the board went away)" });
    x.send(file);
  });
}

function upload(kind, files) {
  for (const file of files) {
    const name = cleanName(file.name);
    const bar = h("i");
    const label = h("span.hint", {}, "waiting");
    const line = h("div.up", {}, h("span", { title: file.name }, name === file.name ? name : `${file.name} → ${name}`),
      label, h("div.meter", {}, bar));
    uploads[kind].append(line);
    queue = queue.then(async () => {
      const exists = (state[kind] || []).some((f) => f.name === name);
      let res;
      if (exists && !confirm(`${name} is already on the board. Replace it?`)) res = { ok: false, msg: "skipped" };
      else if (state.free >= 0 && file.size > state.free - state.keep)
        res = { ok: false, msg: `not enough space (${mb(state.free)} free, ${mb(state.keep)} must stay free)` };
      else if (state.max && file.size > state.max) res = { ok: false, msg: `larger than ${mb(state.max)}` };
      else res = await put(kind, name, file, bar, label);
      label.textContent = res.ok ? "done" : res.msg;
      line.classList.toggle("err", !res.ok);
      if (res.ok) setTimeout(() => line.remove(), 3000);
      await refresh();
    });
  }
}

function dropZone(kind) {
  const input = h("input", { type: "file", multiple: true, accept: KINDS[kind].accept,
    onchange: () => { upload(kind, [...input.files]); input.value = ""; } });
  const zone = h("label.drop", {}, input, "Drop files here, or click to choose (upload to the board)");
  zone.addEventListener("dragover", (e) => { e.preventDefault(); zone.classList.add("over"); });
  zone.addEventListener("dragleave", () => zone.classList.remove("over"));
  zone.addEventListener("drop", (e) => {
    e.preventDefault();
    zone.classList.remove("over");
    upload(kind, [...e.dataTransfer.files]);
  });
  return zone;
}

export function init(root) {
  for (const kind of Object.keys(KINDS)) {
    lists[kind] = h("div.list");
    uploads[kind] = h("div");
  }
  freeEl = h("span.hint", {}, "");
  spriteId = h("input", { type: "number", min: 0, max: 63, value: 0 });
  slotSel = slotPicker();
  info = h("span.hint", {}, "");
  const color = h("input", { type: "color", value: "#ffffff" });
  const text = h("input", { type: "text", value: "feedback" });
  const size = h("input", { type: "number", min: 8, max: 400, value: 96, title: "TrueType size in px" });
  const scale = h("input", { type: "number", min: 1, max: 16, value: 4, title: "pixel font scale" });
  const key = h("input", { type: "color", value: "#ffffff" });
  const tol = h("input", { type: "number", min: 0, max: 255, value: 40, title: "tolerance" });

  root.append(
    h("div.row", {}, h("label", {}, "target slot"), slotSel,
      h("label", {}, "sprite #"), spriteId,
      h("button", { onclick: refresh }, "Refresh lists"), freeEl),
    h("div.grid", {},
      card(`${KINDS.img.title} (${KINDS.img.dir})`, dropZone("img"), uploads.img, lists.img),
      card(`${KINDS.movies.title} (${KINDS.movies.dir})`, dropZone("movies"), uploads.movies, lists.movies,
        row(null, h("button", { onclick: () => net.msg(`/movie/${slotSel.value}/stop`) }, "Stop movie in slot")),
        h("p.hint", {}, "Movies decode on the board (about 12–20 fps per 720p stream). " +
          "File names change to A-Z a-z 0-9 . _ - on upload.")),
      card("Sprites",
        row("colour", color, text),
        row(null,
          h("button", { onclick: () => { const [r, g, b] = hexToRgb(color.value);
            net.msg(`/sprite/${spriteId.value}/ttf`, r, g, b, parseInt(size.value), text.value);
            setTimeout(() => net.msg(`/sprite/${spriteId.value}`), 300); } }, "TrueType → sprite"), size),
        row(null,
          h("button", { onclick: () => { const [r, g, b] = hexToRgb(color.value);
            net.msg(`/sprite/${spriteId.value}/text`, r, g, b, text.value, parseInt(scale.value), 16);
            setTimeout(() => net.msg(`/sprite/${spriteId.value}`), 300); } }, "Pixel text → sprite"), scale),
        row("key out", key, tol, h("button", { onclick: () => { const [r, g, b] = hexToRgb(key.value);
          net.msg(`/sprite/${spriteId.value}/key`, r, g, b, parseInt(tol.value)); toast("colour keyed"); } }, "Key")),
        row(null,
          h("button", { onclick: () => net.msg(`/sprite/${spriteId.value}`) }, "Size?"),
          h("button.danger", { onclick: () => net.msg(`/sprite/${spriteId.value}/free`) }, "Free"), info),
        h("p.hint", {}, "Place sprites with the Paint tab's sprite tool, or animate them with an LFO " +
          "target like /sprite/0/draw 6 640 360 1 $f2."))));
  net.on("/sprite", (m) => {
    if (/^\/sprite\/\d+$/.test(m.path)) info.textContent = `${m.path}: ${m.args[0]} × ${m.args[1]} px`;
  });
}

export function connected() {
  refresh();
}

export function show() {
  refresh();
}
