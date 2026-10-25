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
    const stream = h("input", { type: "checkbox", title: "stream B (delayed copy)",
      onchange: () => net.msg(`${p}/stream`, stream.checked ? 1 : 0) });
    controls.set(`${p}/mode`, { set: (raw) => (mode.value = raw) });
    controls.set(`${p}/stream`, { set: (raw) => (stream.checked = !!raw) });
    return h("tr", {}, h("td", {}, String(c)), h("td", {}, mode), num("k", 65535),
      num("lo", 255), num("hi", 255), h("td", {}, stream),
      ...[0, 1, 2, 3, 4].map((g) => num(`gain/${g}`, 0x7fffffff)));
  };
  return h("div", { style: "overflow-x:auto" }, h("table.mixer", {},
    h("thead", {}, h("tr", {}, ...["ch", "mode", "K", "lo", "hi", "B",
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
