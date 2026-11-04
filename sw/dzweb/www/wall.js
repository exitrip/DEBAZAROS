// wall.js - video wall / crop exerciser (2026-10-29). Each display shows a
// window of the video-mode size from its slot at an offset: /disp/<d>/crop x y
// (debazd disp.c: x even, clamped, applied at the next vsync). There is no
// scaling in the PL: a "zoom" is a smaller output mode (hdmi2 -r) over a
// larger input, e.g. 640x480 quarters of a 1280x960 input. The exerciser
// moves the crops from the browser (one message per display and frame) and
// counts /event/video (vid_out lock loss / underflow, dynclk) during the run:
// 0 events = pass (the frame-synced VDMAs of build fs, ROADMAP section 9).
// Output mode (2026-11-01): /video/mode <name> restarts hdmi2 -r on the board;
// the window = the output size, the range = each display's source (the
// input's size when it shows the capture, else a 1920 x 1080 slot).
import * as net from "./net.js";
import { h, card, row, store } from "./ui.js";

let root;
const cfg = store.get("wall", { cols: 2, rows: 2, mode: "pan", speed: 4, hop: 30, secs: 30, both: 1 });
const geom = { mw: 1280, mh: 720, hz: 0, name: "", iw: 0, ih: 0, live: [false, false] }; // output, input, display d shows it
const CAPTURE_SLOT = 4; // sw/lib/dz_hw.h DZ_SLOT_CAPTURE
const crop = [[0, 0], [0, 0]];
const localT = [0, 0]; // when this browser last moved display d's crop (ms)
let run = null; // { t0, frames, sent, events, last, raf }
let ui = {};

const save = () => store.set("wall", cfg);
// the source display d crops from: the input when it shows the capture, else a 1920 x 1080 slot
const srcW = (d = 0) => (geom.live[d] && geom.iw) || 1920, srcH = (d = 0) => (geom.live[d] && geom.ih) || 1080;
const maxX = (d = 0) => Math.max(0, srcW(d) - geom.mw), maxY = (d = 0) => Math.max(0, srcH(d) - geom.mh);
const MODES = ["640x480", "800x600", "1024x768", "1280x720", "1280x720x50Hz", "1280x720x30Hz",
  "1920x1080x25Hz", "1920x1080x30Hz", "1920x1080x60Hz"]; // fallback for /video/modes

function setCrop(d, x, y, send = true) {
  x = Math.max(0, Math.min(maxX(d), Math.round(x))) & ~1;
  y = Math.max(0, Math.min(maxY(d), Math.round(y)));
  crop[d] = [x, y];
  if (send) {
    localT[d] = Date.now();
    net.throttled(`/disp/${d}/crop`, () => net.message(`/disp/${d}/crop`, x, y));
  }
  const s = ui.sl?.[d];
  if (s) { s.x.value = x; s.y.value = y; s.out.textContent = `${x}, ${y}`; }
  drawMap();
}

// tile t of the grid on display d's source: its top-left, so the window starts at the tile
function tileXY(t, d = 0) {
  const c = t % cfg.cols, r = Math.floor(t / cfg.cols);
  return [(c * srcW(d)) / cfg.cols, (r * srcH(d)) / cfg.rows];
}

// the grid of whole output-sized windows that fits in the source (at least 1 x 1)
function fitGrid() {
  cfg.cols = Math.max(1, Math.min(8, Math.floor(srcW() / geom.mw)));
  cfg.rows = Math.max(1, Math.min(8, Math.floor(srcH() / geom.mh)));
  save();
  ui.cols.value = cfg.cols;
  ui.rows.value = cfg.rows;
  drawMap();
}

async function loadGeom() {
  const v = await net.ask(net.message("/video/mode"), (m) => m.path === "/video/mode" && m.args.length >= 4);
  if (v) [geom.mw, geom.mh, geom.hz, geom.name] = v.args;
  const w = await net.getField("/capture/in/width"), l = await net.getField("/capture/in/lines");
  geom.iw = w && w.raw > 0 ? w.raw : 0;
  geom.ih = l && l.raw > 0 ? l.raw : 0;
  for (const d of [0, 1]) {
    const r = await net.ask(net.message(`/disp/${d}`), (m) => m.path === `/disp/${d}`);
    geom.live[d] = !!r && r.args[0] === CAPTURE_SLOT;
    if (r && ui.show?.[d] && typeof r.args[0] === "number") ui.show[d].value = String(r.args[0]);
  }
  for (const d of [0, 1]) {
    const c = await net.ask(net.message(`/disp/${d}/crop`), (r) => r.path === `/disp/${d}/crop`);
    if (c) setCrop(d, c.args[0], c.args[1], false);
  }
  showGeom();
}

function showGeom() {
  const hz = geom.hz > 1 ? ` @ ${geom.hz.toFixed(geom.hz % 1 ? 2 : 0)} Hz` : "";
  ui.out.textContent = `${geom.mw}×${geom.mh}${hz}`;
  ui.in.textContent = geom.iw ? `${geom.iw}×${geom.ih}` : "no signal";
  if (ui.mode && geom.name && !ui.mode.dataset.busy) ui.mode.value = geom.name;
  for (const d of [0, 1]) {
    ui.src[d].textContent = `${geom.live[d] ? "input" : "slot"} ${srcW(d)}×${srcH(d)}, x 0…${maxX(d)}, y 0…${maxY(d)}`;
    ui.sl[d].x.max = maxX(d);
    ui.sl[d].y.max = maxY(d);
    ui.sl[d].x.disabled = !maxX(d);
    ui.sl[d].y.disabled = !maxY(d);
  }
  const tight = [0, 1].some((d) => !maxX(d) && !maxY(d));
  ui.warn.textContent = tight ? "A source is not larger than the output: that display has no crop range. " +
    "Choose a smaller output mode (e.g. 640x480) to cut windows out of it." : "";
  drawMap();
}

// /video/mode <name>: hdmi2 restarts with -r on the board (both displays, movies stop)
async function applyMode() {
  const name = ui.mode.value;
  if (name === geom.name) return;
  ui.mode.dataset.busy = "1";
  ui.apply.disabled = true;
  ui.out.textContent = `switching to ${name}…`;
  const changed = new Promise((res) => { modeWait = res; setTimeout(res, 5000); });
  net.msg("/video/mode", name);
  await changed;
  modeWait = null;
  await new Promise((r) => setTimeout(r, 300)); // capture re-arm, crops reset
  delete ui.mode.dataset.busy;
  ui.apply.disabled = false;
  await loadGeom();
}
let modeWait = null;

async function loadModes() {
  const m = await net.ask(net.message("/video/modes"), (r) => r.path === "/video/modes");
  const list = m && m.args.length ? m.args : MODES;
  ui.mode.replaceChildren(...list.map((n) => h("option", { value: n }, n.replace(/x(\d+)Hz$/, " @ $1 Hz"))));
  if (geom.name) ui.mode.value = geom.name;
}

// ---- the map: source, tiles, the two windows ----
function drawMap() {
  const cv = ui.map;
  if (!cv) return;
  const W = cv.width, H = cv.height, k = Math.min(W / srcW(), H / srcH());
  const cx = cv.getContext("2d");
  const css = (v) => getComputedStyle(document.body).getPropertyValue(v);
  cx.clearRect(0, 0, W, H);
  cx.fillStyle = css("--panel2");
  cx.fillRect(0, 0, srcW() * k, srcH() * k);
  cx.strokeStyle = css("--line");
  cx.fillStyle = css("--dim");
  cx.font = "11px sans-serif";
  for (let t = 0; t < cfg.cols * cfg.rows; t++) {
    const [x, y] = tileXY(t);
    cx.strokeRect(x * k, y * k, (srcW() / cfg.cols) * k, (srcH() / cfg.rows) * k);
    cx.fillText(String(t), x * k + 4, y * k + 13);
  }
  ["#ff9a3c", "#4cc38a"].forEach((col, d) => {
    cx.strokeStyle = col;
    cx.lineWidth = 2;
    cx.strokeRect(crop[d][0] * k + 1, crop[d][1] * k + 1, geom.mw * k - 2, geom.mh * k - 2);
    cx.fillStyle = col;
    cx.fillText(`D${d}`, crop[d][0] * k + 6, crop[d][1] * k + geom.mh * k - 6);
  });
  cx.lineWidth = 1;
}

// ---- exerciser: one step per animation frame ----
function step() {
  const f = ++run.frames;
  const ds = cfg.both ? [0, 1] : [0];
  for (const d of ds) {
    let x, y;
    if (cfg.mode === "pan") { // a closed loop around the crop range, d = 1 runs the other way
      const mx = maxX(d), my = maxY(d);
      const per = Math.max(2, 2 * (mx + my)) / Math.max(1, cfg.speed);
      const t = ((f / per) + (d ? 0.5 : 0)) % 1;
      const P = 2 * (mx + my) || 1, p = t * P;
      [x, y] = p < mx ? [p, 0] : p < mx + my ? [mx, p - mx] :
        p < 2 * mx + my ? [mx - (p - mx - my), my] : [0, my - (p - 2 * mx - my)];
    } else if (cfg.mode === "hop") {
      if (f % Math.max(1, cfg.hop) !== 1 && f !== 1) continue;
      const n = cfg.cols * cfg.rows, t = (Math.floor(f / Math.max(1, cfg.hop)) + d) % n;
      [x, y] = tileXY(t, d);
    } else if (cfg.mode === "random") {
      if (f % Math.max(1, cfg.hop) !== 1 && f !== 1) continue;
      [x, y] = [Math.random() * maxX(d), Math.random() * maxY(d)];
    } else { // stress: a new random crop every frame
      [x, y] = [Math.random() * maxX(d), Math.random() * maxY(d)];
    }
    x = Math.max(0, Math.min(maxX(d), Math.round(x))) & ~1;
    y = Math.max(0, Math.min(maxY(d), Math.round(y)));
    crop[d] = [x, y];
    net.msg(`/disp/${d}/crop`, x, y);
    run.sent++;
  }
  if (f % 6 === 0) { drawMap(); report(); }
  const secs = (performance.now() - run.t0) / 1000;
  if (cfg.secs > 0 && secs >= cfg.secs) return stop();
  run.raf = requestAnimationFrame(step);
}

function report() {
  if (!run) return;
  const secs = ((performance.now() - run.t0) / 1000).toFixed(1);
  ui.res.textContent = `${secs} s, ${run.frames} frames, ${run.sent} crop changes, ` +
    `${run.events} video event(s)` + (run.last ? ` — last: ${run.last}` : "");
  ui.res.className = run.events ? "warn-text" : "hint";
}

function start() {
  if (run) stop();
  run = { t0: performance.now(), frames: 0, sent: 0, events: 0, last: "", raf: 0, done: false };
  ui.go.disabled = true;
  ui.res.textContent = "running…";
  run.raf = requestAnimationFrame(step);
}

function stop() {
  if (!run) return;
  cancelAnimationFrame(run.raf);
  report();
  ui.res.textContent += run.events ? "  FAIL" : "  PASS";
  run = null;
  ui.go.disabled = false;
  for (const d of [0, 1]) setCrop(d, crop[d][0], crop[d][1], false);
}

function numIn(key, attrs, title) {
  const el = h("input", { type: "number", value: cfg[key], title: `${title}\n(this browser only, no OSC)`, ...attrs,
    onchange: () => { cfg[key] = Number(el.value); save(); drawMap(); } });
  ui[key] = el;
  return el;
}

export function init(el) {
  root = el;
  ui.out = h("b", {}, "–");
  ui.in = h("b", {}, "–");
  ui.src = [h("span.hint"), h("span.hint")];
  // which slot each display shows (2026-11-04): movies, animations and paint
  // keep their own size in the slot, the window pans over all of it
  ui.show = [0, 1].map((d) => h("select", { title: `/disp/${d}/show <slot>  (slot 4 = the live input)`,
    onchange: (e) => { net.msg(`/disp/${d}/show`, Number(e.target.value)); setTimeout(loadGeom, 300); } },
    [...Array(12).keys()].map((i) => h("option", { value: i }, i === CAPTURE_SLOT ? `slot ${i} (input)` : `slot ${i}`))));
  ui.warn = h("p.warn-text");
  ui.mode = h("select", { title: "/video/mode <name>: both displays (one pixel clock); hdmi2 restarts, movies stop" });
  ui.apply = h("button.primary", { title: "/video/mode <name>", onclick: applyMode }, "Apply");
  ui.map = h("canvas", { width: 480, height: 280, title: "click: display 0 to that tile (shift: display 1)\n/disp/<d>/crop <x> <y>",
    style: "width:100%;max-width:480px;height:auto;border:1px solid var(--line);border-radius:8px;cursor:pointer",
    onclick: (e) => {
      const r = ui.map.getBoundingClientRect(), k = Math.min(ui.map.width / srcW(), ui.map.height / srcH());
      const sx = ((e.clientX - r.left) / r.width) * ui.map.width / k, sy = ((e.clientY - r.top) / r.height) * ui.map.height / k;
      const t = Math.min(cfg.cols - 1, Math.floor(sx / (srcW() / cfg.cols))) +
        cfg.cols * Math.min(cfg.rows - 1, Math.floor(sy / (srcH() / cfg.rows)));
      const d = e.shiftKey ? 1 : 0;
      setCrop(d, ...tileXY(t, d));
    } });
  ui.sl = [0, 1].map((d) => {
    const out = h("span", { title: `/disp/${d}/crop  -> /disp/${d}/crop x y (the board's crop now; polled while this tab is open)` }, "0, 0");
    const x = h("input", { type: "range", min: 0, max: 640, step: 2, value: 0, title: `/disp/${d}/crop <x> <y>  (or /disp/${d}/crop/x, /crop/y alone)`,
      oninput: () => setCrop(d, Number(x.value), crop[d][1]) });
    const y = h("input", { type: "range", min: 0, max: 360, step: 1, value: 0, title: `/disp/${d}/crop <x> <y>  (or /disp/${d}/crop/x, /crop/y alone)`,
      oninput: () => setCrop(d, crop[d][0], Number(y.value)) });
    return { x, y, out };
  });
  const mode = h("select", { title: "how the exerciser moves the crops (/disp/<d>/crop x y)", onchange: () => { cfg.mode = mode.value; save(); } },
    [["pan", "pan sweep (around the range)"], ["hop", "tile hop (every N frames)"],
      ["random", "random (every N frames)"], ["stress", "stress (random, every frame)"]]
      .map(([v, t]) => h("option", { value: v, selected: v === cfg.mode }, t)));
  const both = h("input", { type: "checkbox", checked: !!cfg.both, title: "move /disp/0/crop and /disp/1/crop", onchange: () => { cfg.both = both.checked ? 1 : 0; save(); } });
  ui.go = h("button.primary", { title: "run: /disp/<d>/crop x y per step, counts /event/video (/subscribe)\n" +
    "the browser sends the steps: no OSC address starts the exerciser", onclick: start }, "Start");
  ui.res = h("p.hint", {}, "–");
  root.replaceChildren(h("div.grid", {},
    card("Output",
      row("Output", ui.out),
      row("Input", ui.in),
      row("Mode", ui.mode, ui.apply),
      h("p.hint", {}, "Output = both displays (one pixel clock), input = HDMI 2. A new mode restarts hdmi2 on the board (a second or two of black); movies stop " +
        "and the crops go back to 0, 0. The boot mode is HDMI2_ARGS in /home/ebaz/dzstart.conf.")),
    card("Source",
      row(null, h("button", { onclick: () => { [0, 1].forEach((d) => net.msg(`/disp/${d}/capture`)); setTimeout(loadGeom, 300); },
        title: "/disp/0/capture, /disp/1/capture" }, "Live input on both"),
        h("button", { onclick: () => { [0, 1].forEach((d) => net.msg(`/disp/${d}/home`)); setTimeout(loadGeom, 300); },
          title: "/disp/<d>/home" }, "Home"),
        h("button.ghost", { title: "/video/mode, /disp/<d>, /disp/<d>/crop, /capture/in/width|lines", onclick: loadGeom }, "Refresh")),
      ...[0, 1].map((d) => row(`D${d}`, ui.show[d], ui.src[d])),
      ui.warn,
      h("p.hint", {}, "The window is the output mode; a smaller mode (hdmi2 -r, e.g. 640x480 over a 1280x960 " +
        "input) gives the zoom. Crops follow the shown slot: the input's real size when it is shown, else the whole " +
        "1920×1080 slot. Movies, animations and images keep their own size at the top left of their slot (a 720p movie " +
        "fills 1280×720 of it); the rest of the slot is whatever memory holds there.")),
    card("Tiles",
      row("Grid", numIn("cols", { min: 1, max: 8, step: 1 }, "columns"), "×", numIn("rows", { min: 1, max: 8, step: 1 }, "rows"),
        h("button", { title: "grid = the whole output-sized windows that fit in display 0's source\n(this browser only, no OSC)", onclick: fitGrid }, "Fit"),
        h("button", { title: "/disp/0/crop x y, /disp/1/crop x y (next tile)", onclick: () => { setCrop(0, ...tileXY(0, 0)); setCrop(1, ...tileXY(1, 1)); } }, "Split 0 | 1"),
        h("button.ghost", { onclick: () => [0, 1].forEach((d) => { net.msg(`/disp/${d}/crop/off`); setCrop(d, 0, 0, false); }),
          title: "/disp/<d>/crop/off" }, "Crops off")),
      ui.map,
      h("p.hint", {}, "The map is display 0's source; the boxes are the output-sized windows. Click a tile: " +
        "display 0 (orange) starts its window there; shift-click: display 1 (green). Windows clamp at the edge.")),
    card("Manual",
      ...[0, 1].map((d) => row(`D${d}`, ui.sl[d].x, ui.sl[d].y, ui.sl[d].out)),
      h("p.hint", {}, "x, y = the top-left of the window in the display's source; the range is source − output.")),
    card("Exerciser",
      row("Mode", mode),
      row("Speed", numIn("speed", { min: 1, max: 100, step: 1 }, "pan: pixels per frame"),
        "N", numIn("hop", { min: 1, max: 600, step: 1 }, "frames per hop / random step")),
      row("Seconds", numIn("secs", { min: 0, max: 3600, step: 1 }, "0 = until Stop"),
        h("label", {}, both, " both displays")),
      row("", ui.go, h("button", { title: "stop the exerciser (crops stay)", onclick: stop }, "Stop")),
      ui.res,
      h("p.hint", {}, "Counts /event/video during the run (vid_out lock loss / underflow, dynclk lock): " +
        "0 = PASS. The browser sends one crop per display and animation frame (~60/s)."))));
  net.on("/event/mode", () => { if (modeWait) modeWait(); else loadGeom(); });
  // the sliders follow the board (LFOs, cues, other browsers): poll twice a second
  // while this tab is open; a crop this browser moved in the last second wins
  net.on("/disp/", (m) => {
    const r = /^\/disp\/([01])\/crop$/.exec(m.path);
    if (!r || m.args.length < 2 || run) return;
    const d = +r[1];
    if (Date.now() - localT[d] < 1000) return;
    if (m.args[0] !== crop[d][0] || m.args[1] !== crop[d][1]) setCrop(d, m.args[0], m.args[1], false);
  });
  setInterval(() => {
    if (run || document.hidden || !root.classList.contains("active") || !net.connected()) return;
    net.send(net.bundle(net.message("/disp/0/crop"), net.message("/disp/1/crop")));
  }, 500);
  net.on("/event/video", (m) => {
    if (!run) return;
    run.events++;
    run.last = m.args.map((v) => (typeof v === "number" ? "0x" + (v >>> 0).toString(16) : v)).join(" ");
    report();
  });
}

export function connected() {
  loadModes().then(loadGeom);
}

export function show() {
  if (net.connected()) loadGeom();
}
