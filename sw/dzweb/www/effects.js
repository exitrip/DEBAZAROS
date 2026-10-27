// effects.js - every control register, built from /fields (so a gateware
// change appears here without code changes). Mixer as a 9-channel table.
import * as net from "./net.js";
import { h, card, row } from "./ui.js";

const MODES = [
  [0, "0 zero"], [1, "1 MAC (sum of gains)"], [3, "3 pass"], [4, "4 constant K"],
  [0x10, "10 clip ≥ lo"], [0x11, "11 clip ≤ hi"], [0x12, "12 clip = lo"], [0x13, "13 clip band"],
  [0x20, "20 K if ≥ lo"], [0x21, "21 K if ≤ hi"], [0x22, "22 K if = lo"], [0x23, "23 K if band"],
];
const GROUPS = [ // title, path prefix
  ["HDMI_0 output", "/hdmi/0/"],
  ["HDMI_1 output", "/hdmi/1/"],
  ["DDS oscillators (PL)", "/dds/"],
  ["HDMI audio (out HDMI_1, in HDMI_2)", "/audio/"],
];

let root;
let fields = [];
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
    const cb = h("input", { type: "checkbox", onchange: () => net.msg(path, cb.checked ? 1 : 0) });
    controls.set(path, { set: (raw) => (cb.checked = !!raw) });
    return h("div.field", {}, label, cb, h("span"));
  }
  if (unit === "hz") {
    const num = h("input", { type: "number", step: "0.1", min: 0, title: "Hz" });
    const rng = h("input", { type: "range", min: 0, max: 200, step: 0.1 });
    const sendHz = (v) => net.throttled(path, () => net.message(path, net.float(Number(v))));
    num.oninput = () => { rng.value = num.value; sendHz(num.value); };
    rng.oninput = () => { num.value = rng.value; sendHz(rng.value); };
    controls.set(path, { set: (raw, norm) => { num.value = norm.toFixed(2); rng.value = norm; } });
    return h("div.field", {}, label, rng, num);
  }
  const max = maxOf(width);
  const num = h("input", { type: "number", min: 0, max });
  const sendRaw = (v) => net.throttled(path, () => net.message(path, Math.round(Number(v)) | 0));
  if (width > 16) {
    num.onchange = () => sendRaw(num.value);
    controls.set(path, { set: (raw) => (num.value = raw) });
    num.title = `0…${max}`;
    return h("div.field", {}, label, h("span"), num);
  }
  const rng = h("input", { type: "range", min: 0, max, step: 1 });
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
  const deg = h("input", { type: "range", min: -180, max: 180, step: 1, value: 0 });
  const gain = h("input", { type: "range", min: 0, max: 1, step: 0.01, value: 1 });
  const degOut = h("span", {}, "0°");
  const sendHue = () => {
    degOut.textContent = `${deg.value}°`;
    net.throttled("/fx/hue", () => net.message("/fx/hue", net.float(Number(deg.value)),
      net.float(Number(gain.value))));
    refreshSoon();
  };
  deg.oninput = sendHue;
  gain.oninput = sendHue;
  const pick = (v) => h("input", { type: "color", value: v });
  const mapR = pick("#ff0000"), mapG = pick("#00ff00"), mapB = pick("#0000ff");
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
  const keyCol = pick("#00ff00");
  const tol = h("input", { type: "range", min: 0, max: 128, step: 1, value: 30 });
  const tolOut = h("span", {}, "30");
  const sendKey = () => {
    tolOut.textContent = tol.value;
    net.throttled("/fx/key/color", () => net.message("/fx/key/color", hex24(keyCol.value),
      Number(tol.value) | 0));
    refreshSoon();
  };
  const keyOn = h("input", { type: "checkbox",
    onchange: () => (keyOn.checked ? sendKey() : (net.msg("/fx/key/off"), refreshSoon())) });
  const keySrc = h("input", { type: "checkbox",
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
    row("Map R G B →", mapR, mapG, mapB,
      h("button", { onclick: () => { net.msg("/fx/map", hex24(mapR.value), hex24(mapG.value),
        hex24(mapB.value)); refreshSoon(); } }, "Apply")),
    row("", h("button", { onclick: () => { deg.value = 0; degOut.textContent = "0°";
      net.msg("/fx/identity"); refreshSoon(); } }, "Identity"),
      h("button.ghost", { onclick: boot }, "Boot setup"), h("label", {}, wrap, " wrap")),
    h("p.hint", {}, "Hue and map set all 9 mixer channels to constant gains. " +
      "Gains are unsigned: between 0°, 120° and 240° the colours lose saturation."),
    row("Key colour", keyCol, tol, tolOut),
    row("", h("label", {}, keyOn, " key on"),
      h("label", { title: "test HDMI_0's video instead of HDMI_1" }, keySrc, " test HDMI_0")),
    ...["/key/invert", "/key/stream"].map(keyField),
    h("p.hint", {}, "Key: where the tested pixel is within colour ± tolerance, " +
      "HDMI_1 replaces HDMI_0 (box = lo/hi of mixer channels 0, 6, 3 with their " +
      "KEY bit). Default test = HDMI_1's pixel; with invert = green screen on HDMI_1. " +
      "Needs the key bitstream (Oct 2026)."));
}

function mixerTable() {
  const tr = (c) => {
    const p = `/mixer/${c}`;
    const mode = h("select", { onchange: () => net.msg(`${p}/mode`, parseInt(mode.value)) },
      MODES.map(([v, t]) => h("option", { value: v }, t)));
    const num = (k, max) => {
      const n = h("input", { type: "number", min: 0, max,
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
    controls.set(`${p}/mode`, { set: (raw) => (mode.value = raw) });
    return h("tr", {}, h("td", {}, String(c)), h("td", {}, mode), num("k", 65535),
      num("lo", 255), num("hi", 255), bit("stream", "stream B (delayed copy)"),
      bit("key", "lo..hi band joins the colour key"), bit("src", "compare HDMI_0's video"),
      ...[0, 1, 2, 3, 4].map((g) => num(`gain/${g}`, 0x7fffffff)));
  };
  return h("div", { style: "overflow-x:auto" }, h("table.mixer", {},
    h("thead", {}, h("tr", {}, ...["ch", "mode", "K", "lo", "hi", "B", "key", "src",
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
    h("button.ghost", { onclick: refresh, style: "margin-left:auto" }, "Refresh")],
    ...status.map((f) => fieldControl(f, "/"))));
  grid.append(fxCard());
  root.replaceChildren(grid, card("Mixer (HDMI_0 colour matrix, 9 channels)", mixerTable(),
    h("p.hint", {}, "Each channel makes one gain of the 3×3 colour matrix. Inputs: " +
      "din0 R, din1 B, din2 G of HDMI_1 (stream A, or the delayed stream B), din3 sine, din4 saw.")));
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
}

export function connected() {
  load();
}

export function show() {
  if (fields.length) refresh();
}
