// fleet.js - one page for many units (2026-11-04). The browser opens a
// WebSocket to the dzweb of EVERY unit (ws://<ip>:8080/osc) and sends to each
// one itself: no unit relays for another (dzweb accepts sockets from any page,
// and its HTTP replies carry Access-Control-Allow-Origin: *). Any unit (or a
// local copy of the www folder) can serve this page. Units: found with GET
// /units of the serving unit (dzweb broadcasts /info), or added by IP; the
// list, the order and the selection stay in this browser (localStorage).
// A fleet command goes to the selected units in list order, one WebSocket
// message each (sub-millisecond apart on the LAN; FLEET.md section 0).
import * as osc from "./osc.js";
import { h, card, row, toast, store } from "./ui.js";

const PORT = location.protocol.startsWith("http") && location.port ? location.port : "8080";
const POLL = ["/stats", "/vsync", "/video/mode", "/cue/status", "/info"];
const conns = new Map(); // ip -> { ws, open, rtt, pingT, host, mac, stats, vsync, mode, cue }
let units = store.get("fleet.units", []); // [{ ip, sel }]
let modes = [];
let ui = {};

const save = () => store.set("fleet.units", units.map(({ ip, sel }) => ({ ip, sel })));
const sel = () => units.filter((u) => u.sel && conns.get(u.ip)?.open);
const label = (ip) => conns.get(ip)?.host || ip;

// ---- connections ---------------------------------------------------------------
function connect(ip) {
  const c = conns.get(ip) || { ip };
  conns.set(ip, c);
  if (c.ws && c.ws.readyState <= 1) return;
  let ws;
  try {
    ws = new WebSocket(`ws://${ip}:${PORT}/osc`);
  } catch {
    return;
  }
  ws.binaryType = "arraybuffer";
  c.ws = ws;
  ws.onopen = () => {
    c.open = true;
    send(ip, osc.bundle(...POLL.map((p) => osc.message(p))));
    send(ip, osc.message("/video/modes"));
    render();
  };
  ws.onclose = () => {
    c.open = false;
    render();
    if (units.some((u) => u.ip === ip)) setTimeout(() => connect(ip), 2000);
  };
  ws.onerror = () => {};
  ws.onmessage = (e) => {
    let msgs;
    try {
      msgs = osc.decode(e.data);
    } catch {
      return;
    }
    for (const m of msgs) reply(c, m);
  };
}

function send(ip, pkt) {
  const c = conns.get(ip);
  if (c?.open) c.ws.send(pkt);
}

function reply(c, m) {
  const a = m.args;
  switch (m.path) {
    case "/pong": c.rtt = performance.now() - c.pingT; return;
    case "/stats": c.stats = a; return;
    case "/vsync": c.vsync = a; return;
    case "/video/mode": c.mode = a; if (modes.length && !ui.modeSet) { ui.modeSet = true; fillModes(); } return;
    case "/cue/status": c.cue = a; return; // the cue column (also after a fleet GO)
    case "/info": c.host = a[4]; c.mac = a[5]; return;
    case "/video/modes": if (!modes.length && a.length) { modes = a; fillModes(); } return;
  }
  log(`${label(c.ip)}  ${m.path} ${a.map((v) => (typeof v === "string" ? JSON.stringify(v) : Number.isInteger(v) ? v : v.toFixed(3))).join(" ")}`);
}

// ---- fan-out --------------------------------------------------------------------
// fn(unit, index, count) -> a packet (Uint8Array) or null; the selected units, in order
function fan(fn, what) {
  const list = sel();
  if (!list.length) return toast("no unit selected (or none connected)", true);
  const t0 = performance.now();
  list.forEach((u, i) => {
    const p = fn(u, i, list.length);
    if (p) send(u.ip, p);
  });
  const dt = performance.now() - t0;
  if (what) log(`→ ${list.length} unit(s) in ${dt.toFixed(2)} ms: ${what}`);
}

function fanMsg(path, ...args) {
  fan(() => osc.message(path, ...args), `${path} ${args.map((v) => (v && v.__f ? v.v : v)).join(" ")}`);
}

function identify(ips) {
  for (const ip of ips)
    for (let k = 0; k < 6; k++) setTimeout(() => send(ip, osc.message("/led/red", k % 2 ? 0 : 1)), k * 250);
}

// the spread value of unit i of n
function spread(mode, a, b, i, n) {
  const t = n > 1 ? i / (n - 1) : 0;
  switch (mode) {
    case "ramp": return a + (b - a) * t;
    case "reverse": return b + (a - b) * t;
    case "alternate": return i % 2 ? b : a;
    case "random": return a + (b - a) * Math.random();
    default: return a;
  }
}

// ---- units ------------------------------------------------------------------------
function addUnit(ip) {
  ip = ip.trim();
  if (!ip || units.some((u) => u.ip === ip)) return false;
  units.push({ ip, sel: true });
  save();
  connect(ip);
  return true;
}

async function scan() {
  const base = location.protocol.startsWith("http") ? location.hostname : units[0]?.ip;
  if (!base) return toast("add one unit by IP first (this page is not served by a unit)", true);
  try {
    const r = await fetch(`http://${base}:${PORT}/units`, { cache: "no-store" });
    const list = await r.json();
    let added = 0;
    for (const u of list) added += addUnit(u.ip || base) ? 1 : 0;
    toast(`${list.length} unit(s) on the LAN, ${added} new`);
  } catch (e) {
    toast(`scan through ${base} failed: ${e.message || e}`, true);
  }
  render();
}

function move(i, d) {
  const j = i + d;
  if (j < 0 || j >= units.length) return;
  [units[i], units[j]] = [units[j], units[i]];
  save();
  render();
}

// ---- view -------------------------------------------------------------------------
function cell(text, title, cls) {
  return h(`td${cls ? "." + cls : ""}`, { title: title || "" }, text);
}

function render() {
  if (!ui.body) return;
  const on = units.filter((u) => conns.get(u.ip)?.open).length;
  ui.sum.textContent = `${on} of ${units.length} connected · ${sel().length} selected`;
  ui.sum.className = "chip " + (on === units.length && on ? "ok" : on ? "warn" : "off");
  ui.body.replaceChildren(...units.map((u, i) => {
    const c = conns.get(u.ip) || {};
    const s = c.stats, v = c.vsync, md = c.mode, q = c.cue;
    const box = h("input", { type: "checkbox", checked: !!u.sel, title: "fleet commands go to the selected units",
      onchange: () => { u.sel = box.checked; save(); render(); } });
    return h(`tr${c.open ? "" : ".off"}`, {},
      h("td", {}, box),
      h("td", {}, h("button.ghost", { title: "earlier in the order (spreads)", onclick: () => move(i, -1) }, "↑"),
        h("button.ghost", { title: "later in the order", onclick: () => move(i, 1) }, "↓")),
      h("td", { title: c.mac ? `MAC ${c.mac}` : "" }, h("span.dot" + (c.open ? ".on" : "")), c.host || "–"),
      cell(u.ip),
      cell(c.open && c.rtt ? `${c.rtt.toFixed(1)} ms` : "–", "round trip of /ping through its WebSocket", "num"),
      cell(md ? `${md[3] || `${md[0]}x${md[1]}`}` : "–", "/video/mode"),
      cell(v ? `${v[1].toFixed(2)} Hz` : "–", v ? `vsync: ${v[0]} frames, jitter ${v[2].toFixed(0)} us` : "/vsync", "num"),
      cell(s ? `${s[0].toFixed(0)} %` : "–", s ? `debazd ${s[0].toFixed(1)} %, all ${s[1].toFixed(0)} %, load ${s[5].toFixed(2)}, ${(s[6] / 1024).toFixed(0)} MB free` : "/stats", "num"),
      cell(s && s[7] > 0 ? `${s[7].toFixed(0)} °C` : "–", "die temperature", "num"),
      cell(q && q[1] ? `${q[1]} ${Number(q[2]).toFixed(1)}${q[8] >= 0 ? ` (next ${q[8].toFixed(1)} s)` : q[8] === -2 ? " (next at end)" : ""}` : "–",
        q ? `show ${q[0]}, cue "${q[3]}"` : "/cue/status"),
      h("td", {},
        h("button", { title: "blink /led/red 3 times", onclick: () => identify([u.ip]) }, "Identify"),
        h("a.button.ghost", { href: `http://${u.ip}:${PORT}/`, target: "_blank", title: "the full UI of this unit" }, "UI ↗"),
        h("button.ghost", { title: "remove from this list", onclick: () => {
          units = units.filter((x) => x.ip !== u.ip); save(); conns.get(u.ip)?.ws?.close(); conns.delete(u.ip); render();
        } }, "✕")));
  }));
}

function log(line) {
  const t = new Date().toTimeString().slice(0, 8);
  ui.log.textContent = `${t}  ${line}\n` + ui.log.textContent.split("\n").slice(0, 200).join("\n");
}

// the mode list, preselected on the running mode of the first unit (Apply
// must not switch to the first entry by accident)
function fillModes() {
  const now = [...conns.values()].find((c) => c.mode)?.mode?.[3];
  ui.mode.replaceChildren(...modes.map((m) => h("option", { value: m, selected: m === now }, m)));
}

function input(attrs) {
  return h("input", { type: "text", ...attrs });
}

function init() {
  const root = document.getElementById("fleet");
  ui.sum = document.getElementById("st-sum");
  ui.body = h("tbody");
  ui.log = h("pre.log", {}, "");
  ui.mode = h("select", { title: "/video/mode <name> (hdmi2 restarts on each unit)" });
  const addIp = input({ placeholder: "10.42.0.x", style: "width:9em", title: "a unit's IPv4 address" });
  const line = input({ placeholder: "/led/red 1", style: "flex:1", title: "an OSC message: /path args (1 = int, 1.0 = float, \"text\")" });
  const scene = input({ placeholder: "scene", style: "width:8em", title: "the scene name (each unit's own show)" });
  const num = h("input", { type: "number", value: 1, step: 0.5, min: 0, style: "width:5em", title: "cue number" });
  const sAddr = input({ value: "/hdmi/1/gain/r", style: "flex:1", title: "the address that gets one value per unit" });
  const sFrom = h("input", { type: "number", value: 0, step: "any", style: "width:6em", title: "value of the first unit" });
  const sTo = h("input", { type: "number", value: 255, step: "any", style: "width:6em", title: "value of the last unit" });
  const sMode = h("select", { title: "same: every unit a; ramp: a .. b over the order; reverse: b .. a; alternate: a b a b; random: a .. b" },
    ["same", "ramp", "reverse", "alternate", "random"].map((m) => h("option", { value: m }, m)));
  const sType = h("select", { title: "int: rounded (a raw register value); float: as is (0..1 = across the field)" },
    h("option", { value: "int" }, "int"), h("option", { value: "float" }, "float"));
  const sendLine = () => {
    const p = osc.parseLine(line.value);
    if (!p) return toast("an OSC message starts with /", true);
    fanMsg(p.path, ...p.args);
  };
  line.addEventListener("keydown", (e) => { if (e.key === "Enter") sendLine(); });
  const sendSpread = () => {
    const a = Number(sFrom.value), b = Number(sTo.value), path = sAddr.value.trim();
    if (!path.startsWith("/")) return toast("an address starts with /", true);
    const vals = [];
    fan((u, i, n) => {
      const v = spread(sMode.value, a, b, i, n), arg = sType.value === "int" ? Math.round(v) : osc.float(v);
      vals.push(`${label(u.ip)}=${sType.value === "int" ? Math.round(v) : v.toFixed(3)}`);
      return osc.message(path, arg);
    });
    log(`spread ${path} ${sMode.value}: ${vals.join("  ")}`);
  };

  root.append(
    card("Units",
      row(null, h("button.primary", { title: "GET /units of the serving unit (it broadcasts /info on the LAN)", onclick: scan }, "Scan"),
        addIp, h("button", { onclick: () => { if (addUnit(addIp.value)) { addIp.value = ""; render(); } } }, "Add"),
        h("button", { onclick: () => { units.forEach((u) => (u.sel = true)); save(); render(); } }, "All"),
        h("button", { onclick: () => { units.forEach((u) => (u.sel = false)); save(); render(); } }, "None"),
        h("button", { title: "blink /led/red on the selected units", onclick: () => identify(sel().map((u) => u.ip)) }, "Identify selected")),
      h("div.wrap", {}, h("table.units", {},
        h("thead", {}, h("tr", {}, ...["", "order", "unit", "IP", "round trip", "mode", "vsync", "debazd", "temp", "cue", ""].map((t) => h("th", {}, t)))),
        ui.body)),
      h("p.hint", {}, "This browser talks to each unit's dzweb itself (ws://<ip>:" + PORT + "/osc): no unit relays for " +
        "another. Commands go to the selected units in this order.")),
    h("div.grid", {},
      card("Send",
        row(null, line, h("button.primary", { onclick: sendLine }, "Send")),
        h("p.hint", {}, "Any OSC message to every selected unit, e.g. /disp/0/blank 1, /movie/6/play \"x.mkv\" 0 0, /show/load myshow. " +
          "Replies show in the log.")),
      card("Cues",
        row("cue", scene, num,
          h("button.primary", { title: "/cue/go <scene> <num>", onclick: () => scene.value ? fanMsg("/cue/go", scene.value, osc.float(Number(num.value))) : toast("scene name", true) }, "GO")),
        row(null,
          h("button", { title: "/cue/next", onclick: () => fanMsg("/cue/next") }, "Next ▶"),
          h("button", { title: "/cue/back", onclick: () => fanMsg("/cue/back") }, "◀ Back"),
          h("button.danger", { title: "/cue/stop (fades and follows)", onclick: () => fanMsg("/cue/stop") }, "Stop")),
        h("p.hint", {}, "Each unit plays its own show (load the same show name on all, or different ones).")),
      card("Displays",
        row("blank", h("button", { onclick: () => { fanMsg("/disp/0/blank", 1); fanMsg("/disp/1/blank", 1); } }, "Blank"),
          h("button", { onclick: () => { fanMsg("/disp/0/blank", 0); fanMsg("/disp/1/blank", 0); } }, "Unblank"),
          h("button", { title: "/disp/<d>/home", onclick: () => { fanMsg("/disp/0/home"); fanMsg("/disp/1/home"); } }, "Home")),
        row("mode", ui.mode, h("button", { onclick: () => {
          if (ui.mode.value && confirm(`Set ${ui.mode.value} on ${sel().length} unit(s)? (hdmi2 restarts; do not do it while a capture input streams)`))
            fanMsg("/video/mode", ui.mode.value);
        } }, "Apply"))),
      card("Spread",
        row("address", sAddr),
        row("values", sFrom, h("span.hint", {}, "→"), sTo, sMode, sType, h("button.primary", { onclick: sendSpread }, "Send")),
        h("p.hint", {}, "One value per selected unit, over the list order (FLEET.md 1.2). Example: /hdmi/1/gain/r 0 → 255 ramp."))),
    card("Log", ui.log));

  for (const u of units) connect(u.ip);
  if (!units.length && location.protocol.startsWith("http")) scan();
  setInterval(() => {
    for (const u of units) {
      const c = conns.get(u.ip);
      if (!c?.open) continue;
      c.pingT = performance.now();
      send(u.ip, osc.message("/ping"));
      send(u.ip, osc.bundle(...POLL.map((p) => osc.message(p))));
    }
    render();
  }, 2000);
  render();
}

init();
