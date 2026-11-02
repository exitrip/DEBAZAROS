// anim.js - image sequences (debazd anim.c, /anim/...): the player card of the
// Media tab (one row per display: two sequences can run at once) and the
// "Save frame" card of the Paint tab (stop motion / drawn animation: each
// press adds the next fNNNNN.jpg to a folder in /media/debaz/anim).
import * as net from "./net.js";
import { h, card, row, toast, store } from "./ui.js";

const MODES = ["loop", "once", "pingpong", "random"];
let folders = []; // [{ name, frames, kb }]
const folderListeners = new Set();

export async function loadFolders() {
  const items = await net.collect(net.message("/anim/list"), "/anim/folder", "/anim/folder/end");
  folders = items.map(([name, frames, kb]) => ({ name, frames, kb })).sort((a, b) => a.name.localeCompare(b.name));
  for (const fn of folderListeners) fn();
  return folders;
}

const status = (d) => net.ask(net.message(`/anim/${d}`), (m) => m.path === `/anim/${d}`, 800);

// ---- player (Media tab) ----

function playerRow(d) {
  const p = `/anim/${d}`;
  const sel = h("select", { title: `${p}/play "<folder>" [fps]`, style: "max-width:220px" });
  const fillSel = () => {
    const was = sel.value;
    sel.replaceChildren(...(folders.length ? folders.map((f) =>
      h("option", { value: f.name, selected: f.name === was }, `${f.name} (${f.frames})`)) :
      [h("option", { value: "" }, "no folders")]));
  };
  folderListeners.add(fillSel);
  const fps = h("input", { type: "number", min: 0.1, max: 120, step: 0.5, value: 12, style: "width:70px",
    title: `${p}/fps <f>: sequence frames per second`, onchange: () => net.msg(`${p}/fps`, net.float(+fps.value)) });
  const mode = h("select", { title: `${p}/mode loop|once|pingpong|random`, onchange: () => net.msg(`${p}/mode`, mode.value) },
    MODES.map((m) => h("option", { value: m }, m)));
  const late = h("select", { title: `${p}/late hold|skip: hold = wait for a late frame (no frame lost), skip = keep time`,
    onchange: () => net.msg(`${p}/late`, late.value) }, ["hold", "skip"].map((m) => h("option", { value: m }, m)));
  const scrub = h("input", { type: "range", min: 0, max: 0, value: 0, style: "width:220px",
    title: `${p}/frame <i>: go to a frame (the player pauses while you drag)` });
  let dragging = false;
  scrub.oninput = () => {
    dragging = true;
    net.throttled(`${p}/frame`, () => net.bundle(net.message(`${p}/pause`, 1), net.message(`${p}/frame`, +scrub.value)));
  };
  scrub.onchange = () => { dragging = false; };
  const st = h("span.hint", {}, "");
  const btn = (label, title, fn) => h("button", { title, onclick: fn }, label);
  const refresh = async () => {
    const m = await status(d);
    if (!m) { st.textContent = "no reply"; return; }
    const [name, n, pos, f, real, lateN, dec, decMax, state, file, resident, slot] = m.args;
    if (!dragging) {
      scrub.max = Math.max(0, n - 1);
      if (pos >= 0) scrub.value = pos;
    }
    if (document.activeElement !== fps) fps.value = +f.toFixed(2);
    if (name && document.activeElement !== sel && [...sel.options].some((o) => o.value === name)) sel.value = name;
    st.textContent = name ? `${state} ${name} ${pos + 1}/${n} ${file} · ${real.toFixed(1)} fps · ` +
      `decode ${dec.toFixed(0)} ms (max ${decMax.toFixed(0)}) · late ${lateN}${resident ? " · resident" : ""} · slot ${slot}` :
      "stopped";
  };
  return {
    refresh,
    folder: () => sel.value,
    el: h("div.anim-row", {},
      row(`display ${d}`, sel,
        btn("Play", `${p}/play "<folder>" <fps>`, () => { if (sel.value) net.msg(`${p}/play`, sel.value, net.float(+fps.value)); setTimeout(refresh, 300); }),
        btn("Pause", `${p}/pause (toggle)`, () => { net.msg(`${p}/pause`); setTimeout(refresh, 100); }),
        btn("◀", `${p}/step -1 (pauses)`, () => { net.msg(`${p}/step`, -1); setTimeout(refresh, 100); }),
        btn("▶", `${p}/step 1 (pauses)`, () => { net.msg(`${p}/step`, 1); setTimeout(refresh, 100); }),
        btn("Stop", `${p}/stop: back to what the display showed before`, () => { net.msg(`${p}/stop`); setTimeout(refresh, 100); })),
      row("fps", fps, h("span.hint", {}, "mode"), mode, h("span.hint", {}, "late"), late),
      row("frame", scrub),
      st),
  };
}

let rows = [];
let timer = null;
let playerEl = null;

// ---- add a sequence from the browser: files or a whole folder -> /media/anim/<folder>/ ----

const natural = (a, b) => a.localeCompare(b, undefined, { numeric: true, sensitivity: "base" });
const imageFile = (f) => /\.(jpe?g|png|webp|gif|bmp|avif)$/i.test(f.name);

// all files below a dropped folder (DataTransferItem entries)
async function filesOf(entry, out = []) {
  if (entry.isFile) {
    out.push(await new Promise((r, j) => entry.file(r, j)));
  } else if (entry.isDirectory) {
    const rd = entry.createReader();
    for (;;) {
      const batch = await new Promise((r, j) => rd.readEntries(r, j));
      if (!batch.length) break;
      for (const e of batch) await filesOf(e, out);
    }
  }
  return out;
}

// fit into w x h (never enlarged) and encode as JPEG
async function reencode(file, w, hh, q) {
  const bm = await createImageBitmap(file);
  const k = Math.min(1, w / bm.width, hh / bm.height);
  const cw = Math.max(1, Math.round(bm.width * k)), ch = Math.max(1, Math.round(bm.height * k));
  const cv = document.createElement("canvas");
  cv.width = cw; cv.height = ch;
  const c = cv.getContext("2d");
  c.imageSmoothingQuality = "high";
  c.drawImage(bm, 0, 0, cw, ch);
  bm.close?.();
  return new Promise((r) => cv.toBlob(r, "image/jpeg", q / 100));
}

function uploadPanel() {
  const st = { convert: true, rename: true, q: 85, ...store.get("animup", {}) };
  const keep = () => store.set("animup", st);
  const name = h("input", { type: "text", placeholder: "folder name", style: "width:150px",
    title: "folder in /media/debaz/anim (A-Z a-z 0-9 . _ -); a chosen folder fills it in" });
  const clean = (n) => n.replace(/[^A-Za-z0-9._-]+/g, "_").replace(/^[._]+/, "").slice(0, 90);
  const conv = h("input", { type: "checkbox", checked: st.convert, onchange: () => { st.convert = conv.checked; keep(); } });
  const ren = h("input", { type: "checkbox", checked: st.rename, onchange: () => { st.rename = ren.checked; keep(); } });
  const qOut = h("span.hint", {}, String(st.q));
  const q = h("input.big-range", { type: "range", min: 40, max: 100, value: st.q, style: "width:110px",
    title: "JPEG quality of the converted frames", oninput: () => { st.q = +q.value; qOut.textContent = st.q; keep(); } });
  const prog = h("div.meter", {}, h("i"));
  const msg = h("span.hint", {}, "");
  let stop = false;
  const go = async (files, dirName) => {
    files = files.filter(imageFile).sort((a, b) => natural(a.webkitRelativePath || a.name, b.webkitRelativePath || b.name));
    if (!files.length) return toast("no image files", true);
    if (!name.value && dirName) name.value = clean(dirName);
    const folder = clean(name.value || "");
    if (!folder) return toast("folder name first", true);
    name.value = folder;
    let w = 1280, hh = 720;
    const vm = await net.ask(net.message("/video/mode"), (m) => m.path === "/video/mode" && typeof m.args[0] === "number", 800);
    if (vm) [w, hh] = vm.args;
    // numbering continues after frames already in the folder
    let next = 1;
    if (folders.some((f) => f.name === folder)) {
      if (!confirm(`${folder} exists: add ${files.length} frames after its frames?`)) return;
      const sh = await getSheet(folder);
      for (const m of (sh?.text || "").matchAll(/^f(\d+)\.jpg/gm)) next = Math.max(next, +m[1] + 1);
    }
    stop = false;
    let bytes = 0, done = 0, failed = "";
    const t0 = performance.now();
    for (const f of files) {
      if (stop) break;
      let body = f, out = clean(f.name);
      try {
        if (st.convert || !/\.(jpe?g|png)$/i.test(f.name)) body = await reencode(f, w, hh, st.q);
        if (st.rename || body !== f) out = st.rename ? `f${String(next++).padStart(5, "0")}.jpg` : out.replace(/\.[^.]+$/, ".jpg");
        const r = await fetch(`${net.httpBase()}/media/anim/${encodeURIComponent(folder)}/${encodeURIComponent(out)}`, { method: "PUT", body });
        if (!r.ok) throw new Error(`${r.status} ${await r.text()}`);
      } catch (e) {
        failed = `${f.name}: ${e.message || e}`;
        break;
      }
      bytes += body.size;
      done++;
      prog.firstChild.style.width = `${(100 * done) / files.length}%`;
      msg.textContent = `${done}/${files.length} · ${(bytes / 1048576).toFixed(1)} MB · ${(bytes / 1024 / done).toFixed(0)} KB per frame · ` +
        `${((done * 1000) / (performance.now() - t0)).toFixed(1)} files/s`;
    }
    msg.textContent += done ? ` · ${playbackHint(bytes / done)}` : "";
    if (failed) { msg.textContent += ` · stopped: ${failed}`; toast(`stopped after ${done} frames: ${failed}`, true); }
    else toast(`${folder}: ${done} frames uploaded`);
    loadFolders();
  };
  const pickDir = h("input", { type: "file", multiple: true, webkitdirectory: true, style: "display:none",
    onchange: () => { const fs = [...pickDir.files]; go(fs, fs[0]?.webkitRelativePath.split("/")[0]); pickDir.value = ""; } });
  const pickFiles = h("input", { type: "file", multiple: true, accept: "image/*", style: "display:none",
    onchange: () => { go([...pickFiles.files]); pickFiles.value = ""; } });
  const zone = h("label.drop", {}, "Drop a folder or image files here");
  zone.addEventListener("dragover", (e) => { e.preventDefault(); zone.classList.add("over"); });
  zone.addEventListener("dragleave", () => zone.classList.remove("over"));
  zone.addEventListener("drop", async (e) => {
    e.preventDefault();
    zone.classList.remove("over");
    const items = [...e.dataTransfer.items].map((i) => i.webkitGetAsEntry?.()).filter(Boolean);
    const dir = items.find((x) => x.isDirectory);
    const files = [];
    for (const it of items) await filesOf(it, files);
    go(files, dir?.name);
  });
  return h("div.anim-up", {},
    h("h3", {}, "Add a sequence"),
    row("folder", name, h("button", { onclick: () => pickDir.click(), title: "choose a folder of frames" }, "Folder…"),
      h("button", { onclick: () => pickFiles.click(), title: "choose image files" }, "Files…"), pickDir, pickFiles),
    zone,
    row(null, h("label", {}, conv, " fit to the display + JPEG"), q, qOut),
    row(null, h("label", {}, ren, " rename f00001.jpg … (natural order of the names)")),
    row(null, prog, h("button", { title: "stop after the current file", onclick: () => { stop = true; } }, "Stop")),
    msg,
    h("p.hint", {}, "Fit converts in this browser before the upload: camera photos become display-size JPEGs " +
      "(fast playback). Off: .jpg / .png go as they are (other formats are always converted)."));
}

export function playerCard() {
  rows = [0, 1].map(playerRow);
  return playerEl = card("Image sequences (/media/debaz/anim)",
    ...rows.map((r) => r.el),
    row(null, h("button", { title: "/anim/list", onclick: loadFolders }, "Refresh folders"),
      h("button.danger", { title: "/anim/delete <folder>: the frames and timing.txt of the folder chosen for display 0", onclick: async () => {
        const f = rows[0].folder();
        if (!f || !confirm(`Delete the folder ${f} and all its frames on the board?`)) return;
        const m = await net.ask(net.message("/anim/delete", f), (m) => m.path === "/anim/deleted" || (m.path === "/error" && m.args[1] === "/anim/delete"), 4000);
        toast(m?.path === "/anim/deleted" ? `${f}: ${m.args[1]} frames deleted` : (m?.args[0] || "no reply"), m?.path !== "/anim/deleted");
        loadFolders();
      } }, "Delete folder (display 0's)")),
    uploadPanel(),
    h("p.hint", {}, "A folder of .jpg (or slow .png) frames, natural order (f2 before f10); an optional " +
      "timing.txt holds frames: \"file [hold]\" lines, \"# fps 12\". Two sequences (one per display) share " +
      "the two CPU cores: 720p JPEG of ~150 KB ≈ 20-30 fps alone, about half each with two. " +
      "Make folders in the Paint tab (Save frame) or with mkmedia."));
}

// status once a second while the card is on screen (tabs have no hide hook)
export function playerShow() {
  clearInterval(timer);
  loadFolders();
  const tick = () => {
    if (!playerEl?.offsetParent) { clearInterval(timer); timer = null; return; }
    rows.forEach((r) => r.refresh());
  };
  tick();
  timer = setInterval(tick, 1000);
}

// ---- timing sheet (timing.txt; /anim/sheet in parts of <= 4000 bytes) ----

export function getSheet(folder) {
  return new Promise((resolve) => {
    const parts = [];
    const offP = net.on("/anim/sheet/part", (m) => { if (m.args[0] === folder) parts[m.args[1]] = m.args[2]; });
    const offE = net.on("/anim/sheet/end", (m) => {
      if (m.args[0] !== folder) return;
      done({ text: parts.join(""), exists: !!m.args[1], entries: m.args[2], fps: m.args[3] });
    });
    const timer = setTimeout(() => done(null), 3000);
    function done(v) { clearTimeout(timer); offP(); offE(); resolve(v); }
    net.msg("/anim/sheet", folder);
  });
}

export async function putSheet(folder, text) {
  const chunks = [];
  for (let i = 0; i < text.length; i += 3000) chunks.push(text.slice(i, i + 3000));
  if (!chunks.length) chunks.push("");
  for (let k = 0; k < chunks.length - 1; k++) net.msg("/anim/sheet/put", folder, k, 0, chunks[k]);
  return net.ask(net.message("/anim/sheet/put", folder, chunks.length - 1, 1, chunks[chunks.length - 1]),
    (m) => (m.path === "/anim/sheet/saved" && m.args[0] === folder) ||
      (m.path === "/error" && m.args[1] === "/anim/sheet/put"), 4000);
}

// text <-> rows: "# fps n", "<file> [hold]"; other comment lines are kept at the top
function parseSheet(text) {
  const rows = [], notes = [];
  let fps = 0;
  for (const raw of text.split("\n")) {
    const line = raw.trim();
    if (!line) continue;
    const f = line.match(/^#\s*fps\s+([\d.]+)/i);
    if (f) { fps = +f[1]; continue; }
    if (line.startsWith("#")) { notes.push(line); continue; }
    const [file, hold] = line.split(/\s+/);
    rows.push({ file, hold: Math.max(1, parseInt(hold) || 1) });
  }
  return { rows, notes, fps };
}
function sheetText(rows, notes, fps) {
  return [...notes, `# fps ${fps}`, ...rows.map((r) => (r.hold > 1 ? `${r.file} ${r.hold}` : r.file))].join("\n") + "\n";
}

// the editor: one row per entry (thumbnail, file, hold), or the raw text
export async function openSheet(folder, onSaved) {
  const sh = await getSheet(folder);
  if (!sh) { toast(`no timing sheet reply for ${folder}`, true); return; }
  let { rows, notes, fps } = parseSheet(sh.text);
  fps = fps || sh.fps || 12;
  let raw = false;
  const fpsIn = h("input", { type: "number", min: 0.1, max: 120, step: 0.5, value: fps, style: "width:70px",
    title: "# fps: the rate when /play gives none", onchange: () => { fps = +fpsIn.value || 12; sum(); } });
  const summary = h("span.hint", {}, "");
  const list = h("div.sheet-list", {});
  const txt = h("textarea.sheet-raw", { spellcheck: false, rows: 18, style: "display:none" });
  const thumb = (file) => h("img", { loading: "lazy", alt: "", src: `${net.httpBase()}/media/anim/${encodeURIComponent(folder)}/${encodeURIComponent(file)}` });
  const sum = () => {
    const frames = rows.reduce((a, r) => a + r.hold, 0);
    summary.textContent = `${rows.length} entries · ${frames} frames · ${(frames / fps).toFixed(2)} s at ${fps} fps` +
      (sh.exists ? "" : " · no timing.txt yet (folder order)");
  };
  const draw = () => {
    list.replaceChildren(...rows.map((r, i) => {
      const hold = h("input", { type: "number", min: 1, max: 1000, value: r.hold, style: "width:60px",
        title: "hold: frames at the sequence rate (2 = on twos)", onchange: () => { r.hold = Math.max(1, parseInt(hold.value) || 1); sum(); } });
      const mv = (d) => () => { const j = i + d; if (j < 0 || j >= rows.length) return; [rows[i], rows[j]] = [rows[j], rows[i]]; draw(); };
      return h("div.sheet-row", {},
        h("span.hint", {}, String(i + 1)), thumb(r.file), h("span.sheet-file", {}, r.file), hold,
        h("button.ghost", { title: "earlier", onclick: mv(-1) }, "▲"),
        h("button.ghost", { title: "later", onclick: mv(1) }, "▼"),
        h("button.ghost", { title: "repeat this frame here", onclick: () => { rows.splice(i + 1, 0, { ...r }); draw(); } }, "⧉"),
        h("button.ghost", { title: "remove from the sheet (the file stays)", onclick: () => { rows.splice(i, 1); draw(); } }, "✕"));
    }));
    sum();
  };
  const toRaw = () => { txt.value = sheetText(rows, notes, fps); };
  const fromRaw = () => { ({ rows, notes, fps } = parseSheet(txt.value)); fps = fps || 12; fpsIn.value = fps; };
  const mode = h("button", { title: "edit timing.txt as text", onclick: () => {
    raw = !raw;
    if (raw) toRaw(); else { fromRaw(); draw(); }
    txt.style.display = raw ? "" : "none";
    list.style.display = raw ? "none" : "";
    mode.textContent = raw ? "Table" : "Text";
  } }, "Text");
  const save = async () => {
    if (raw) fromRaw();
    const m = await putSheet(folder, sheetText(rows, notes, fps));
    if (!m) toast("no reply from the board", true);
    else if (m.path === "/error") toast(m.args[0], true);
    else {
      toast(`timing.txt: ${m.args[1]} entries` + (m.args[2] ? `, ${m.args[2]} not in the folder (first: ${m.args[3]})` : ""), !!m.args[2]);
      sh.exists = true; sum(); onSaved?.();
    }
  };
  const folderOrder = async () => {
    if (!confirm(`Delete ${folder}/timing.txt? The folder order plays again (every file once).`)) return;
    const m = await putSheet(folder, "");
    if (m?.path === "/anim/sheet/saved") { const n = await getSheet(folder); ({ rows, notes, fps } = parseSheet(n.text)); sh.exists = false; draw(); onSaved?.(); }
  };
  const close = () => { dlg.close(); dlg.remove(); };
  const dlg = h("dialog.fxdlg.sheetdlg", { onclose: () => dlg.remove() },
    h("h2", {}, `Timing sheet: ${folder}`),
    row("fps", fpsIn, summary),
    list, txt,
    row(null, h("button.primary", { title: "/anim/sheet/put (writes timing.txt; a display that plays the folder reloads)", onclick: save }, "Save"),
      mode,
      h("button", { title: "/anim/sheet/put \"\": delete timing.txt", onclick: folderOrder }, "Folder order"),
      h("button", { onclick: close }, "Close")),
    h("p.hint", {}, "Hold = how many sequence frames a picture stays (2 = on twos). A file may come back (⧉). " +
      "Saving a frame with hold > 1 starts a sheet; later saves add their line."));
  document.body.append(dlg);
  draw();
  dlg.showModal();
}

// expected playback of frames this size (720p, measured 2026-11-01: decode ~25 ms +
// 0.16 ms per KB on one core, 2 decode threads, SD card ~10 MB/s)
export function playbackHint(bytes) {
  const kb = bytes / 1024, ms = 25 + 0.16 * kb;
  const alone = Math.min(60, (2 * 1000) / ms, 10240 / Math.max(1, kb));
  const two = Math.min(60, 1000 / ms, 5120 / Math.max(1, kb));
  return `≈ ${alone.toFixed(0)} fps alone, ${two.toFixed(0)} with a sequence on the other display`;
}

// ---- save frame (Paint tab) ----

export function saveCard(slotFn) {
  const s = { folder: "take1", src: "slot", q: 90, disp: 1, fps: 8, hold: 1, ...store.get("animsave", {}) };
  const keep = () => store.set("animsave", s);
  const listId = "anim-folders";
  const dl = h("datalist", { id: listId });
  const fillDl = () => dl.replaceChildren(...folders.map((f) => h("option", { value: f.name }, `${f.frames} frames`)));
  folderListeners.add(fillDl);
  const folder = h("input", { type: "text", value: s.folder, list: listId, style: "width:160px",
    title: "folder in /media/debaz/anim: A-Z a-z 0-9 . _ - (made on the first save)",
    onchange: () => { s.folder = folder.value.replace(/[^A-Za-z0-9._-]+/g, "_").replace(/^[._]+/, "").slice(0, 90); folder.value = s.folder; keep(); } });
  folder.setAttribute("list", listId);
  const src = h("select", { title: "what to save:\nthis paint slot = /anim/save <folder> <slot>\nlive input = /anim/save <folder> capture\n" +
      "display = /anim/save <folder> disp0|disp1 (what it shows, with its crop)",
    onchange: () => { s.src = src.value; keep(); } },
    [["slot", "this paint slot"], ["capture", "live input (HDMI 2)"], ["disp0", "display 0"], ["disp1", "display 1"]].map(([v, t]) =>
      h("option", { value: v, selected: v === s.src }, t)));
  const qOut = h("span.hint", { style: "min-width:2.2em" }, String(s.q));
  const q = h("input.big-range", { type: "range", min: 30, max: 100, step: 1, value: s.q, style: "width:140px",
    title: "JPEG quality: lower = smaller files = faster playback (see the size after a save); 85-90 looks clean",
    oninput: () => { s.q = +q.value; qOut.textContent = s.q; keep(); } });
  const info = h("span.hint", {}, "");
  const hold = h("input", { type: "number", min: 1, max: 1000, value: s.hold, style: "width:60px",
    title: "hold: how many sequence frames this picture stays (2 = on twos); > 1 starts timing.txt",
    onchange: () => { s.hold = Math.max(1, parseInt(hold.value) || 1); hold.value = s.hold; keep(); } });
  const disp = h("select", { title: "display for the preview loop", onchange: () => { s.disp = +disp.value; keep(); } },
    [0, 1].map((d) => h("option", { value: d, selected: d === s.disp }, `display ${d}`)));
  const fps = h("input", { type: "number", min: 0.5, max: 60, step: 0.5, value: s.fps, style: "width:60px",
    title: "preview frames per second", onchange: () => { s.fps = +fps.value; keep(); } });

  const saved = (m) => {
    const [f, file, n, ms, bytes = 0] = m.args;
    info.textContent = file ? `${f}/${file} saved · ${n} frames · ${ms.toFixed(0)} ms` +
      (bytes ? ` · ${(bytes / 1024).toFixed(0)} KB (q ${s.q}) · ${playbackHint(bytes)}` : "") :
      `${f}: last frame deleted · ${n} frames`;
    loadFolders();
  };
  const err = (m) => m.path === "/error" && /\/anim\/(save|undo)/.test(m.args[1] || "");
  const saveFrame = async () => {
    const source = s.src === "slot" ? +slotFn() : s.src;
    const m = await net.ask(net.message("/anim/save", s.folder, source, +s.q, s.hold | 0), (m) => m.path === "/anim/saved" || err(m), 3000);
    if (!m) toast("no reply from the board", true);
    else if (m.path === "/error") toast(m.args[0], true);
    else saved(m);
  };
  const undo = async () => {
    const m = await net.ask(net.message("/anim/undo", s.folder), (m) => m.path === "/anim/saved" || err(m), 2000);
    if (m?.path === "/error") toast(m.args[0], true);
    else if (m) saved(m);
  };
  const preview = () => net.msg(`/anim/${s.disp}/play`, s.folder, net.float(+s.fps));
  // onion skin: the live input (or the paint slot) with the last frames over it
  s.op ??= 0.4; s.onN ??= 1;
  const opOut = h("span.hint", {}, `${Math.round(s.op * 100)} %`);
  const op = h("input.big-range", { type: "range", min: 0, max: 1, step: 0.05, value: s.op, style: "width:110px",
    title: "opacity of the last frame (older ones: half each)\n/anim/<d>/onion/opacity f",
    oninput: () => { s.op = +op.value; opOut.textContent = `${Math.round(s.op * 100)} %`; keep();
      net.throttled(`/anim/${s.disp}/onion/opacity`, () => net.message(`/anim/${s.disp}/onion/opacity`, net.float(s.op))); } });
  const onN = h("select", { title: "how many earlier frames\n/anim/<d>/onion/frames n",
    onchange: () => { s.onN = +onN.value; keep(); net.msg(`/anim/${s.disp}/onion/frames`, s.onN); } },
    [1, 2, 3].map((k) => h("option", { value: k, selected: k === s.onN }, `${k} frame${k > 1 ? "s" : ""}`)));
  const onion = (on) => {
    const src = s.src === "slot" ? +slotFn() : -1; // a paint slot, else the capture
    if (on) net.msg(`/anim/${s.disp}/onion`, s.folder, net.float(s.op), s.onN, src);
    else net.msg(`/anim/${s.disp}/onion`, "");
  };
  // Ctrl+Enter = save frame (hands stay on the keyboard during a shoot)
  document.addEventListener("keydown", (e) => {
    if (e.key === "Enter" && e.ctrlKey && folder.closest(".tab")?.classList.contains("active")) { e.preventDefault(); saveFrame(); }
  });
  loadFolders();
  return card("Save frame (animation)",
    dl,
    row("folder", folder, h("span.hint", {}, "source"), src),
    row("quality", q, qOut, h("span.hint", {}, "hold"), hold),
    row(null,
      h("button.primary", { title: "/anim/save <folder> <source> <quality> <hold> (Ctrl+Enter)", onclick: saveFrame }, "Save frame"),
      h("button", { title: "/anim/undo <folder>: delete the last frame (and its timing.txt line)", onclick: undo }, "Undo last"),
      h("button", { title: "view / edit timing.txt: holds, order, repeats (/anim/sheet)", onclick: () => openSheet(s.folder, loadFolders) }, "Timing sheet…")),
    row("preview", disp, fps, h("button", { title: "/anim/<d>/play <folder> <fps> (loops; it reloads after each save)", onclick: preview }, "Play loop"),
      h("button", { title: "/anim/<d>/stop", onclick: () => net.msg(`/anim/${s.disp}/stop`) }, "Stop")),
    row("onion", op, opOut, onN,
      h("button", { title: "/anim/<d>/onion <folder> <opacity> <frames> <src>: the display above shows the live " +
        "input (or this paint slot, when the source is the paint slot) with the last frames over it", onclick: () => onion(true) }, "Onion on"),
      h("button", { title: "/anim/<d>/onion \"\"", onclick: () => onion(false) }, "Off")),
    info,
    h("p.hint", {}, "Each save adds the next f00001.jpg, f00002.jpg … to /media/debaz/anim/<folder>: the picture " +
      "of the source at its own size (display mode, or the input size for live input). Stop motion: source = " +
      "live input, preview loop or onion skin on the other display; both follow each save. While a sequence plays it " +
      "decodes into slots 5-8 (display 0) or 9, 10, 1, 3 (display 1): paint into another slot."));
}
