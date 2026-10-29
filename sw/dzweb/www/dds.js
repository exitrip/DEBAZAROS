// dds.js - the PL DDS engine dz_osc2 (build osc, 2026-10-29): patterns,
// step table and a draw panel for the AWG table. Patterns and tables are
// debazd /dds/<n>/... (sw/debazd/dds.c); the single registers are fields
// (also on the Effects page). Channel 0 feeds the HDMI_0 mixer (din3 sine,
// din4 saw: used only by mixer mode 1); channel 1 feeds HDMI_1's oscillator
// layers, which add to the picture (wrap math, intentional).
import * as net from "./net.js";
import { h, card, row, store } from "./ui.js";

const SHAPES = [["sine", "sine"], ["saw", "saw up"], ["sawdown", "saw down"], ["tri", "triangle"],
  ["square", "square"], ["pulse", "pulse"], ["awg", "AWG (drawn)"]];
const PATTERNS = [
  ["wave", "free running (Hz)"], ["bars", "vertical bars"], ["hbars", "horizontal bands"],
  ["checker", "checkerboard"], ["slant", "diagonal bars"]];
const TICKS = ["prescaler", "hsync", "vsync", "line start", "other ch step", "other ch wrap",
  "ext trigger", "none"];
const RESETS = ["none", "hsync", "vsync", "line start"];
const NPTS = 512; // AWG points sent (debazd interpolates to 2048)
const TWO32 = 4294967296;

let root;
const state = [0, 1].map((n) => store.get(`dds.${n}`, {
  pattern: "bars", shape: "square", hz: 1, count: 8, rows: 8, shift: 0.01, scroll: 0,
  duty: 0.5, phase: 0, level: 255 }));
const awg = [0, 1].map(() => new Array(NPTS).fill(32768));
const steps = [0, 1].map(() => Array.from({ length: 16 }, () => [0, 0, 0, 0, 0, 0]));
const views = [];
let rasterText;

const save = (n) => store.set(`dds.${n}`, state[n]);
const i32 = (v) => Math.round(v) | 0; // 0..2^32-1 -> the OSC int (two's complement)

function patternMsg(n) {
  const s = state[n], p = `/dds/${n}`;
  switch (s.pattern) {
    case "wave": return net.message(`${p}/wave`, s.shape, net.float(s.hz));
    case "bars": return net.message(`${p}/bars`, net.float(s.count), s.shape);
    case "hbars": return net.message(`${p}/hbars`, net.float(s.count), s.shape);
    case "checker": return net.message(`${p}/checker`, Math.max(1, s.count | 0), Math.max(1, s.rows | 0), s.shape);
    default: return net.message(`${p}/slant`, net.float(s.count), net.float(s.shift), s.shape);
  }
}

// a pattern resets the offsets: scroll, phase and pulse width go again after it
function apply(n) {
  const s = state[n], p = `/dds/${n}`;
  const m = [patternMsg(n)];
  if (s.scroll) m.push(net.message(`${p}/scroll`, net.float(s.scroll)));
  if (s.phase) m.push(net.message(`${p}/poff`, net.float(s.phase / 360)));
  if (s.shape === "pulse") m.push(net.message(`${p}/pulse`, net.float(s.duty)));
  net.throttled(`dds${n}`, () => net.bundle(...m));
  save(n);
}

function num(n, key, attrs, onset = () => apply(n)) {
  const el = h("input", { type: "number", value: state[n][key], ...attrs,
    oninput: () => { state[n][key] = Number(el.value); onset(); } });
  return el;
}

function slider(n, key, attrs, out, onset) {
  const el = h("input", { type: "range", value: state[n][key], ...attrs,
    oninput: () => { state[n][key] = Number(el.value); out.textContent = fmt(key, el.value); onset(); } });
  out.textContent = fmt(key, el.value);
  return el;
}

function fmt(key, v) {
  if (key === "phase") return `${v}°`;
  if (key === "duty") return `${Math.round(v * 100)} %`;
  if (key === "scroll") return `${v}/s`;
  return String(v);
}

function patternCard(n) {
  const s = state[n], p = `/dds/${n}`;
  const pat = h("select", { onchange: () => { s.pattern = pat.value; showRows(); apply(n); } },
    PATTERNS.map(([v, t]) => h("option", { value: v, selected: v === s.pattern }, t)));
  const shp = h("select", { onchange: () => { s.shape = shp.value; showRows(); apply(n); } },
    SHAPES.map(([v, t]) => h("option", { value: v, selected: v === s.shape }, t)));
  const rHz = row("Hz", num(n, "hz", { step: "0.01", min: 0 }));
  const rCount = row("Count", num(n, "count", { step: "0.5", min: 0, title: "bars / bands / columns across the picture" }));
  const rRows = row("Rows", num(n, "rows", { step: "1", min: 1 }));
  const rShift = row("Shift", num(n, "shift", { step: "0.001", title: "cycles per line (diagonal)" }));
  const outS = h("span"), outP = h("span"), outD = h("span"), outL = h("span");
  const scroll = slider(n, "scroll", { min: -10, max: 10, step: 0.1 }, outS, () => {
    net.throttled(`${p}/scroll`, () => net.message(`${p}/scroll`, net.float(s.scroll))); save(n); });
  const phase = slider(n, "phase", { min: 0, max: 359, step: 1 }, outP, () => {
    net.throttled(`${p}/poff`, () => net.message(`${p}/poff`, net.float(s.phase / 360))); save(n); });
  const duty = slider(n, "duty", { min: 0, max: 1, step: 0.01 }, outD, () => {
    net.throttled(`${p}/pulse`, () => net.message(`${p}/pulse`, net.float(s.duty))); save(n); });
  const rDuty = row("Duty", duty, outD);
  function showRows() {
    rHz.hidden = s.pattern !== "wave";
    rCount.hidden = s.pattern === "wave";
    rRows.hidden = s.pattern !== "checker";
    rShift.hidden = s.pattern !== "slant";
    rDuty.hidden = s.shape !== "pulse";
  }
  showRows();
  const kids = [
    row("Pattern", pat, shp),
    rHz, rCount, rRows, rShift,
    row("Scroll", scroll, outS),
    row("Phase", phase, outP),
    rDuty,
    row("", h("button.primary", { onclick: () => apply(n) }, "Apply"),
      h("button.ghost", { onclick: () => { net.msg(`${p}/off`); } }, "Off"),
      h("button.ghost", { onclick: () => net.msg(`${p}/wave`, "sine", net.float(0.1)) }, "Slow sine")),
  ];
  if (n === 1) {
    // HDMI_1: the sine layer's level, and a solo (video + feedback gains to 0)
    const level = slider(n, "level", { min: 0, max: 255, step: 1 }, outL, () => {
      net.throttled("/hdmi/1/osc/sin/gain/rgb", () => net.message("/hdmi/1/osc/sin/gain/rgb", s.level | 0));
      save(n); });
    let saved = null;
    const solo = h("input", { type: "checkbox", onchange: async () => {
      if (solo.checked) {
        const a = await net.getField("/hdmi/1/gain/rgb"), b = await net.getField("/hdmi/1/feedback/rgb");
        saved = [a ? a.raw : 0xffffff, b ? b.raw : 0x808080];
        net.send(net.bundle(net.message("/hdmi/1/gain/rgb", 0), net.message("/hdmi/1/feedback/rgb", 0)));
      } else if (saved) {
        const rgb = (v) => [(v >> 16) & 255, v & 255, (v >> 8) & 255]; // lanes R, G (low), B (mid)
        net.send(net.bundle(net.message("/hdmi/1/gain/rgb", ...rgb(saved[0])),
          net.message("/hdmi/1/feedback/rgb", ...rgb(saved[1]))));
        saved = null;
      }
    } });
    kids.push(row("Layer", level, outL), row("", h("label", { title:
      "HDMI_1 video and feedback gains to 0 while on (back when off)" }, solo, " solo on black")));
  }
  kids.push(h("p.hint", {}, n === 0
    ? "Channel 0 → HDMI_0 mixer din3 (sine leg) / din4 (saw leg): visible only through mixer mode 1."
    : "Channel 1 → HDMI_1 oscillator layers (sine leg: Layer; saw leg: /hdmi/1/osc/phase/gain). " +
      "Unsigned shapes: 0 or full scale; the layers add with wrap (intentional)."));
  return card(`DDS ${n} → HDMI_${n}`, ...kids);
}

// ---- step table ----
function stepCard(n) {
  const p = `/dds/${n}`;
  const field = (name) => `${p}/${name}`;
  const sel = (name, opts) => {
    const el = h("select", { onchange: () => net.msg(field(name), parseInt(el.value)) },
      opts.map((t, i) => h("option", { value: i }, `${i} ${t}`)));
    views[n][name] = el;
    return el;
  };
  const chk = (name, label, title) => {
    const el = h("input", { type: "checkbox", onchange: () => net.msg(field(name), el.checked ? 1 : 0) });
    views[n][name] = el;
    return h("label", { title }, el, ` ${label}`);
  };
  const last = h("select", { onchange: () => net.msg(field("last"), parseInt(last.value)) },
    [...Array(16).keys()].map((i) => h("option", { value: i }, String(i))));
  views[n].last = last;
  const cells = steps[n].map(() => []); // [i][k] = the input of value k of step i
  const body = h("tbody", {}, steps[n].map((st, i) => {
    const inp = (k, attrs) => {
      const el = h("input", { type: "number", value: st[k], ...attrs,
        oninput: () => { st[k] = Number(el.value); } });
      cells[i][k] = el;
      return h("td", {}, el);
    };
    const cb = (k) => {
      const el = h("input", { type: "checkbox", checked: !!st[k], onchange: () => { st[k] = el.checked ? 1 : 0; } });
      cells[i][k] = el;
      return h("td", {}, el);
    };
    return h("tr", {}, h("td", {}, String(i)),
      inp(0, { min: 0, step: 1, title: "START: increment (Hz = value × 0.0233)" }),
      inp(1, { step: 1, title: "DELTA: added at each tick (signed)" }),
      inp(2, { min: 0, step: 1, title: "LEN: ticks" }), cb(3), cb(4),
      inp(5, { min: 0, max: 359, step: 1, title: "PHASE offset while the step runs, degrees" }));
  }));
  const write = () => {
    const m = steps[n].map((st, i) => net.message(`${p}/step`, i, i32(st[0]), i32(st[1]),
      Math.max(0, st[2] | 0), st[3] ? 1 : 0, st[4] ? 1 : 0, i32((st[5] % 360) / 360 * TWO32)));
    net.send(net.bundle(...m));
  };
  const read = async () => {
    const r = await net.collect(net.message(`${p}/steps`), `${p}/step`, `${p}/steps/end`, 600);
    for (const [i, start, delta, len, keep, rst, ph] of r) {
      if (i < 0 || i > 15) continue;
      steps[n][i] = [start >>> 0, delta, len, keep, rst, Math.round(((ph >>> 0) / TWO32) * 360)];
      steps[n][i].forEach((v, k) => {
        const el = cells[i][k];
        if (el.type === "checkbox") el.checked = !!v; else el.value = v;
      });
    }
    refreshFields(n);
  };
  return card(`DDS ${n} step table`,
    row("Tick", sel("tick", TICKS), "Reset", sel("reset", RESETS)),
    row("Last", last, chk("seq", "run", "sequencer on"), chk("oneshot", "one shot"),
      chk("vsrestart", "restart at vsync"), chk("commit", "commit at vsync", "PINC, POFF, CTRL wait for vsync")),
    h("div", { style: "overflow-x:auto" }, h("table.mixer", {},
      h("thead", {}, h("tr", {}, ...["#", "start", "delta", "len", "keep", "rst", "phase°"].map((t) => h("th", {}, t)))),
      body)),
    row("", h("button.primary", { onclick: write }, "Write steps"),
      h("button.ghost", { onclick: read }, "Read back")),
    h("p.hint", {}, "A step runs LEN ticks: START is loaded (unless keep), DELTA is added at each tick, " +
      "PHASE is added while it runs, rst restarts the phase. Square = {A,0,N}{B,0,N}; " +
      "triangle = {A,+d,N}{keep,−d,N}. The checkerboard pattern writes steps 0-1."));
}

// ---- AWG draw panel ----
function awgCard(n) {
  const W = 512, H = 160;
  const pts = awg[n];
  const cv = h("canvas", { width: W, height: H, style: "width:100%;max-width:640px;height:auto;" +
    "background:var(--panel2);border:1px solid var(--line);border-radius:8px;touch-action:none;cursor:crosshair" });
  const ctx = cv.getContext("2d");
  const live = h("input", { type: "checkbox", checked: store.get(`dds.awglive.${n}`, true),
    onchange: () => store.set(`dds.awglive.${n}`, live.checked) });
  const draw = () => {
    ctx.clearRect(0, 0, W, H);
    ctx.strokeStyle = getComputedStyle(document.body).getPropertyValue("--line");
    ctx.beginPath(); ctx.moveTo(0, H / 2); ctx.lineTo(W, H / 2); ctx.stroke();
    ctx.strokeStyle = getComputedStyle(document.body).getPropertyValue("--accent");
    ctx.lineWidth = 2;
    ctx.beginPath();
    for (let i = 0; i < NPTS; i++) {
      const x = (i / NPTS) * W, y = H - 1 - (pts[i] / 65535) * (H - 2);
      i ? ctx.lineTo(x, y) : ctx.moveTo(x, y);
    }
    ctx.stroke();
  };
  const send = () => net.throttled(`/dds/${n}/awg`, () => net.message(`/dds/${n}/awg`, pts.join(" ")));
  let last = null;
  const at = (e) => {
    const r = cv.getBoundingClientRect();
    const x = Math.max(0, Math.min(NPTS - 1, Math.round(((e.clientX - r.left) / r.width) * (NPTS - 1))));
    const v = Math.max(0, Math.min(65535, Math.round((1 - (e.clientY - r.top) / r.height) * 65535)));
    return [x, v];
  };
  const paintTo = ([x, v]) => {
    if (last) { // fill every point between the last and this position
      const [x0, v0] = last, dx = x - x0;
      for (let k = 0; k <= Math.abs(dx); k++) {
        const t = dx ? k / Math.abs(dx) : 1;
        pts[x0 + Math.sign(dx) * k] = Math.round(v0 + (v - v0) * t);
      }
    } else pts[x] = v;
    last = [x, v];
    draw();
    if (live.checked) send();
  };
  cv.onpointerdown = (e) => { cv.setPointerCapture(e.pointerId); last = null; paintTo(at(e)); };
  cv.onpointermove = (e) => { if (e.buttons) paintTo(at(e)); };
  cv.onpointerup = () => { last = null; send(); };
  const fill = (f) => { for (let i = 0; i < NPTS; i++) pts[i] = Math.round(Math.max(0, Math.min(1, f(i / NPTS))) * 65535); draw(); send(); };
  const smooth = () => {
    const c = pts.slice();
    for (let i = 0; i < NPTS; i++) pts[i] = Math.round((c[(i + NPTS - 2) % NPTS] + 2 * c[(i + NPTS - 1) % NPTS] +
      3 * c[i] + 2 * c[(i + 1) % NPTS] + c[(i + 2) % NPTS]) / 9);
    draw(); send();
  };
  views[n].awgDraw = draw;
  draw();
  return card(`DDS ${n} AWG (draw a waveshape)`, cv,
    row("Preset",
      h("button.ghost", { onclick: () => fill((t) => 0.5 + 0.5 * Math.sin(2 * Math.PI * t)) }, "sine"),
      h("button.ghost", { onclick: () => fill((t) => t) }, "saw"),
      h("button.ghost", { onclick: () => fill((t) => 1 - Math.abs(2 * t - 1)) }, "tri"),
      h("button.ghost", { onclick: () => fill((t) => (t < 0.5 ? 1 : 0)) }, "square"),
      h("button.ghost", { onclick: () => fill(() => Math.random()) }, "noise"),
      h("button.ghost", { onclick: () => fill((t) => Math.pow(t, 3)) }, "curve"),
      h("button.ghost", { onclick: () => fill(() => 0.5) }, "flat")),
    row("", h("button.ghost", { onclick: smooth }, "Smooth"),
      h("button.ghost", { onclick: () => { pts.reverse(); draw(); send(); } }, "Reverse"),
      h("button.ghost", { onclick: () => fill((t) => 1 - pts[Math.round(t * NPTS) % NPTS] / 65535) }, "Invert"),
      h("label", {}, live, " live"),
      h("button.primary", { onclick: () => { send(); net.msg(`/dds/${n}/shape`, 6); state[n].shape = "awg"; save(n); } },
        "Use AWG")),
    h("p.hint", {}, "One cycle of the shape, left to right; top = full scale. " +
      `${NPTS} points → 2048 table entries (debazd interpolates). "Use AWG" selects shape 6 ` +
      "for the running pattern; the patterns above take shape AWG too."));
}

// read the register fields into the step-card controls
async function refreshFields(n) {
  const v = views[n];
  for (const name of ["tick", "reset", "last", "seq", "oneshot", "vsrestart", "commit"]) {
    const f = await net.getField(`/dds/${n}/${name}`);
    if (!f || !v[name]) continue;
    if (v[name].type === "checkbox") v[name].checked = !!f.raw;
    else v[name].value = f.raw;
  }
}

async function loadAwg(n) {
  const m = await net.ask(net.message(`/dds/${n}/awg`), (m) => m.path === `/dds/${n}/awg` && typeof m.args[0] === "string");
  if (!m || !m.args[0]) return;
  const src = m.args[0].trim().split(/\s+/).map(Number);
  if (src.length < 2) return;
  for (let i = 0; i < NPTS; i++) { // resample to NPTS points
    const pos = (i / NPTS) * src.length, k = Math.floor(pos), fr = pos - k;
    awg[n][i] = Math.round(src[k] * (1 - fr) + src[(k + 1) % src.length] * fr);
  }
  views[n].awgDraw?.();
}

async function loadRaster() {
  const m = await net.ask(net.message("/dds/raster"), (m) => m.path === "/dds/raster");
  if (!m) { rasterText.textContent = "no reply: needs debazd with dds.c and an osc bitstream"; return; }
  const [line, frame, ht, vt, w, hh] = m.args;
  rasterText.textContent = `raster ${w}×${hh} active, ${ht}×${vt} total, ` +
    `${frame.toFixed(2)} Hz frames, ${(line / 1000).toFixed(2)} kHz lines`;
}

export function init(el) {
  root = el;
  rasterText = h("span.hint");
  for (const n of [0, 1]) views[n] = {};
  const grid = h("div.grid", {}, patternCard(1), awgCard(1), stepCard(1),
    patternCard(0), awgCard(0), stepCard(0));
  root.replaceChildren(h("p", {}, rasterText, " ",
    h("button.ghost", { onclick: loadRaster }, "Refresh")), grid);
}

export function connected() {
  loadRaster();
  for (const n of [1, 0]) { refreshFields(n); loadAwg(n); }
}

export function show() {
  if (net.connected()) loadRaster();
}
