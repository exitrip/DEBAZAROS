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

// Send a packet (Uint8Array) to the primary unit and, if set, all extras.
export function send(pkt) {
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
      if (m.path === item) items.push(m.args);
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
const pending = new Map();
let scheduled = false;
export function throttled(key, pktFn) {
  pending.set(key, pktFn);
  if (scheduled) return;
  scheduled = true;
  requestAnimationFrame(() => {
    scheduled = false;
    const all = [...pending.values()].map((f) => f());
    pending.clear();
    send(all.length === 1 ? all[0] : osc.bundle(...all));
  });
}
