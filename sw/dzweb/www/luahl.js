// luahl.js - Lua in the editor: highlighting (a coloured <pre> under a
// transparent textarea), the lint (luaparse.js, MIT, vendored, LuaJIT
// syntax: errors + names that are neither defined nor in the API) and
// the API help for the word at the cursor.
import { KNOWN, LOOKUP } from "./luaapi.js";

const KW = new Set(("and break do else elseif end false for function goto if in local nil not or " +
  "repeat return then true until while").split(" "));

// tokens: [start, end, class]; class "" = plain
export function tokens(s) {
  const out = [];
  const n = s.length;
  let i = 0;
  const longEnd = (j) => {			// s[j] = "[": long bracket -> end index or -1
    const m = /^\[(=*)\[/.exec(s.slice(j, j + 64));
    if (!m) return -1;
    const close = "]" + m[1] + "]";
    const e = s.indexOf(close, j + m[0].length);
    return e < 0 ? n : e + close.length;
  };
  while (i < n) {
    const c = s[i];
    if (c === "-" && s[i + 1] === "-") {
      let e = s[i + 2] === "[" ? longEnd(i + 2) : -1;
      if (e < 0) { e = s.indexOf("\n", i); if (e < 0) e = n; }
      out.push([i, e, "cm"]); i = e; continue;
    }
    if (c === "[" && (s[i + 1] === "[" || s[i + 1] === "=")) {
      const e = longEnd(i);
      if (e > 0) { out.push([i, e, "st"]); i = e; continue; }
    }
    if (c === '"' || c === "'") {
      let j = i + 1;
      while (j < n && s[j] !== c && s[j] !== "\n") j += s[j] === "\\" ? 2 : 1;
      j = Math.min(n, j + (s[j] === c ? 1 : 0));
      out.push([i, j, "st"]); i = j; continue;
    }
    if (/[0-9]/.test(c) || (c === "." && /[0-9]/.test(s[i + 1] || ""))) {
      const m = /^(0[xX][0-9a-fA-F.]*([pP][+-]?\d+)?|[0-9.]+([eE][+-]?\d+)?)(ULL|LL|ull|ll|i)?/.exec(s.slice(i, i + 64));
      out.push([i, i + m[0].length, "nu"]); i += m[0].length; continue;
    }
    if (/[A-Za-z_]/.test(c)) {
      const m = /^[A-Za-z_][A-Za-z0-9_]*/.exec(s.slice(i, i + 128));
      const w = m[0];
      const prev = s[i - 1];
      let cls = "";
      if (KW.has(w) && prev !== ".") cls = "kw";
      else if (prev === ":" && LOOKUP.has(":" + w)) cls = "api";
      else if (prev === "." && /audio\.$/.test(s.slice(Math.max(0, i - 6), i)) && LOOKUP.has("audio." + w)) cls = "api";
      else if (prev !== "." && prev !== ":" && LOOKUP.has(w)) cls = "api";
      else if (prev !== "." && prev !== ":" && KNOWN.has(w)) cls = "lib";
      out.push([i, i + w.length, cls]); i += w.length; continue;
    }
    i++;
  }
  return out;
}

const esc = (t) => t.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");

// HTML of s; marks = Map(offset -> length) of words to underline
export function highlight(s, marks) {
  let html = "", at = 0;
  for (const [a, b, cls] of tokens(s)) {
    if (a > at) html += esc(s.slice(at, a));
    let c = cls;
    if (marks && marks.has(a)) c = (c ? c + " " : "") + "wv";
    html += c ? `<span class="${c}">${esc(s.slice(a, b))}</span>` : esc(s.slice(a, b));
    at = b;
  }
  return html + esc(s.slice(at)) + "\n ";
}

// ---- lint -----------------------------------------------------------------
let lp = null;
function loadParser() {
  if (lp) return lp;
  lp = new Promise((ok) => {
    if (window.luaparse) return ok(window.luaparse);
    const sc = document.createElement("script");
    sc.src = "luaparse.js";
    sc.onload = () => ok(window.luaparse || null);
    sc.onerror = () => ok(null);
    document.head.append(sc);
  });
  return lp;
}

// -> { ok: parser loaded, error: {line, col, msg} | null, warns: [{line, col, off, len, msg}] }
export async function lint(src) {
  const P = await loadParser();
  if (!P) return { ok: false, error: null, warns: [] };
  const lineStart = [0];
  for (let i = 0; i < src.length; i++) if (src[i] === "\n") lineStart.push(i + 1);
  const ids = [], defined = new Set();
  try {
    P.parse(src, {
      luaVersion: "LuaJIT", scope: true, locations: true, comments: false,
      onCreateNode: (nd) => {
        if (nd.type === "Identifier") ids.push(nd);
        else if (nd.type === "AssignmentStatement") {
          for (const v of nd.variables) if (v.type === "Identifier" && !v.isLocal) defined.add(v.name);
        } else if (nd.type === "FunctionDeclaration" && nd.identifier && nd.identifier.type === "Identifier" && !nd.isLocal) {
          defined.add(nd.identifier.name);
        }
      },
    });
  } catch (e) {
    if (e.line == null) return { ok: true, error: { line: 1, col: 0, msg: String(e.message || e) }, warns: [] };
    return { ok: true, error: { line: e.line, col: e.column, msg: e.message.replace(/^\[\d+:\d+\]\s*/, "") }, warns: [] };
  }
  const warns = [], seen = new Set();
  for (const id of ids) {
    if (id.isLocal !== false || KNOWN.has(id.name) || defined.has(id.name) || !id.loc) continue;
    const line = id.loc.start.line, col = id.loc.start.column;
    const off = lineStart[line - 1] + col;
    warns.push({ line, col, off, len: id.name.length,
      msg: seen.has(id.name) ? "" : `'${id.name}' is not defined (a typo? not in the API, never assigned)` });
    seen.add(id.name);
  }
  return { ok: true, error: null, warns };
}

// ---- help at the cursor ------------------------------------------------------
// the API entry for the word at `pos`, else for the function whose "(" the
// cursor is inside (same line)
export function helpAt(s, pos) {
  const ls = s.lastIndexOf("\n", pos - 1) + 1;
  const line = s.slice(ls, s.indexOf("\n", pos) < 0 ? s.length : s.indexOf("\n", pos));
  const p = pos - ls;
  const look = (w, pre) => {
    if (pre === ":" && LOOKUP.has(":" + w)) return ":" + w;
    if (pre === "audio." && LOOKUP.has("audio." + w)) return "audio." + w;
    return LOOKUP.has(w) ? w : null;
  };
  const wordAt = (q) => {
    let a = q, b = q;
    while (a > 0 && /\w/.test(line[a - 1])) a--;
    while (b < line.length && /\w/.test(line[b])) b++;
    if (a === b) return null;
    const pre = line[a - 1] === ":" ? ":" : /audio\.$/.test(line.slice(0, a)) ? "audio." : "";
    return look(line.slice(a, b), pre);
  };
  let k = wordAt(p);
  if (!k) {					// inside f( ... ): the f
    let depth = 0;
    for (let q = p - 1; q >= 0; q--) {
      if (line[q] === ")") depth++;
      else if (line[q] === "(") {
        if (depth === 0) { k = wordAt(q); break; }
        depth--;
      }
    }
  }
  return k ? [k, ...LOOKUP.get(k)] : null;
}
