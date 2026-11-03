// net.js - connection to one or more debazd units through dzweb (WebSocket
// at /osc). Messages are OSC packets (osc.js). Reconnects by itself.
import * as osc from "./osc.js";

export const message = osc.message;
export const bundle = osc.bundle;
export const float = osc.float;

const listeners = new Map(); // path prefix -> Set(fn)
const anyListeners = new Set();
let primary = null; // { url, ws }
let extras = []; // other units when "send to all units" is on
let statusFn = () => {};

export function onStatus(fn) {
  statusFn = fn;
}

function openSocket(url, isPrimary) {
  const conn = { url, ws: null, dead: false };
  start(conn, isPrimary);
  return conn;
}

// (Re)open the socket of one connection object; stops when conn.dead is set.
function start(conn, isPrimary) {
  const ws = new WebSocket(conn.url);
  ws.binaryType = "arraybuffer";
  conn.ws = ws;
  ws.onopen = () => {
    if (!isPrimary) return;
    statusFn(true);
    send(osc.message("/subscribe")); // events: io, hpd, capture
    for (const fn of reconnectHooks) fn();
  };
  ws.onmessage = (e) => {
    if (!isPrimary) return; // replies come from the primary unit only
    for (const m of osc.decode(e.data)) dispatch(m);
  };
  ws.onclose = () => {
    if (conn.dead) return;
    if (isPrimary) statusFn(false);
    setTimeout(() => {
      if (!conn.dead) start(conn, isPrimary);
    }, 1500);
  };
}

const reconnectHooks = new Set();
export function onConnect(fn) {
  reconnectHooks.add(fn);
}

// host "" = the board that served this page
export function connect(host) {
  if (primary) {
    primary.dead = true;
    primary.ws.close();
  }
  const h = host || location.host;
  const hostport = h.includes(":") ? h : `${h}:${location.port || 8080}`;
  base = `http://${hostport}`;
  primary = openSocket(`ws://${hostport}/osc`, true);
}

// HTTP address of the selected unit's dzweb (file transfer: /media)
let base = "";
export function httpBase() {
  return base;
}

export function setExtras(hosts) {
  for (const c of extras) {
    c.dead = true;
    c.ws.close();
  }
  extras = hosts.map((h) => openSocket(`ws://${h.includes(":") ? h : h + ":" + (location.port || 8080)}/osc`, false));
}

function rawSend(conn, pkt) {
  if (conn && conn.ws.readyState === 1) conn.ws.send(pkt);
}

// ---- OSC hover text (2026-11-02): every control shows the message it sent ----
// While a click / input / change handler runs, its control is the "actor"; a packet
// sent then (directly or later by throttled) is written into the control's title as
// "sent: /addr args", under the control's own title. For scripting and tests: hover a
// control after using it to see the exact message.
let actor = null;
const ACTOR_SEL = "button, input, select, textarea, canvas, a, label";
for (const ev of ["click", "input", "change", "keydown", "pointerdown", "pointerup"])
  document.addEventListener(ev, (e) => {
    actor = e.target?.closest?.(ACTOR_SEL) || null;
    setTimeout(() => { actor = null; }, 0);
  }, true);

const argText = (a, t) => (t === "s" ? JSON.stringify(a) : t === "f" ? String(+a.toFixed(4)) : String(a));
export function describe(pkt) {
  const out = [];
  for (const m of osc.decode(pkt)) out.push([m.path, ...m.args.map((a, k) => argText(a, m.tags?.[k]))].join(" "));
  return out;
}
function annotate(el, pkt) {
  if (!el || !el.isConnected) return;
  let lines;
  try { lines = describe(pkt); } catch { return; }
  if (!lines.length) return;
  if (el.dataset.baseTitle === undefined) el.dataset.baseTitle = el.title || "";
  const shown = lines.length > 6 ? [...lines.slice(0, 6), `… ${lines.length - 6} more`] : lines;
  el.title = (el.dataset.baseTitle ? el.dataset.baseTitle + "\n" : "") + "sent: " + shown.join("\n      ");
}

// Send a packet (Uint8Array) to the primary unit and, if set, all extras.
export function send(pkt) {
  annotate(actor, pkt);
  rawSend(primary, pkt);
  for (const c of extras) rawSend(c, pkt);
}

// Shorthand: msg("/path", args...)
export function msg(path, ...args) {
  send(osc.message(path, ...args));
}

export function connected() {
  return !!primary && primary.ws.readyState === 1;
}

function dispatch(m) {
  for (const fn of anyListeners) fn(m);
  for (const [prefix, set] of listeners) {
    if (m.path === prefix || m.path.startsWith(prefix + "/")) for (const fn of set) fn(m);
  }
}

// Listen to replies/events whose path is `prefix` or below it.
export function on(prefix, fn) {
  if (!listeners.has(prefix)) listeners.set(prefix, new Set());
  listeners.get(prefix).add(fn);
  return () => listeners.get(prefix).delete(fn);
}

export function onAny(fn) {
  anyListeners.add(fn);
}

// Send a query and collect replies with path `item` until `end` (or timeout).
// List queries share reply names (/file, /field), so they run one at a time.
let chain = Promise.resolve();
export function collect(pkt, item, end, timeout = 1500) {
  const run = () => new Promise((resolve) => {
    const items = [];
    const offItem = on(item, (m) => {
      if (m.path !== item) return;
      const a = m.args;
      a.tags = m.tags;	// OSC types of the args, e.g. "ssi"
      items.push(a);
    });
    const offEnd = on(end, () => finish());
    const timer = setTimeout(finish, timeout);
    function finish() {
      clearTimeout(timer);
      offItem();
      offEnd();
      resolve(items);
    }
    send(pkt);
  });
  const p = chain.then(run);
  chain = p.catch(() => {});
  return p;
}

// Send a query and resolve with the first reply that `match` accepts.
export function ask(pkt, match, timeout = 1000) {
  return new Promise((resolve) => {
    const off = (fn) => anyListeners.delete(fn);
    const fn = (m) => {
      if (match(m)) {
        clearTimeout(timer);
        off(fn);
        resolve(m);
      }
    };
    const timer = setTimeout(() => {
      off(fn);
      resolve(null);
    }, timeout);
    anyListeners.add(fn);
    send(pkt);
  });
}

// Read one field: resolves with { raw, norm } or null.
export async function getField(path) {
  const m = await ask(osc.message(path), (m) => m.path === "/value" && m.args[0] === path);
  return m ? { raw: m.args[1], norm: m.args[2] } : null;
}

// Coalesce fast changes (sliders): send at most once per animation frame per key.
const pending = new Map(), pendingActor = new Map();
let scheduled = false;
export function throttled(key, pktFn) {
  pending.set(key, pktFn);
  if (actor) pendingActor.set(key, actor);
  if (scheduled) return;
  scheduled = true;
  requestAnimationFrame(() => {
    scheduled = false;
    const keys = [...pending.keys()], all = keys.map((k) => pending.get(k)());
    keys.forEach((k, i) => annotate(pendingActor.get(k), all[i]));
    pending.clear();
    pendingActor.clear();
    const was = actor;
    actor = null;	// annotated per key above
    send(all.length === 1 ? all[0] : osc.bundle(...all));
    actor = was;
  });
}
