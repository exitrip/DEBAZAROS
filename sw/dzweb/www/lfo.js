// lfo.js - the 16 soft oscillators in debazd. debazd keeps the settings but
// reports only value and on, so this page keeps a copy of what it sent.
import * as net from "./net.js";
import { h, card, store } from "./ui.js";

const N = 16;
const SHAPES = ["sine", "tri", "saw", "ramp", "square", "random", "smooth", "step", "noise"];
const EXAMPLES = [
  "/hdmi/1/feedback/r",
  "/hdmi/0/gain/g",
  "/dds/0/hz",
  "/draw/6/brush 200 80 20 $0 $1 30 0",
  "/sprite/0/draw 6 640 360 1 $f2",
  "/draw/6/rotozoom $f3 1.02",
  "/disp/1/seq/rate $4",
  "/disp/1/show $5",
];
const DEF = { on: 0, shape: "sine", rate: 1, frames: 0, lo: 0, hi: 1, width: 0.5, curve: 1,
  steps: 0, every: 1, once: 0, phase: 0, target: "" };

const ALL = ["shape", "rate", "frames", "range", "width", "curve", "steps", "every", "mode",
  "phase", "target", "on"];
let cfg = [];
const meters = [];
let timer = null;

function save() {
  store.set("lfo", cfg);
}

function apply(i, keys) {
  const c = cfg[i];
  const p = `/lfo/${i}`;
  const m = [];
  for (const k of keys) {
    if (k === "shape") m.push(net.message(`${p}/shape`, c.shape));
    else if (k === "rate") m.push(net.message(`${p}/rate`, net.float(c.rate)));
    else if (k === "frames" && c.frames > 0) m.push(net.message(`${p}/frames`, c.frames | 0));
    else if (k === "range") m.push(net.message(`${p}/range`, net.float(c.lo), net.float(c.hi)));
    else if (k === "width") m.push(net.message(`${p}/width`, net.float(c.width)));
    else if (k === "curve") m.push(net.message(`${p}/curve`, net.float(c.curve)));
    else if (k === "steps") m.push(net.message(`${p}/steps`, c.steps | 0));
    else if (k === "every") m.push(net.message(`${p}/every`, Math.max(1, c.every | 0)));
    else if (k === "mode") m.push(net.message(`${p}/mode`, c.once ? "once" : "loop"));
    else if (k === "phase") m.push(net.message(`${p}/phase`, net.float(c.phase)));
    else if (k === "target") m.push(c.target ? net.message(`${p}/target`, c.target) : net.message(`${p}/target`));
    else if (k === "on") m.push(net.message(`${p}/on`, c.on ? 1 : 0));
  }
  if (m.length) net.send(m.length === 1 ? m[0] : net.bundle(...m));
  save();
}

function lfoCard(i) {
  const c = cfg[i];
  const num = (key, step, title, sendKey = key) => {
    const el = h("input", { type: "number", step, value: c[key], title,
      onchange: () => { c[key] = Number(el.value); apply(i, [sendKey]); } });
    return h("label", {}, title, el);
  };
  const onBtn = h("button", { onclick: () => { c.on = c.on ? 0 : 1; paint(); apply(i, ["on"]); } });
  const paint = () => { onBtn.textContent = c.on ? "On" : "Off"; onBtn.classList.toggle("on", !!c.on); };
  paint();
  const shape = h("select", { onchange: () => { c.shape = shape.value; apply(i, ["shape"]); } },
    SHAPES.map((s) => h("option", { value: s, selected: s === c.shape }, s)));
  const mode = h("select", { onchange: () => { c.once = mode.value === "once" ? 1 : 0; apply(i, ["mode"]); } },
    h("option", { value: "loop", selected: !c.once }, "loop"),
    h("option", { value: "once", selected: !!c.once }, "once"));
  const target = h("input", { type: "text", value: c.target, list: "lfo-targets",
    placeholder: "/field/path  or  /message a b $0 $f1" });
  const meter = h("div.meter", {}, h("i"));
  const val = h("span.hint", {}, "–");
  meters[i] = { meter, val };
  onBtn.style.marginLeft = "auto";
  return card([`LFO ${i}`, onBtn],
    meter, val,
    h("div.lfo", {},
      h("label", {}, "shape", shape),
      num("rate", "0.01", "rate Hz", "rate"),
      num("frames", "1", "or frames/cycle", "frames"),
      num("lo", "any", "min", "range"),
      num("hi", "any", "max", "range"),
      num("width", "0.05", "width 0..1"),
      num("curve", "0.1", "curve"),
      num("steps", "1", "steps"),
      num("every", "1", "every n frames"),
      num("phase", "0.05", "phase 0..1"),
      h("label", {}, "mode", mode),
      h("label", {}, " ", h("button", { onclick: () => { c.on = 1; paint(); net.msg(`/lfo/${i}/trigger`); save(); } }, "Trigger")),
      h("label.target", {}, "target",
        h("div.row", {}, target,
          h("button.primary", { onclick: () => { c.target = target.value.trim(); apply(i, ["target"]); } }, "Set"),
          h("button", { onclick: () => { c.target = ""; target.value = ""; apply(i, ["target"]); } }, "Clear")))));
}

function poll() {
  if (!net.connected()) return;
  net.send(net.bundle(...[...Array(N).keys()].map((i) => net.message(`/lfo/${i}`))));
}

export function init(root) {
  cfg = store.get("lfo", []);
  for (let i = 0; i < N; i++) cfg[i] = { ...DEF, ...(cfg[i] || {}) };
  const list = h("datalist", { id: "lfo-targets" });
  root.append(list,
    h("div.row", {},
      h("button", { onclick: () => { net.msg("/lfo/reset"); cfg = cfg.map(() => ({ ...DEF })); save(); root.replaceChildren(); init(root); } }, "Reset all"),
      h("button", { onclick: () => cfg.forEach((_, i) => apply(i, ALL)) }, "Send all settings"),
      h("span.hint", {}, "$k = value of LFO k (int), $fk = float. Targets run once per frame (every n).")),
    h("div.grid", {}, [...Array(N).keys()].map(lfoCard)));
  for (const ex of EXAMPLES) list.append(h("option", { value: ex }));
  net.on("/lfo", (m) => {
    const i = parseInt(m.path.split("/")[2]);
    if (!(i >= 0 && i < N) || m.path !== `/lfo/${i}`) return;
    const [v, on] = m.args;
    const c = cfg[i];
    const span = c.hi - c.lo || 1;
    meters[i].meter.firstChild.style.width = `${Math.max(0, Math.min(1, (v - c.lo) / span)) * 100}%`;
    meters[i].val.textContent = `${on ? "running" : "off"} · ${Number(v).toFixed(3)}`;
  });
}

export function connected() {
  // field paths as target suggestions
  net.collect(net.message("/fields"), "/field", "/field/end").then((fs) => {
    const list = document.getElementById("lfo-targets");
    for (const f of fs) if (!f[4]) list.append(h("option", { value: f[0] }));
  });
}

export function show() {
  clearInterval(timer);
  timer = setInterval(() => {
    if (document.getElementById("tab-lfo").classList.contains("active")) poll();
    else clearInterval(timer);
  }, 250);
}
