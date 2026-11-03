// app.js - shell: tabs, unit switcher, status chips, error toasts.
import * as net from "./net.js";
import { h, toast, store } from "./ui.js";
import * as displays from "./displays.js";
import * as wall from "./wall.js";
import * as effects from "./effects.js";
import * as lfo from "./lfo.js";
import * as dds from "./dds.js";
import * as paint from "./paint.js";
import * as media from "./media.js";
import * as audio from "./audio.js";
import * as con from "./console.js";
import * as cues from "./cues.js";

const modules = { displays, wall, effects, lfo, dds, paint, media, audio, cues, console: con };
const $ = (id) => document.getElementById(id);

// ---- tabs ----
function showTab(name) {
  for (const b of document.querySelectorAll(".tabs button"))
    b.setAttribute("aria-selected", String(b.dataset.tab === name));
  for (const s of document.querySelectorAll(".tab")) s.classList.toggle("active", s.id === "tab-" + name);
  store.set("tab", name);
  if (location.hash.slice(1) !== name) history.replaceState(null, "", "#" + name);
  modules[name]?.show?.();
}
for (const b of document.querySelectorAll(".tabs button")) b.onclick = () => showTab(b.dataset.tab);

// ---- status chips ----
function chip(id, text, cls) {
  const c = $(id);
  c.textContent = text;
  c.className = "chip " + (cls || "");
}
net.onStatus((up) => chip("st-conn", up ? "online" : "offline", up ? "ok" : "off"));
net.on("/vsync", (m) => {
  const [, hz, , ok] = m.args;
  chip("st-vsync", ok ? `vsync ${hz.toFixed(2)} Hz` : "no vsync", ok ? "ok" : "warn");
});
net.on("/event/capture", (m) => {
  const [locked, frames] = m.args;
  chip("st-input", locked ? (frames ? "input live" : "input locked") : "no input",
       locked && frames ? "ok" : locked ? "warn" : "");
});
// /stats: debazd CPU, frame ticks per second, the slowest tick / OSC packet of the
// last second (a slow one blocks every reply: the web app then looks frozen)
net.on("/stats", (m) => {
  const [self, total, hz, tickMax, oscMax, load, mem, temp] = m.args;
  const slow = tickMax > 25 || oscMax > 100 || (hz > 0 && hz < 50);
  const pct = (v) => (v < 0 ? "…" : `${v.toFixed(0)} %`);
  chip("st-load", `debazd ${pct(self)}${temp > 0 ? ` · ${temp.toFixed(0)} °C` : ""}`, slow ? "warn" : "ok");
  $("st-load").title = `debazd CPU ${pct(self)}, all programs ${pct(total)} (200 % = both cores)\n` +
    `frame ticks ${hz.toFixed(1)}/s, slowest tick ${tickMax.toFixed(1)} ms, slowest OSC packet ${oscMax.toFixed(1)} ms\n` +
    `load ${load.toFixed(2)}, memory free ${(mem / 1024).toFixed(0)} MB` + (temp > 0 ? `, die ${temp.toFixed(1)} °C` : "") +
    "\n/stats";
});
setInterval(() => net.connected() && net.send(net.bundle(net.message("/vsync"), net.message("/stats"))), 2000);

// ---- errors -> toast ----
net.on("/error", (m) => toast(m.args.join(": "), true));
net.on("/warning", (m) => toast(m.args.join(": ")));

// ---- units ----
let units = [];
function fillUnits() {
  const sel = $("unit");
  const cur = store.get("unit", "");
  sel.replaceChildren(
    h("option", { value: "" }, `this unit (${location.hostname})`),
    ...units.filter((u) => u.ip).map((u) =>
      h("option", { value: u.ip }, `${u.host} ${u.ip} — ${u.mac}`)),
  );
  sel.value = [...sel.options].some((o) => o.value === cur) ? cur : "";
}
async function scan() {
  try {
    const r = await fetch("/units");
    units = await r.json();
    fillUnits();
    toast(`${units.length} unit(s) found`);
  } catch {
    toast("scan failed", true);
  }
}
$("scan").onclick = scan;
$("unit").onchange = () => {
  store.set("unit", $("unit").value);
  net.connect($("unit").value);
};
$("sendall").onchange = () => {
  const primary = $("unit").value;
  const others = $("sendall").checked
    ? units.map((u) => u.ip || location.hostname).filter((ip) => ip !== (primary || location.hostname))
    : [];
  net.setExtras(others);
  toast($("sendall").checked ? `controls go to ${others.length + 1} units` : "controls go to one unit");
};

// ---- start ----
for (const [name, mod] of Object.entries(modules)) mod.init($("tab-" + name));
net.onConnect(() => {
  net.msg("/vsync");
  for (const mod of Object.values(modules)) mod.connected?.();
});
fillUnits();
net.connect(store.get("unit", ""));
const hashTab = location.hash.slice(1);
showTab(hashTab in modules ? hashTab : store.get("tab", "displays"));
window.addEventListener("hashchange", () => {
  const t = location.hash.slice(1);
  if (t in modules) showTab(t);
});
scan();
