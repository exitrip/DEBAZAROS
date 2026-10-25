// osc.js - OSC 1.0 encode/decode for the DEBAZAROS web app (ES module).
// Values: integers -> 'i', other numbers -> 'f', strings -> 's',
// booleans -> 'T'/'F'. Force a float with osc.float(1).

const enc = new TextEncoder();
const dec = new TextDecoder();

export function float(v) {
  return { __f: true, v: Number(v) };
}

function pad4(n) {
  return (n + 3) & ~3;
}

function str(s) {
  const b = enc.encode(s);
  const out = new Uint8Array(pad4(b.length + 1));
  out.set(b);
  return out;
}

export function message(path, ...args) {
  const parts = [str(path)];
  let tags = ",";
  const data = [];
  for (const a of args) {
    if (a && a.__f) {
      tags += "f";
      const b = new DataView(new ArrayBuffer(4));
      b.setFloat32(0, a.v);
      data.push(new Uint8Array(b.buffer));
    } else if (typeof a === "number" && Number.isInteger(a)) {
      tags += "i";
      const b = new DataView(new ArrayBuffer(4));
      b.setInt32(0, a);
      data.push(new Uint8Array(b.buffer));
    } else if (typeof a === "number") {
      tags += "f";
      const b = new DataView(new ArrayBuffer(4));
      b.setFloat32(0, a);
      data.push(new Uint8Array(b.buffer));
    } else if (typeof a === "boolean") {
      tags += a ? "T" : "F";
    } else {
      tags += "s";
      data.push(str(String(a)));
    }
  }
  parts.push(str(tags), ...data);
  return concat(parts);
}

export function bundle(...msgs) {
  const head = new Uint8Array(16);
  head.set(enc.encode("#bundle"));
  head[15] = 1; // time tag 1 = immediately
  const parts = [head];
  for (const m of msgs) {
    const len = new DataView(new ArrayBuffer(4));
    len.setInt32(0, m.length);
    parts.push(new Uint8Array(len.buffer), m);
  }
  return concat(parts);
}

function concat(parts) {
  const n = parts.reduce((s, p) => s + p.length, 0);
  const out = new Uint8Array(n);
  let o = 0;
  for (const p of parts) {
    out.set(p, o);
    o += p.length;
  }
  return out;
}

function readStr(u8, pos) {
  let e = pos;
  while (e < u8.length && u8[e] !== 0) e++;
  return [dec.decode(u8.subarray(pos, e)), pad4(e - pos + 1)];
}

// Decode a packet into an array of { path, args }.
export function decode(buf) {
  const u8 = buf instanceof Uint8Array ? buf : new Uint8Array(buf);
  const dv = new DataView(u8.buffer, u8.byteOffset, u8.byteLength);
  if (u8.length >= 16 && dec.decode(u8.subarray(0, 7)) === "#bundle") {
    const out = [];
    let pos = 16;
    while (pos + 4 <= u8.length) {
      const n = dv.getInt32(pos);
      pos += 4;
      out.push(...decode(u8.subarray(pos, pos + n)));
      pos += n;
    }
    return out;
  }
  let [path, step] = readStr(u8, 0);
  let pos = step;
  const args = [];
  if (pos < u8.length && u8[pos] === 0x2c) {
    const [tags, ts] = readStr(u8, pos);
    pos += ts;
    for (const t of tags.slice(1)) {
      if (t === "i") { args.push(dv.getInt32(pos)); pos += 4; }
      else if (t === "f") { args.push(dv.getFloat32(pos)); pos += 4; }
      else if (t === "s") { const [s, n] = readStr(u8, pos); args.push(s); pos += n; }
      else if (t === "T") args.push(true);
      else if (t === "F") args.push(false);
      else break;
    }
  }
  return [{ path, args }];
}

// Parse a typed command line: /path 1 0.5 "text with spaces" word
export function parseLine(line) {
  const toks = [];
  const re = /"([^"]*)"|(\S+)/g;
  let m;
  while ((m = re.exec(line))) toks.push(m[1] !== undefined ? { s: m[1] } : m[2]);
  if (!toks.length || typeof toks[0] !== "string" || toks[0][0] !== "/") return null;
  const args = toks.slice(1).map((t) => {
    if (typeof t === "object") return t.s;
    if (/^-?(0x[0-9a-f]+|\d+)$/i.test(t)) return parseInt(t);
    if (/^-?\d*\.\d+(e-?\d+)?$/i.test(t)) return float(parseFloat(t));
    return t;
  });
  return { path: toks[0], args };
}
