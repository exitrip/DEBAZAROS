// media.js - images, movies, audio files and sprites on the board. File transfer (upload,
// download, delete) uses dzweb's HTTP /media; drawing and playback use OSC.
import * as sprites from "./sprites.js";
import * as net from "./net.js";
import { h, card, row, hexToRgb, toast, store } from "./ui.js";
import * as movfx from "./movfx.js";
import * as anim from "./anim.js";
import { playlistCard } from "./playlist.js";

const KINDS = {
  img: { title: "Images", dir: "/media/debaz/img", accept: "image/*,.ppm" },
  movies: { title: "Movies", dir: "/media/debaz/movies", accept: "video/*,.mkv,.ts" },
  audio: { title: "Audio", dir: "/media/debaz/audio", accept: "audio/*,.wav,.mp3,.flac,.ogg,.mkv" },
};
let lists = {}, uploads = {}, freeEl, slotSel, movieAudio, audioOut, movX, movY;
let state = { free: -1, keep: 0, max: 0, img: [], movies: [], audio: [] };
let queue = Promise.resolve(); // one upload at a time: the SD card is slow

// files picked for the playlist (playlist.js), in click order; shift-click = a range
let picked = [], lastPick = null;
const isPicked = (kind, name) => picked.some((p) => p.kind === kind && p.name === name);
function pick(kind, files, i, on, shift) {
  const range = shift && lastPick && lastPick.kind === kind ? [Math.min(lastPick.i, i), Math.max(lastPick.i, i)] : [i, i];
  for (let k = range[0]; k <= range[1]; k++) {
    const name = files[k].name;
    picked = picked.filter((p) => !(p.kind === kind && p.name === name));
    if (on) picked.push({ kind, name });
  }
  lastPick = { kind, i };
  draw(kind);
}

const mb = (n) => (n >= 1 << 30 ? `${(n / (1 << 30)).toFixed(2)} GB` : `${(n / (1 << 20)).toFixed(1)} MB`);
const url = (kind, name) => `${net.httpBase()}/media/${kind}/${encodeURIComponent(name)}`;

// the board accepts A-Z a-z 0-9 . _ - only (same rule as debazd)
function cleanName(n) {
  n = n.replace(/[^A-Za-z0-9._-]+/g, "_").replace(/^[._]+/, "").replace(/\.{2,}/g, ".");
  return n.slice(-96) || "file";
}

// default slot 0 (display 0's home): a movie in a slot no display shows
// still costs CPU (2026-10-28: a hidden movie in slot 6 took ~55 % of a core)
const SLOT_NOTE = { 0: "display 0", 2: "display 1", 4: "capture", 11: "black" };
function slotPicker() {
  return h("select", { title: "only slots a display shows are visible: 0 = display 0, 2 = display 1 at home\n" +
      "the <s> of /movie/<s>/..., /img/<s>/load, /ascii/<s>/... (/disp/<d> shows which slot a display shows)" },
    [...Array(12).keys()].map((i) => h("option", { value: i, selected: i === 0 },
      `slot ${i}${SLOT_NOTE[i] ? ` (${SLOT_NOTE[i]})` : ""}`)));
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
      h("button.to-sprite", { title: "load it as the selected sprite (Sprites card: click a number there)\n/sprite/<id>/load \"<file>\"",
        onclick: () => toSprite(name) }, `→ sprite #${sprites.selected()}`),
      h("button", { title: "draw into the target slot\n/img/<slot>/load \"<file>\"", onclick: () => net.msg(`/img/${slotSel.value}/load`, name) }, "draw"),
    ];
  if (kind === "audio")
    return [h("button.primary", { title: "play on the output chosen below\n/audio/play <out> \"<file>\" 0",
      onclick: () => net.msg("/audio/play", parseInt(audioOut.value), name, 0) }, "play")];
  return [h("button.primary", { title: "play into the target slot\n/movie/<slot>/play \"<file>\" 0 <audio>  (0 = the file's rate)",
    onclick: () => net.msg(`/movie/${slotSel.value}/play`, name, 0, parseInt(movieAudio.value)) }, "play")];
}

// "→ sprite": into the selected number, then (advance) on to the next empty one
function toSprite(name) {
  const id = sprites.selected();
  sprites.loadFile(id, name);
  toast(`${name} → sprite #${id}`);
  if (store.get("sprite.advance", false)) {
    const next = sprites.nextFree(id + 1);
    if (next >= 0 && next !== id) sprites.select(next);
  }
}

function draw(kind) {
  const files = [...(state[kind] || [])].sort((a, b) => a.name.localeCompare(b.name));
  lists[kind].replaceChildren(...files.map((f, i) => h("div.item", {},
    h("input", { type: "checkbox", checked: isPicked(kind, f.name), title: "pick for the playlist (Playlist → scene card; " +
      `#${picked.findIndex((p) => p.kind === kind && p.name === f.name) + 1 || "–"} in the order; shift-click: a range)`,
      onclick: (e) => pick(kind, files, i, e.target.checked, e.shiftKey) }),
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
    title: `upload: dzweb HTTP PUT /media/${kind}/<file> (not OSC)`,
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
  slotSel = slotPicker();
  movX = h("input", { type: "number", min: 0, max: 1918, step: 2, value: 0, style: "width:76px", title: "x (even) of /movie/<slot>/pos x y" });
  movY = h("input", { type: "number", min: 0, max: 1079, step: 1, value: 0, style: "width:76px", title: "y of /movie/<slot>/pos x y" });
  const posLoad = async () => {
    const r = await net.ask(net.message(`/movie/${slotSel.value}/pos`), (m) => m.path === `/movie/${slotSel.value}/pos`);
    if (r) [movX.value, movY.value] = r.args;
  };
  slotSel.addEventListener("change", posLoad);
  slotSel.addEventListener("change", fxRefresh);
  movieAudio = h("select", { title: "where the movie's own audio track plays\n" +
      "the <audio> of /movie/<s>/play \"<file>\" <fps> <audio>: bits 1 HDMI 0, 2 HDMI 1, 4 I2S" },
    h("option", { value: 0 }, "no audio"), h("option", { value: 1 }, "HDMI 0"),
    h("option", { value: 2 }, "HDMI 1"), h("option", { value: 3 }, "HDMI 0 + 1"),
    h("option", { value: 4 }, "I2S"));
  audioOut = h("select", { title: "/audio/play <out> <file>: the output" }, h("option", { value: 0 }, "HDMI 0"), h("option", { value: 1 }, "HDMI 1"),
    h("option", { value: 2 }, "I2S"));
  const color = h("input", { type: "color", value: "#ffffff", title: "/sprite/<id>/ttf|text <r g b> ..." });
  const text = h("input", { type: "text", value: "feedback", title: "/sprite/<id>/ttf r g b size \"<text>\"" });
  const size = h("input", { type: "number", min: 8, max: 400, value: 96, title: "TrueType size in px\n/sprite/<id>/ttf r g b <size> ..." });
  const scale = h("input", { type: "number", min: 1, max: 16, value: 4, title: "pixel font scale\n/sprite/<id>/text r g b \"text\" <scale>" });
  const key = h("input", { type: "color", value: "#ffffff", title: "/sprite/<id>/key <r g b> [tol]" });
  const tol = h("input", { type: "number", min: 0, max: 255, value: 40, title: "tolerance\n/sprite/<id>/key r g b <tol>" });

  root.append(
    h("div.row", {}, h("label", {}, "target slot"), slotSel,
      h("button", { title: "dzweb HTTP GET /media (file lists, free space)", onclick: refresh }, "Refresh lists"), freeEl),
    h("div.grid", {},
      card(`${KINDS.img.title} (${KINDS.img.dir})`, dropZone("img"), uploads.img, lists.img,
        h("p.hint", {}, "→ sprite loads the image as the sprite selected in the Sprites card (PNG transparency kept).")),
      spriteCard({ color, text, size, scale, key, tol }),
      card(`${KINDS.movies.title} (${KINDS.movies.dir})`, dropZone("movies"), uploads.movies, lists.movies,
        row("movie audio", movieAudio),
        row(null, h("button", { title: "/movie/<slot>/stop", onclick: () => net.msg(`/movie/${slotSel.value}/stop`) }, "Stop movie in slot")),
        row("position", movX, movY, h("button", { title: "/movie/<slot>/pos x y: the movie's top left in the slot\n" +
          "(not moved in: near the edge, or taller than 1080, it runs on into the next slot;\n" +
          "wider than 1920 does not play; a playing movie restarts)",
          onclick: () => net.msg(`/movie/${slotSel.value}/pos`, Number(movX.value) | 0, Number(movY.value) | 0) }, "Set")),
        h("p.hint", {}, "Movies decode on the board (about 12–20 fps per 720p stream) and play at their own size " +
          "(never scaled to the output: scaling costs more CPU than the decode; at most 1920 wide, and above 720p the decode " +
          "is too slow) at the position in the slot; " +
          "a display shows a window of the slot (Wall tab). File names change to A-Z a-z 0-9 . _ - on upload.")),
      anim.playerCard(),
      movfx.moshCard(() => slotSel.value),
      movfx.asciiCard(() => slotSel.value, slotPicker),
      movfx.slitCard(() => slotSel.value, slotPicker),
      card(`${KINDS.audio.title} (${KINDS.audio.dir})`, dropZone("audio"), uploads.audio, lists.audio,
        row("play on", audioOut, h("button", { title: "/audio/stop", onclick: () => net.msg("/audio/stop") }, "Stop all")),
        h("p.hint", {}, "Recordings from the Audio tab land here. HDMI 0 + 1 for a movie = the same " +
          "audio on both outputs; the Audio tab's sources choose what each output plays.")),
      playlistCard(() => picked, () => { picked = []; lastPick = null; for (const k of Object.keys(KINDS)) draw(k); },
        () => parseInt(movieAudio.value), () => parseInt(audioOut.value))));
  sprites.onChange(() => {			// the image rows name the target number
    for (const b of lists.img.querySelectorAll("button.to-sprite")) b.textContent = `→ sprite #${sprites.selected()}`;
  });
}

// the Sprites card: the palette (what each number holds; click = select),
// then everything that acts on the selected number
function spriteCard({ color, text, size, scale, key, tol }) {
  const cur = h("div.hint", {}, "");
  const num = h("input", { type: "number", min: 0, max: sprites.N - 1, value: sprites.selected(), style: "width:70px",
    title: "the selected sprite number (0-63): any number, also an empty one", onchange: () => sprites.select(num.value) });
  const adv = h("input", { type: "checkbox", checked: store.get("sprite.advance", false),
    onchange: () => store.set("sprite.advance", adv.checked) });
  const sel = () => sprites.selected();
  const show = () => { num.value = sel(); cur.textContent = sprites.describe(sel()); };
  sprites.onChange(show);
  show();
  return card("Sprites",
    h("p.hint", {}, "1. click a number below (or type one)  2. → sprite on an image in the Images card, or make text here  " +
      "3. draw it: Paint tab ◰ sprite tool (the same selected number), an LFO target, or a Lua script."),
    sprites.palette(),
    row("selected", num, cur),
    row(null, h("label", { title: "after → sprite, select the next empty number (load several images in a row)" }, adv, " then the next empty number"),
      h("button.ghost", { title: "/sprite/list: what every number holds", onclick: sprites.refresh }, "Refresh")),
    row("text", color, text),
    row(null,
      h("button", { title: "/sprite/<id>/ttf r g b <size> \"text\"", onclick: () => { const [r, g, b] = hexToRgb(color.value);
        sprites.op(sel(), "ttf", r, g, b, parseInt(size.value), text.value); } }, "TrueType → sprite"), size,
      h("button", { title: "/sprite/<id>/text r g b \"text\" <scale> 16", onclick: () => { const [r, g, b] = hexToRgb(color.value);
        sprites.op(sel(), "text", r, g, b, text.value, parseInt(scale.value), 16); } }, "Pixel text → sprite"), scale),
    row("key out", key, tol, h("button", { title: "/sprite/<id>/key r g b <tol>: that colour becomes transparent",
      onclick: () => { const [r, g, b] = hexToRgb(key.value); sprites.op(sel(), "key", r, g, b, parseInt(tol.value)); toast("colour keyed"); } }, "Key"),
      h("button.danger", { title: "/sprite/<id>/free", onclick: () => sprites.op(sel(), "free") }, "Free")),
    h("p.hint", {}, "An LFO target moves a sprite: /sprite/0/draw 6 640 360 1 $f2 (slot x y scale angle alpha). " +
      "Lua: the sprite-bounce example."));
}

function fxRefresh() {
  movfx.moshRefresh(slotSel.value);
  movfx.asciiRefresh(slotSel.value);
  movfx.slitRefresh(slotSel.value);
}

export function connected() {
  refresh();
  fxRefresh();
  anim.playerShow();
}

export function show() {
  refresh();
  fxRefresh();
  anim.playerShow();
}
