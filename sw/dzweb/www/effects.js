// effects.js - every control register, built from /fields (so a gateware
// change appears here without code changes). Mixer as a 9-channel table.
import * as net from "./net.js";
import { h, card, row } from "./ui.js";

const MODES = [
  [0, "0 zero"], [1, "1 MAC (sum of gains)"], [3, "3 pass"], [4, "4 constant K"], [5, "5 signed constant (g0)"],
  [0x10, "10 clip ≥ lo"], [0x11, "11 clip ≤ hi"], [0x12, "12 clip = lo"], [0x13, "13 clip band"],
  [0x20, "20 K if ≥ lo"], [0x21, "21 K if ≤ hi"], [0x22, "22 K if = lo"], [0x23, "23 K if band"],
];
const GROUPS = [ // title, path prefix
  ["HDMI_0 output", "/hdmi/0/"],
  ["HDMI_1 output", "/hdmi/1/"],
  ["DDS oscillators (PL)", "/dds/"],
  ["HDMI audio (out HDMI_1, in HDMI_2)", "/audio/"],
  ["User I/O lines PL_KEY0-5 (function 0 = input)", "/io/"],
  ["I2S (on the user I/O lines)", "/i2s/"],
];

let root;
let fields = [];
let hueUi = null;	// the Colour FX card's hue controls
const controls = new Map(); // path -> { set(raw), el }

function maxOf(width) {
  return width >= 31 ? 0x7fffffff : 2 ** width - 1;
}

function fieldControl(f, prefix = "") {
  const [path, , width, unit, ro, help] = f;
  const name = path.startsWith(prefix) ? path.slice(prefix.length) : path;
  const label = h("span.name", { title: `${path}\n${help}` }, name);
  if (ro) {
    const v = h("span", {}, "–");
    controls.set(path, { set: (raw) => (v.textContent = raw) });
    return h("div.field", {}, label, v, h("span"));
  }
  if (unit === "bool") {
    const cb = h("input", { type: "checkbox", title: `${path} <0|1>`, onchange: () => net.msg(path, cb.checked ? 1 : 0) });
    controls.set(path, { set: (raw) => (cb.checked = !!raw) });
    return h("div.field", {}, label, cb, h("span"));
  }
  if (unit === "q16s") { // signed gain (mixer coreRevision 25): signed int, 0x10000 = 1.0
    const half = 2 ** (width - 1);
    const num = h("input", { type: "number", step: 1, min: -half, max: half - 1, value: 0,
      title: `${path} <int>: signed, 0x10000 = 1.0` });
    num.onchange = () => net.msg(path, Math.round(Number(num.value)) | 0);
    controls.set(path, { set: (raw) => (num.value = raw >= half ? raw - 2 * half : raw) });
    return h("div.field", {}, label, h("span"), num);
  }
  if (unit === "hz") {
    const num = h("input", { type: "number", step: "0.1", min: 0, title: `${path} <Hz, float>` });
    const rng = h("input", { type: "range", min: 0, max: 200, step: 0.1, title: `${path} <Hz, float>` });
    const sendHz = (v) => net.throttled(path, () => net.message(path, net.float(Number(v))));
    num.oninput = () => { rng.value = num.value; sendHz(num.value); };
    rng.oninput = () => { num.value = rng.value; sendHz(rng.value); };
    controls.set(path, { set: (raw, norm) => { num.value = norm.toFixed(2); rng.value = norm; } });
    return h("div.field", {}, label, rng, num);
  }
  const max = maxOf(width);
  const num = h("input", { type: "number", min: 0, max, title: `${path} <0..${max}> (int raw; float 0..1 = scaled)` });
  const sendRaw = (v) => net.throttled(path, () => net.message(path, Math.round(Number(v)) | 0));
  if (width > 16) {
    num.onchange = () => sendRaw(num.value);
    controls.set(path, { set: (raw) => (num.value = raw) });
    num.title = `${path} <0…${max}>`;
    return h("div.field", {}, label, h("span"), num);
  }
  const rng = h("input", { type: "range", min: 0, max, step: 1, title: `${path} <0..${max}>` });
  rng.oninput = () => { num.value = rng.value; sendRaw(rng.value); };
  num.onchange = () => { rng.value = num.value; sendRaw(num.value); };
  controls.set(path, { set: (raw) => { rng.value = raw; num.value = raw; } });
  return h("div.field", {}, label, rng, num);
}

const hex24 = (hex) => parseInt(hex.slice(1), 16);
let refreshTimer;
const refreshSoon = () => { clearTimeout(refreshTimer); refreshTimer = setTimeout(refresh, 300); };

// Colour matrix (hue, map) and colour key: debazd /fx/... (sw/debazd/fx.c).
// Both write the mixer; "Boot setup" puts back the debazarosit.sh values.
function fxCard() {
  const deg = h("input", { type: "range", min: -180, max: 180, step: 1, value: 0,
    title: "/fx/hue/deg <degrees>  (or /fx/hue <deg> [gain])" });
  const gain = h("input", { type: "range", min: 0, max: 2, step: 0.01, value: 1,
    title: "/fx/hue/gain <0..1> (signed: 0..4)" });
  const sat = h("input", { type: "range", min: -1, max: 3, step: 0.05, value: 1,
    title: "/fx/hue/sat <f>: 1 = as is, 0 = grey, > 1 more, < 0 the complement\n(needs signed for > 1 and < 0)" });
  const degOut = h("span", {}, "0°"), satOut = h("span", {}, "1.00");
  const sendHue = () => {
    degOut.textContent = `${deg.value}°`;
    net.throttled("/fx/hue", () => net.message("/fx/hue", net.float(Number(deg.value)),
      net.float(Number(gain.value))));	// = /fx/hue/deg + /fx/hue/gain
    refreshSoon();
  };
  const sendSat = () => {
    satOut.textContent = Number(sat.value).toFixed(2);
    net.throttled("/fx/hue/sat", () => net.message("/fx/hue/sat", net.float(Number(sat.value))));
    refreshSoon();
  };
  deg.oninput = sendHue;
  gain.oninput = sendHue;
  sat.oninput = sendSat;
  const signed = h("input", { type: "checkbox",
    title: "/fx/signed <0|1>: write the matrix as mode 5 signed constants (bitstream smix or later)\n" +
      "exact hue at every angle, saturation, negative entries; results outside 0..255 wrap",
    onchange: () => { net.msg("/fx/signed", signed.checked ? 1 : 0); sendHue(); } });
  hueUi = { deg, degOut, gain, sat, satOut, signed };	// for the /fx/hue, /fx/signed replies (init)
  const pick = (v, t) => h("input", { type: "color", value: v, title: t });
  const mapR = pick("#ff0000", "where input red goes\n/fx/map <0xRRGGBB r> <g> <b>"),
    mapG = pick("#00ff00", "where input green goes\n/fx/map <r> <0xRRGGBB g> <b>"),
    mapB = pick("#0000ff", "where input blue goes\n/fx/map <r> <g> <0xRRGGBB b>");
  const wrap = h("input", { type: "checkbox", title: "allow row sums > 1 (bright colours wrap)",
    onchange: () => net.msg("/fx/wrap", wrap.checked ? 1 : 0) });
  const boot = () => {
    const m = [];
    for (let c = 0; c < 9; c++) {
      const diag = c === 0 || c === 5 || c === 7;
      m.push(net.message(`/mixer/${c}/mode`, diag ? 4 : 0x23),
        net.message(`/mixer/${c}/k`, diag ? 0x8000 : 0xffff));
      if (!diag) m.push(net.message(`/mixer/${c}/lo`, 0x20), net.message(`/mixer/${c}/hi`, 0xed));
    }
    net.send(net.bundle(...m));
    refreshSoon();
  };
  const keyCol = pick("#00ff00", "key colour\n/fx/key/color <0xRRGGBB> [tol]");
  const tol = h("input", { type: "range", min: 0, max: 128, step: 1, value: 30,
    title: "key tolerance (± per channel)\n/fx/key/tol <0..128>" });
  const tolOut = h("span", {}, "30");
  const sendKey = () => {
    tolOut.textContent = tol.value;
    net.throttled("/fx/key/color", () => net.message("/fx/key/color", hex24(keyCol.value),
      Number(tol.value) | 0));
    refreshSoon();
  };
  const keyOn = h("input", { type: "checkbox", title: "on: /fx/key/color <0xRRGGBB> <tol>\noff: /fx/key/off",
    onchange: () => (keyOn.checked ? sendKey() : (net.msg("/fx/key/off"), refreshSoon())) });
  const keySrc = h("input", { type: "checkbox", title: "compare HDMI_0's own video\n/fx/key/source <0|1>",
    onchange: () => net.msg("/fx/key/source", keySrc.checked ? 1 : 0) });
  keyCol.oninput = () => { keyOn.checked = true; sendKey(); };
  tol.oninput = () => { keyOn.checked = true; sendKey(); };
  const keyField = (p) => {
    const f = fields.find((x) => x[0] === p);
    return f ? fieldControl(f, "/key/") : null;
  };
  return card("Colour FX (HDMI_0)",
    row("Hue", deg, degOut),
    row("Gain", gain),
    row("Saturation", sat, satOut),
    row("", h("label", {}, signed, " signed gains (mode 5)")),
    row("Map R G B →", mapR, mapG, mapB,
      h("button", { title: "/fx/map <0xRRGGBB> <0xRRGGBB> <0xRRGGBB>", onclick: () => { net.msg("/fx/map", hex24(mapR.value), hex24(mapG.value),
        hex24(mapB.value)); refreshSoon(); } }, "Apply")),
    row("", h("button", { title: "/fx/identity", onclick: () => { deg.value = 0; degOut.textContent = "0°";
      net.msg("/fx/identity"); refreshSoon(); } }, "Identity"),
      h("button.ghost", { title: "the debazarosit.sh mixer setup\n/mixer/<c>/mode, /k, /lo, /hi (all 9 channels)", onclick: boot }, "Boot setup"), h("label", {}, wrap, " wrap")),
    h("p.hint", {}, "Hue and map set all 9 mixer channels to constant gains. " +
      "Unsigned (mode 4): between 0°, 120° and 240° the colours lose saturation, and saturation > 1 does little. " +
      "Signed (mode 5): exact at every angle; as in the rest of the gateware, a result outside 0..255 wraps."),
    row("Key colour", keyCol, tol, tolOut),
    row("", h("label", {}, keyOn, " key on"),
      h("label", { title: "test HDMI_0's video instead of HDMI_1" }, keySrc, " test HDMI_0")),
    ...["/key/invert", "/key/stream"].map(keyField),
    h("p.hint", {}, "Key: where the tested pixel is within colour ± tolerance, " +
      "HDMI_1 replaces HDMI_0 (box = lo/hi of mixer channels 0, 6, 3 with their " +
      "KEY bit). Default test = HDMI_1's pixel; with invert = green screen on HDMI_1. " +
      "Needs the key bitstream (Oct 2026)."));
}

// HDMI_1 cross-fade (debazd trans.c): own slot <-> HDMI_0's output through the two gain
// words; the board keeps own + feedback = the level G per lane, so the adder never wraps
function xfadeCard() {
  const t = h("input", { type: "range", min: 0, max: 1, step: 0.001, value: 0,
    title: "drag = at once\n/fx/xfade t (0 = HDMI_1's own slot, 1 = HDMI_0's output)" });
  const tOut = h("span", {}, "0.000");
  const secs = h("input", { type: "number", min: 0, max: 600, step: 0.1, value: 3, style: "width:5em",
    title: "fade time of the buttons, seconds" });
  const smooth = h("input", { type: "checkbox", title: "S curve instead of linear" });
  const st = h("span.hint", {}, "");
  const show = (v) => { t.value = v; tOut.textContent = Number(v).toFixed(3); };
  t.oninput = () => {
    show(t.value);
    net.throttled("/fx/xfade", () => net.message("/fx/xfade", net.float(Number(t.value))));
  };
  const go = (to) => {
    const a = [net.float(to), net.float(Number(secs.value) || 0)];
    if (smooth.checked) a.push("smooth");
    net.msg("/fx/xfade", ...a);
    poll();
  };
  let timer = 0;
  const poll = () => {        // follow a running fade
    clearTimeout(timer);
    let n = Math.ceil(((Number(secs.value) || 0) + 0.5) / 0.2);
    const step = () => {
      net.send(net.bundle(net.message("/fx/xfade"), net.message("/trans/status")));
      if (--n > 0) timer = setTimeout(step, 200);
    };
    step();
  };
  net.on("/fx/xfade", (m) => { if (m.args.length && document.activeElement !== t) show(m.args[0]); });
  net.on("/trans/status", (m) => { st.textContent = m.args[0] ? `${m.args[0]} ramp(s) running` : "idle"; });
  net.send(net.bundle(net.message("/fx/xfade"), net.message("/trans/status"))); // position now
  return card("Cross-fade (HDMI_1)",
    row("t", t, tOut),
    row("fade", secs, h("label", {}, "s"), h("label", {}, smooth, " smooth")),
    row(null,
      h("button", { title: "/fx/xfade 0 <s> [smooth]", onclick: () => go(0) }, "→ own (0)"),
      h("button", { title: "/fx/xfade 0.5 <s> [smooth]", onclick: () => go(0.5) }, "½"),
      h("button.primary", { title: "/fx/xfade 1 <s> [smooth]", onclick: () => go(1) }, "→ HDMI_0 (1)"),
      h("button", { title: "/trans/stop: hold where it is", onclick: () => { net.msg("/trans/stop"); poll(); } }, "Stop"),
      h("button", { title: "/fx/xfade (query)", onclick: poll }, "Read")),
    row(null, st),
    h("p.hint", {}, "Fades HDMI_1 between its own slot and HDMI_0's output with the own and feedback " +
      "gains; per colour lane own + feedback stays at the level they had together (at most 255)."));
}

function mixerTable() {
  const tr = (c) => {
    const p = `/mixer/${c}`;
    const mode = h("select", { title: `${p}/mode <n>`, onchange: () => net.msg(`${p}/mode`, parseInt(mode.value)) },
      MODES.map(([v, t]) => h("option", { value: v }, t)));
    const num = (k, max) => {
      const n = h("input", { type: "number", min: 0, max, title: `${p}/${k} <0..${max}>`,
        onchange: () => net.msg(`${p}/${k}`, parseInt(n.value) || 0) });
      controls.set(`${p}/${k}`, { set: (raw) => (n.value = raw) });
      return h("td", {}, n);
    };
    const bit = (k, title) => {
      const cb = h("input", { type: "checkbox", title,
        onchange: () => net.msg(`${p}/${k}`, cb.checked ? 1 : 0) });
      controls.set(`${p}/${k}`, { set: (raw) => (cb.checked = !!raw) });
      return h("td", {}, cb);
    };
    // a signed gain (mixer coreRevision 25): an int, the 24-bit two's complement
    // value of gain [23:0] (0x10000 = 1.0; RGB gains are useful below ~255, the
    // oscillator gains below that); g0 = the mode 5 constant
    const sgain = (k) => {
      const n = h("input", { type: "number", step: 1, min: -8388608, max: 8388607, value: 0, style: "width:6.5em",
        title: `${p}/${k} <int>: signed, 0x10000 = 1.0, negative subtracts\n(raw unsigned: ${p}/gain/${k.slice(2)})`,
        onchange: () => net.msg(`${p}/${k}`, Math.round(Number(n.value)) | 0) });
      controls.set(`${p}/${k}`, { set: (raw) => (n.value = raw >= 0x800000 ? raw - 0x1000000 : raw) });
      return h("td", {}, n);
    };
    controls.set(`${p}/mode`, { set: (raw) => (mode.value = raw) });
    return h("tr", {}, h("td", {}, String(c)), h("td", {}, mode), num("k", 65535),
      num("lo", 255), num("hi", 255), bit("stream", "stream B (delayed copy)"),
      bit("key", "lo..hi band joins the colour key"), bit("src", "compare HDMI_0's video"),
      bit("diff", "mode 1: R B G inputs = stream A - stream B (edge / comb with the delay)"),
      bit("centre", "mode 1: R B G inputs - 128 (bipolar video)"),
      bit("dsign", "mode 1: sine / saw (din3, din4) as two's complement"),
      ...[0, 1, 2, 3, 4].map((g) => sgain(`g/${g}`)));
  };
  return h("div", { style: "overflow-x:auto" }, h("table.mixer", {},
    h("thead", {}, h("tr", {}, ...["ch", "mode", "K", "lo", "hi", "B", "key", "src", "A−B", "−128", "±dds",
      "g0 R", "g1 B", "g2 G", "g3 sin", "g4 saw"].map((t) => h("th", {}, t)))),
    h("tbody", {}, [...Array(9).keys()].map(tr))));
}

async function load() {
  fields = await net.collect(net.message("/fields"), "/field", "/field/end");
  controls.clear();
  const grid = h("div.grid");
  for (const [title, prefix] of GROUPS) {
    const fs = fields.filter((f) => f[0].startsWith(prefix) && !f[4] && f[3] !== "rgb");
    if (fs.length) grid.append(card(title, ...fs.map((f) => fieldControl(f, prefix))));
  }
  const status = fields.filter((f) => f[4]);
  grid.append(card(["Inputs (read only)",
    h("button.ghost", { title: "query every field (/<field> -> /value)", onclick: refresh, style: "margin-left:auto" }, "Refresh")],
    ...status.map((f) => fieldControl(f, "/"))));
  grid.append(fxCard());
  grid.prepend(xfadeCard()); // first: the quick test of /fx/xfade
  root.replaceChildren(grid, card("Mixer (HDMI_0 colour matrix, 9 channels)", mixerTable(),
    h("p.hint", {}, "Each channel makes one gain of the 3×3 colour matrix. Inputs: " +
      "din0 R, din1 B, din2 G of HDMI_1 (stream A, or the delayed stream B), din3 sine, din4 saw. " +
      "Gains g0..g4 are signed ints (0x10000 = 1.0, negative subtracts; bitstream smix or later). Mode 1 options: A−B (stream A minus " +
      "the delayed stream B: edges / comb), −128 (bipolar video), ±dds (sine and saw signed). " +
      "Mode 1 is timed for 720p60 only.")));
  refresh();
}

function refresh() {
  const paths = fields.filter((f) => f[3] !== "rgb").map((f) => f[0]);
  for (let i = 0; i < paths.length; i += 24) // bundles of 24 queries
    net.send(net.bundle(...paths.slice(i, i + 24).map((p) => net.message(p))));
}

export function init(el) {
  root = el;
  root.append(h("p.hint", {}, "Connecting…"));
  net.on("/value", (m) => {
    const [path, raw, norm] = m.args;
    controls.get(path)?.set(raw, norm);
  });
  // the board's state: /fx/hue -> deg gain sat, /fx/signed -> i
  net.on("/fx/hue", (m) => {
    const u = hueUi, [d, g, s] = m.args;
    if (!u) return;
    if (document.activeElement !== u.deg) { u.deg.value = d; u.degOut.textContent = `${Math.round(d)}°`; }
    if (document.activeElement !== u.gain) u.gain.value = g;
    if (s !== undefined && document.activeElement !== u.sat) { u.sat.value = s; u.satOut.textContent = Number(s).toFixed(2); }
  });
  net.on("/fx/signed", (m) => { if (hueUi) hueUi.signed.checked = !!m.args[0]; });
}

export function connected() {
  load();
  net.msg("/fx/hue");
  net.msg("/fx/signed");
}

export function show() {
  if (fields.length) refresh();
  net.msg("/fx/xfade");
  net.msg("/fx/hue");
  net.msg("/fx/signed");
}
