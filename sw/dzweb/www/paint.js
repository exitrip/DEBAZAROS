// paint.js - draw into a slot with mouse, pen or touch. The canvas is the
// whole slot in board coordinates (1920x1080, 2026-11-04: the surface canvas,
// /surface/<s>/canvas) and shows a local preview of what you draw; effects
// that run on the board (grab, transforms) show on the display only. Guides:
// the output sizes from the top left, and the window each display shows when
// it shows this slot (/disp/<d>/crop; the Wall tab moves them).
// Live mode sends every stroke at once; batch mode keeps the drawing here (with
// undo / redo) until Send. Keys: B brush, L line, R rect, E ellipse, P shape,
// G gradient, F fill, I pick, T text, [ ] size, X swap colours, Ctrl+Z undo,
// Ctrl+Shift+Z / Ctrl+Y redo, Enter send (batch), Alt+click = pick a colour.
import * as sprites from "./sprites.js";
import * as net from "./net.js";
import { h, card, row, hexToRgb, store, toast } from "./ui.js";
import * as anim from "./anim.js";
import { colorPicker } from "./colorpick.js";

const W = 1920, H = 1080; // a whole slot (sw/lib/dz_hw.h: 7680-byte lines)
const SIZES = [[640, 480], [800, 600], [1024, 768], [1280, 720]]; // output modes (debazd disp.c video_modes)
// text as the board draws it (lib/dz_text.c text_norm, 2026-11-19): "\n", a newline,
// "\r\n", "\r" = a line break; "\t" or a tab = spaces to the next 4-column stop;
// "\\" = a backslash; other control / invisible characters dropped; the pixel
// font (ascii) draws one ? for a non-ASCII character
function normText(t, ascii) {
  let o = "", col = 0;
  const tab = () => { do { o += " "; } while (++col % 4); };
  for (let i = 0; i < t.length;) {
    if (t[i] === "\\" && "nrt\\".includes(t[i + 1] || "x")) {
      const e = t[i + 1];
      i += 2;
      if (e === "\\") { o += "\\"; col++; }
      else if (e === "t") tab();
      else { if (e === "r" && t[i] === "\\" && t[i + 1] === "n") i += 2; o += "\n"; col = 0; }
      continue;
    }
    const c = t.codePointAt(i), ch = String.fromCodePoint(c);
    i += ch.length;
    if (c === 13 || c === 10 || c === 0x2028 || c === 0x2029) {
      if (c === 13 && t[i] === "\n") i++;
      o += "\n"; col = 0;
    } else if (c === 9) tab();
    else if (c < 0x20 || c === 0x7f || (c >= 0x80 && c < 0xa0) || c === 0xad || (c >= 0x200b && c <= 0x200f) || c === 0xfeff) continue;
    else { o += ascii && c > 0x7e ? "?" : ch; col++; }
  }
  return o;
}

const MAXPTS = 13; // stroke: 5 fixed args + 13 points = 31 args (< 32)
const DEF = { slot: 6, tool: "brush", color: "#ff9a3c", color2: "#2040ff", fill: true, size: 24, hard: 0.4,
  alpha: 1, blend: "normal", text: "DEBAZAROS", ttf: 64, scale: 2, sprite: 0, sscale: 1, angle: 0,
  gangle: 45, tl: "#ff0000", tr: "#00ff00", bl: "#0000ff", br: "#ffffff",
  rz: 3, zoom: 1.04, dx: 8, dy: 0, waxis: 0, wamp: 12, wper: 90,
  rot: 0, sfill: "solid", sides: 5, pstyle: "star", inner: 0, skip: 2, gtype: "linear", batch: false, tol: 32,
  ltext: "", lfont: "ttf", lerase: true, llive: false, lafter: "keep" };
const s = { ...DEF, ...store.get("paint", {}) };
if (!s.lver) { s.lafter = "keep"; s.lver = 2; } // 2026-11-21: Shift+Enter keeps the text and the caret
const SHAPES = ["rect", "ellipse", "shape"]; // rotatable, gradient-filled (dz_shape.c)
const DRAG = ["line", "gradient", "live", ...SHAPES]; // tools that use press-drag-release
let cv, cx, ov, ox, gv, drawing = false, start = null, pending = [], last = null, raf = false;
let end = null, rotating = null, rotOut = null, rotEl = null; // drag state, rotation slider
let setTool = () => {}, toolKeys = {};
const brushSet = {}; // key -> setter of the Brush card controls

// the Brush card's sample: a dab and a wavy stroke on a checkerboard
function drawBrushPreview() {
  const c = brushPrev;
  if (!c) return;
  const w = c.canvas.width, hh = c.canvas.height, [r, g, b] = rgb();
  for (let x = 0; x < w; x += 10) for (let y = 0; y < hh; y += 10) {
    c.fillStyle = (x / 10 + y / 10) % 2 ? "#3a3a3a" : "#555";
    c.fillRect(x, y, 10, 10);
  }
  const rad0 = Math.min(s.size, hh / 2 - 4), dab = (x, y) => {
    const gr = c.createRadialGradient(x, y, rad0 * s.hard, x, y, rad0);
    gr.addColorStop(0, `rgba(${r},${g},${b},1)`);
    gr.addColorStop(1, `rgba(${r},${g},${b},0)`);
    c.fillStyle = gr;
    c.beginPath(); c.arc(x, y, rad0, 0, Math.PI * 2); c.fill();
  };
  c.save();
  c.globalAlpha = s.alpha;
  const x0 = rad0 + 6, x1 = w - rad0 - 6;
  for (let x = x0; x <= x1; x += Math.max(1, rad0 / 3)) dab(x, hh / 2 + Math.sin(((x - x0) / (x1 - x0 || 1)) * Math.PI * 2) * (hh / 2 - rad0 - 4) * 0.8);
  c.restore();
  c.fillStyle = "#fff";
  c.font = "12px system-ui";
  c.fillText(s.size > rad0 ? `${s.size} px (shown smaller)` : `${s.size} px`, 6, hh - 6);
}
function syncBrush() {
  for (const k of ["size", "hard", "alpha"]) brushSet[k]?.(s[k], true);
}


const save = () => store.set("paint", s);
const rgb = () => hexToRgb(s.color);
const rgb2 = () => hexToRgb(s.color2);
const thick = () => (s.fill ? 0 : Math.max(1, s.size | 0)); // 0 = filled
const rad = (d) => (d * Math.PI) / 180;
const gcd = (a, b) => (b ? gcd(b, a % b) : a);
const D = () => `/draw/${s.slot}`;

// ---- live or batch ----
// Batch: every action (a stroke, a shape, a button) waits with a snapshot of the
// preview before it; Undo puts the snapshot back, Send replays the messages in
// order (each action starts with the alpha and blend it was drawn with).
const ops = [], redo = [];
const SNAPS = 30; // snapshots kept (3.7 MB each); older actions can no longer be undone
let curOp = null, batchEl = null, picker = null, brushPrev = null;
const stateMsgs = () => [net.message(`${D()}/alpha`, net.float(s.alpha)), net.message(`${D()}/blend`, s.blend)];
function beginOp() {
  if (!s.batch || curOp) return;
  curOp = { pkts: stateMsgs(), n: 0, snap: cx.getImageData(0, 0, W, H) };
}
function endOp() {
  if (!curOp) return;
  if (curOp.n) {
    ops.push(curOp);
    redo.length = 0;
    let k = 0;
    for (let i = ops.length - 1; i >= 0; i--) if (ops[i].snap && ++k > SNAPS) ops[i].snap = null;
  }
  curOp = null;
  batchInfo();
}
function bsend(pkt) {
  if (!s.batch) return net.send(pkt);
  const open = !curOp;
  if (open) beginOp();
  curOp.pkts.push(pkt);
  curOp.n++;
  if (open) endOp();
}
const bmsg = (path, ...a) => bsend(net.message(path, ...a));
function undo() {
  if (!s.batch) return toast("Undo works in batch mode: switch to Batch, draw, then Send");
  const op = ops[ops.length - 1];
  if (!op) return;
  if (!op.snap) return toast("undo limit reached (30 actions)", true);
  ops.pop();
  op.after = cx.getImageData(0, 0, W, H);
  cx.putImageData(op.snap, 0, 0);
  redo.push(op);
  batchInfo();
}
function redoOp() {
  const op = redo.pop();
  if (!op) return;
  op.snap = cx.getImageData(0, 0, W, H);
  cx.putImageData(op.after, 0, 0);
  ops.push(op);
  batchInfo();
}
async function sendBatch() {
  const pk = ops.flatMap((o) => o.pkts);
  ops.length = 0;
  redo.length = 0;
  batchInfo();
  for (let i = 0; i < pk.length; i += 16) { // ~1000 messages/s: debazd keeps up
    net.send(net.bundle(...pk.slice(i, i + 16)));
    await new Promise((r) => requestAnimationFrame(r));
  }
  if (pk.length) toast(`sent ${pk.length} messages to slot ${s.slot}`);
}
function discard() {
  if (ops.length && ops[0].snap) cx.putImageData(ops[0].snap, 0, 0);
  else if (ops.length) toast("preview older than the undo limit: it may not match the board", true);
  ops.length = 0;
  redo.length = 0;
  batchInfo();
}
function batchInfo() {
  if (!batchEl) return;
  batchEl.textContent = s.batch ? `${ops.length} action${ops.length === 1 ? "" : "s"} waiting` +
    (redo.length ? ` · ${redo.length} to redo` : "") : "every stroke goes to the board at once";
}

function toBoard(e) {
  const r = cv.getBoundingClientRect();
  return [Math.round(((e.clientX - r.left) / r.width) * W), Math.round(((e.clientY - r.top) / r.height) * H)];
}

// ---- local preview ----
function previewStyle() {
  cx.globalAlpha = s.alpha;
  cx.globalCompositeOperation = { add: "lighter", lighten: "lighten", multiply: "multiply" }[s.blend] || "source-over";
}
function previewDot(x, y) {
  previewStyle();
  const [r, g, b] = rgb();
  const grad = cx.createRadialGradient(x, y, s.size * s.hard, x, y, s.size);
  grad.addColorStop(0, `rgba(${r},${g},${b},1)`);
  grad.addColorStop(1, `rgba(${r},${g},${b},0)`);
  cx.fillStyle = grad;
  cx.beginPath();
  cx.arc(x, y, s.size, 0, Math.PI * 2);
  cx.fill();
}
function previewSeg(a, b) {
  const d = Math.hypot(b[0] - a[0], b[1] - a[1]);
  const step = Math.max(1, s.size / 3);
  for (let t = step; t <= d; t += step)
    previewDot(a[0] + ((b[0] - a[0]) * t) / d, a[1] + ((b[1] - a[1]) * t) / d);
}

// local gradient like dz_draw_gradient: 0 deg = left to right, 90 = top to bottom
function previewGradient(deg, c1, c2, x = 0, y = 0, w = W, hh = H) {
  const r = (deg * Math.PI) / 180, cxm = x + w / 2, cym = y + hh / 2;
  const half = (Math.abs(Math.cos(r)) * w + Math.abs(Math.sin(r)) * hh) / 2;
  const g = cx.createLinearGradient(cxm - Math.cos(r) * half, cym - Math.sin(r) * half,
    cxm + Math.cos(r) * half, cym + Math.sin(r) * half);
  g.addColorStop(0, c1);
  g.addColorStop(1, c2);
  previewStyle();
  cx.fillStyle = g;
  cx.fillRect(x, y, w, hh);
}
// ---- shapes: same geometry as sw/lib/dz_shape.c ----
// drag a -> b: box; lock (Ctrl) = equal width and height
function geom(a, b, lock) {
  let dx = b[0] - a[0], dy = b[1] - a[1];
  if (lock) {
    const m = Math.max(Math.abs(dx), Math.abs(dy));
    dx = Math.sign(dx || 1) * m;
    dy = Math.sign(dy || 1) * m;
  }
  const x = Math.min(a[0], a[0] + dx), y = Math.min(a[1], a[1] + dy), w = Math.abs(dx), hh = Math.abs(dy);
  return { x, y, w, h: hh, cx: x + w / 2, cy: y + hh / 2, hx: w / 2, hy: hh / 2 };
}
// closed loops in the shape frame (centre 0,0, not rotated); points first at the top
function loops(kind, hx, hy) {
  const ring = (k, n, rx, ry) => {
    const a = -Math.PI / 2 + (2 * Math.PI * k) / n;
    return [rx * Math.cos(a), ry * Math.sin(a)];
  };
  const range = (n) => [...Array(n).keys()];
  if (kind === "rect") return [[[-hx, -hy], [hx, -hy], [hx, hy], [-hx, hy]]];
  if (kind === "ellipse") return [range(96).map((k) => ring(k, 96, hx, hy))];
  const n = Math.max(3, s.sides | 0);
  if (s.pstyle === "polygon") return [range(n).map((k) => ring(k, n, hx, hy))];
  if (s.pstyle === "star") {
    const inner = s.inner > 0 ? Math.min(1, s.inner) : n >= 5 ? Math.cos((2 * Math.PI) / n) / Math.cos(Math.PI / n) : 0.5;
    return [range(2 * n).map((k) => ring(k, 2 * n, hx * (k & 1 ? inner : 1), hy * (k & 1 ? inner : 1)))];
  }
  const k = s.skip % n || 1, g = gcd(n, k), m = n / g, pts = range(n).map((q) => ring(q, n, hx, hy));
  return range(g).map((l) => range(m).map((q) => pts[(l + q * k) % n]));
}
function path(ctx, kind, hx, hy) {
  ctx.beginPath();
  for (const lp of loops(kind, hx, hy)) {
    lp.forEach((p, i) => (i ? ctx.lineTo(...p) : ctx.moveTo(...p)));
    ctx.closePath();
  }
}
// preview fill in the shape frame (like dz_shape.c colour())
function fillStyle(ctx, g) {
  if (s.sfill === "solid") return s.color;
  let gr;
  if (s.sfill === "radial") {
    gr = ctx.createRadialGradient(0, 0, 0, 0, 0, Math.max(1, (g.hx + g.hy) / 2));
  } else {
    const gc = Math.cos(rad(s.gangle)), gs = Math.sin(rad(s.gangle));
    const d = [gc / Math.max(g.hx, 0.5), gs / Math.max(g.hy, 0.5)], dd = d[0] ** 2 + d[1] ** 2;
    const l = (Math.abs(gc) + Math.abs(gs)) / dd;
    gr = ctx.createLinearGradient(-l * d[0], -l * d[1], l * d[0], l * d[1]);
  }
  gr.addColorStop(0, s.color);
  gr.addColorStop(1, s.color2);
  return gr;
}
function drawShape(ctx, kind, g, preview) {
  const t = thick(), ins = (r) => (t ? Math.max(0.5, r - t / 2) : r);
  ctx.save();
  ctx.translate(g.cx, g.cy);
  ctx.rotate(rad(s.rot));
  path(ctx, kind, ins(g.hx), ins(g.hy));
  if (preview) {
    previewStyle();
    ctx.fillStyle = ctx.strokeStyle = fillStyle(ctx, g);
    ctx.lineWidth = t;
    ctx.lineJoin = "round";
    t ? ctx.stroke() : ctx.fill(kind === "shape" && s.pstyle === "starpoly" ? "evenodd" : "nonzero");
  } else {
    ctx.stroke();
  }
  ctx.restore();
}
function fillMsg() {
  if (s.sfill === "solid") return net.message(`${D()}/fill`, "solid");
  if (s.sfill === "radial") return net.message(`${D()}/fill`, "radial", ...rgb2());
  return net.message(`${D()}/fill`, "linear", ...rgb2(), net.float(s.gangle));
}
function shapeMsg(kind, g) {
  const [r, gg, b] = rgb(), t = thick(), ang = net.float(s.rot);
  const c = [Math.round(g.cx), Math.round(g.cy), Math.max(1, Math.round(g.hx)), Math.max(1, Math.round(g.hy))];
  if (kind === "rect") return net.message(`${D()}/rect`, r, gg, b, Math.round(g.x), Math.round(g.y), Math.round(g.w), Math.round(g.h), t, ang);
  if (kind === "ellipse") return net.message(`${D()}/ellipse`, r, gg, b, ...c, t, ang);
  if (s.pstyle === "polygon") return net.message(`${D()}/polygon`, r, gg, b, ...c, s.sides | 0, t, ang);
  if (s.pstyle === "star") return net.message(`${D()}/star`, r, gg, b, ...c, s.sides | 0, net.float(s.inner), t, ang);
  return net.message(`${D()}/starpoly`, r, gg, b, ...c, s.sides | 0, s.skip | 0, t, ang);
}
function setRot(v) {
  s.rot = Math.round(((v + 540) % 360) - 180);
  if (rotEl) { rotEl.value = s.rot; rotOut.textContent = s.rot; }
  save();
  if (lbox && !drawing) liveRedraw();
}
// rubber band on the overlay while a drag tool is down
function band(a, b, lock) {
  ox.clearRect(0, 0, W, H);
  ox.strokeStyle = "#fff";
  ox.setLineDash([12, 8]);
  ox.lineWidth = 3;
  if (SHAPES.includes(s.tool)) return drawShape(ox, s.tool, geom(a, b, lock), false);
  if (s.tool === "live") return drawShape(ox, "rect", geom(a, b, lock), false);
  ox.beginPath();
  if (s.tool === "gradient" && s.gtype === "radial") ox.arc(a[0], a[1], Math.hypot(b[0] - a[0], b[1] - a[1]), 0, Math.PI * 2);
  else { ox.moveTo(...a); ox.lineTo(...b); }
  ox.stroke();
}
function previewRadial(x, y, r) {
  const g = cx.createRadialGradient(x, y, 0, x, y, r);
  g.addColorStop(0, s.color);
  g.addColorStop(1, s.color2);
  previewStyle();
  cx.fillStyle = g;
  cx.fillRect(0, 0, W, H);
}
const dragAngle = (a, b) => Math.round((Math.atan2(b[1] - a[1], b[0] - a[0]) * 180) / Math.PI);

// ---- live text (2026-11-21): drag a box (Shift: rotate = the rotation
// slider), type into it, Shift+Enter (or Ctrl+Enter) draws it on the board.
// The text wraps at the box width and shrinks until it fits the box height
// (max = the ttf px / pixel × slider). "live" = draw every change at once (the
// box is erased with colour 2 first). The board measures ttf text with its
// own font; the wrap here uses the browser's sans-serif with a 6 % margin, so
// a ttf line can end a little short or long. The pixel font is exact (8 × 16).
let lbox = null, livein = null, liveInfo = null;
const mctx = document.createElement("canvas").getContext("2d");
const TTF_LH = 1.17; // line height / px of LiberationSans (dz_text.c line_metrics)
// lines + where each line starts in the text (out.starts: for the caret)
function liveWrap(text, maxW, width) {
  const out = [], starts = [];
  let pos = 0;
  for (const para of text.split("\n")) {
    let line = "", ls = pos;
    for (const word of para.split(/(?<= )/)) { // keep the spaces at the word ends
      if (width(line + word) <= maxW || !line) { line += word; } else { out.push(line.trimEnd()); starts.push(ls); ls += line.length; line = word; }
      while (width(line) > maxW && line.length > 1) { // a word longer than the box: break it
        let k = line.length - 1;
        while (k > 1 && width(line.slice(0, k)) > maxW) k--;
        out.push(line.slice(0, k)); starts.push(ls);
        ls += k;
        line = line.slice(k);
      }
    }
    out.push(line.trimEnd()); starts.push(ls);
    pos += para.length + 1;
  }
  out.starts = starts;
  return out;
}
function liveLayout() {
  const pix = s.lfont === "pixel", t = normText(s.ltext || "", pix);
  if (pix) {
    for (let sc = Math.max(1, s.scale | 0); ; sc--) {
      const cols = Math.max(1, Math.floor(lbox.w / (8 * sc)));
      const lines = liveWrap(t, cols, (x) => [...x].length);
      if (lines.length * 16 * sc <= lbox.h || sc === 1) {
        const tw = Math.max(1, ...lines.map((l) => [...l].length)) * 8 * sc;
        return { pix, lines, size: sc, lh: 16 * sc, tw, th: lines.length * 16 * sc, font: `${16 * sc}px monospace` };
      }
    }
  }
  for (let px = Math.max(8, s.ttf | 0); ; px = Math.max(8, Math.floor(px * 0.94))) {
    mctx.font = `${px}px sans-serif`;
    const width = (x) => mctx.measureText(x).width;
    const lines = liveWrap(t, lbox.w * 0.94, width), lh = Math.ceil(px * TTF_LH);
    if (lines.length * lh <= lbox.h || px === 8) {
      const tw = Math.max(1, ...lines.map(width));
      return { pix, lines, size: px, lh, tw, th: lines.length * lh, font: `${px}px sans-serif` };
    }
  }
}
// the board's x y: the top-left of the unrotated text, rotated about its centre;
// put that centre where the box's top-left corner keeps the text in the box
function livePos(L) {
  const a = rad(s.rot), vx = -lbox.w / 2 + L.tw / 2, vy = -lbox.h / 2 + L.th / 2;
  const cxw = lbox.cx + vx * Math.cos(a) - vy * Math.sin(a), cyw = lbox.cy + vx * Math.sin(a) + vy * Math.cos(a);
  return [Math.round(cxw - L.tw / 2), Math.round(cyw - L.th / 2)];
}
function liveMsgs(erase) {
  const L = liveLayout(), [r, g, b] = rgb(), m = [];
  if (erase) {
    m.push(net.message(`${D()}/fill`, "solid"));
    m.push(net.message(`${D()}/rect`, ...rgb2(), Math.round(lbox.cx - lbox.w / 2), Math.round(lbox.cy - lbox.h / 2),
      Math.round(lbox.w), Math.round(lbox.h), 0, net.float(s.rot)));
  }
  // a backslash typed stays one (the board reads \n \t \\ as escapes)
  const txt = L.lines.join("\n").replaceAll("\\", "\\\\"), [x, y] = livePos(L);
  if (txt.trim()) {
    if (L.pix) m.push(net.message(`${D()}/text`, r, g, b, x, y, txt, L.size, 16, net.float(s.rot)));
    else if (s.font) m.push(net.message(`${D()}/ttf`, r, g, b, x, y, L.size, txt, s.font, net.float(s.rot)));
    else m.push(net.message(`${D()}/ttf`, r, g, b, x, y, L.size, txt, net.float(s.rot)));
  }
  return { m, L };
}
// draw the box text (the preview canvas, or the overlay with a caret)
function liveDraw(ctx, L, erase, caret) {
  ctx.save();
  ctx.translate(lbox.cx, lbox.cy);
  ctx.rotate(rad(s.rot));
  if (erase) { ctx.fillStyle = s.color2; ctx.fillRect(-lbox.w / 2, -lbox.h / 2, lbox.w, lbox.h); }
  ctx.font = L.font;
  ctx.textBaseline = "top";
  ctx.fillStyle = s.color;
  const x0 = -lbox.w / 2, y0 = -lbox.h / 2;
  L.lines.forEach((l, k) => ctx.fillText(l, x0, y0 + k * L.lh));
  if (caret) {
    ctx.strokeStyle = "#fff";
    ctx.setLineDash([]);
    ctx.lineWidth = 2;
    // the caret where the edit point is (the text before it, normalised as the board does)
    const n = normText(livein.value.slice(0, livein.selectionEnd), L.pix).length, st = L.lines.starts;
    let k = st.length - 1;
    while (k > 0 && st[k] > n) k--;
    const before = L.lines[k].slice(0, Math.max(0, n - st[k]));
    const cxp = x0 + (L.pix ? [...before].length * L.lh / 2 : ctx.measureText(before).width) + 2;
    ctx.beginPath(); ctx.moveTo(cxp, y0 + k * L.lh); ctx.lineTo(cxp, y0 + (k + 1) * L.lh); ctx.stroke();
  }
  ctx.restore();
}
function liveOverlay() {
  if (!lbox || s.tool !== "live") return;
  const L = liveLayout();
  ox.save();
  ox.translate(lbox.cx, lbox.cy);
  ox.rotate(rad(s.rot));
  ox.setLineDash([10, 6]);
  ox.lineWidth = 2;
  ox.strokeStyle = document.activeElement === livein ? "rgba(255,154,60,0.95)" : "rgba(255,255,255,0.6)";
  ox.strokeRect(-lbox.w / 2, -lbox.h / 2, lbox.w, lbox.h);
  ox.restore();
  ox.globalAlpha = s.llive ? 0.35 : 0.8;
  liveDraw(ox, L, false, document.activeElement === livein);
  ox.globalAlpha = 1;
  if (liveInfo) liveInfo.textContent = `${L.pix ? "pixel ×" + L.size : L.size + " px"}, ${L.lines.length} line${L.lines.length === 1 ? "" : "s"}` +
    (L.th > lbox.h ? " (does not fit)" : "");
}
function liveInside(p) {
  if (!lbox) return false;
  const a = -rad(s.rot), dx = p[0] - lbox.cx, dy = p[1] - lbox.cy;
  return Math.abs(dx * Math.cos(a) - dy * Math.sin(a)) <= lbox.w / 2 && Math.abs(dx * Math.sin(a) + dy * Math.cos(a)) <= lbox.h / 2;
}
function liveRedraw() { ox.clearRect(0, 0, W, H); liveOverlay(); }
function liveFocus() { if (lbox && livein) { livein.focus({ preventScroll: true }); liveRedraw(); } }
// every change in live mode: erase the box, draw the text (one bundle per frame)
function liveSendNow() {
  if (!lbox || !s.llive) return;
  net.throttled("livetext", () => net.bundle(...liveMsgs(true).m));
}
function liveCommit() {
  if (!lbox) return toast("drag a box on the canvas first (⌨ live tool)", true);
  const erase = s.llive || s.lerase, { m, L } = liveMsgs(erase);
  if (s.llive) net.send(net.bundle(...m));
  else { beginOp(); m.forEach(bsend); endOp(); }
  prevAllDraw(() => liveDraw(cx, L, erase, false));
  if (s.lafter === "next") { // the box moves one box height down its own axis
    const a = rad(s.rot);
    lbox.cx -= Math.sin(a) * lbox.h;
    lbox.cy += Math.cos(a) * lbox.h;
  }
  if (s.lafter !== "keep") { s.ltext = ""; livein.value = ""; save(); } // keep: the caret stays where it is
  liveRedraw();
}
function liveErase() {
  if (!lbox) return;
  const m = [net.message(`${D()}/fill`, "solid"), net.message(`${D()}/rect`, ...rgb2(), Math.round(lbox.cx - lbox.w / 2),
    Math.round(lbox.cy - lbox.h / 2), Math.round(lbox.w), Math.round(lbox.h), 0, net.float(s.rot))];
  if (s.llive) net.send(net.bundle(...m)); else { beginOp(); m.forEach(bsend); endOp(); }
  prevAllDraw(() => { cx.save(); cx.translate(lbox.cx, lbox.cy); cx.rotate(rad(s.rot)); cx.fillStyle = s.color2;
    cx.fillRect(-lbox.w / 2, -lbox.h / 2, lbox.w, lbox.h); cx.restore(); });
}
function prevAllDraw(fn) { cx.globalAlpha = 1; cx.globalCompositeOperation = "source-over"; fn(); }

// ---- sending strokes, batched per animation frame ----
function flush() {
  raf = false;
  if (!pending.length) return;
  const [r, g, b] = rgb();
  while (pending.length) {
    const pts = pending.splice(0, MAXPTS - (last ? 1 : 0));
    const all = (last ? [last] : []).concat(pts);
    bmsg(`${D()}/stroke`, r, g, b, s.size | 0, net.float(s.hard), ...all.flat());
    last = all[all.length - 1];
  }
}
function queue(p) {
  pending.push(p);
  if (!raf) {
    raf = true;
    requestAnimationFrame(flush);
  }
}

// paint bucket preview: like dz_shape_flood (largest channel difference <= tol;
// linear across the area's box at the fill angle, radial from the click point)
function previewFlood(x, y) {
  const im = cx.getImageData(0, 0, W, H), d = im.data, mask = new Uint8Array(W * H);
  const at = (i) => i * 4, k0 = at(y * W + x), sr = d[k0], sg = d[k0 + 1], sb = d[k0 + 2], tol = s.tol | 0;
  const near = (i) => { const k = at(i); return Math.abs(d[k] - sr) <= tol && Math.abs(d[k + 1] - sg) <= tol && Math.abs(d[k + 2] - sb) <= tol; };
  let x0 = x, x1 = x, y0 = y, y1 = y;
  const st = [[x, y]];
  while (st.length) {
    const [sx, sy] = st.pop(), row = sy * W;
    if (mask[row + sx] || !near(row + sx)) continue;
    let l = sx, r = sx;
    while (l > 0 && !mask[row + l - 1] && near(row + l - 1)) l--;
    while (r < W - 1 && !mask[row + r + 1] && near(row + r + 1)) r++;
    mask.fill(1, row + l, row + r + 1);
    x0 = Math.min(x0, l); x1 = Math.max(x1, r); y0 = Math.min(y0, sy); y1 = Math.max(y1, sy);
    for (const ny of [sy - 1, sy + 1]) {
      if (ny < 0 || ny >= H) continue;
      for (let k = l; k <= r; k++) {
        if (mask[ny * W + k] || !near(ny * W + k)) continue;
        st.push([k, ny]);
        while (k < r && !mask[ny * W + k + 1] && near(ny * W + k + 1)) k++;
      }
    }
  }
  const c1 = rgb(), c2 = rgb2(), a = s.alpha, gx = (x0 + x1 + 1) / 2, gy = (y0 + y1 + 1) / 2;
  const hx = (x1 - x0 + 1) / 2, hy = (y1 - y0 + 1) / 2, gc = Math.cos(rad(s.gangle)), gs = Math.sin(rad(s.gangle));
  const gn = Math.abs(gc) + Math.abs(gs);
  const rr = Math.hypot(Math.max(x - x0, x1 - x) + 1, Math.max(y - y0, y1 - y) + 1);
  for (let yy = y0; yy <= y1; yy++) for (let xx = x0; xx <= x1; xx++) {
    if (!mask[yy * W + xx]) continue;
    let t = 0;
    if (s.sfill === "radial") t = Math.min(1, Math.hypot(xx + 0.5 - x - 0.5, yy + 0.5 - y - 0.5) / rr);
    else if (s.sfill === "linear") t = Math.min(1, Math.max(0, (((xx + 0.5 - gx) / hx * gc + (yy + 0.5 - gy) / hy * gs) / gn + 1) / 2));
    const k = at(yy * W + xx);
    for (let c = 0; c < 3; c++) d[k + c] = Math.round(d[k + c] * (1 - a) + (c1[c] + (c2[c] - c1[c]) * t) * a);
  }
  cx.putImageData(im, 0, 0);
}
function pickAt(p) {
  const v = cx.getImageData(Math.min(W - 1, Math.max(0, p[0])), Math.min(H - 1, Math.max(0, p[1])), 1, 1).data;
  picker?.set("#" + [v[0], v[1], v[2]].map((c) => c.toString(16).padStart(2, "0")).join(""));
  toast(`colour ${s.color} (from the preview)`);
}
// brush outline under the pointer (the overlay; drag tools draw their band there)
function cursorAt(p) {
  ox.clearRect(0, 0, W, H);
  if (!p) return liveOverlay();
  ox.setLineDash([]);
  ox.lineWidth = 2;
  ox.strokeStyle = "rgba(255,255,255,0.9)";
  ox.beginPath();
  if (s.tool === "brush") {
    ox.arc(p[0], p[1], Math.max(1, s.size), 0, Math.PI * 2);
    ox.stroke();
    ox.strokeStyle = "rgba(0,0,0,0.8)";
    ox.beginPath();
    ox.arc(p[0], p[1], Math.max(1, s.size) + 2, 0, Math.PI * 2);
    ox.stroke();
    if (s.hard < 1) {
      ox.setLineDash([4, 4]);
      ox.strokeStyle = "rgba(255,255,255,0.5)";
      ox.beginPath();
      ox.arc(p[0], p[1], Math.max(1, s.size * s.hard), 0, Math.PI * 2);
      ox.stroke();
    }
  } else {
    ox.moveTo(p[0] - 12, p[1]); ox.lineTo(p[0] + 12, p[1]);
    ox.moveTo(p[0], p[1] - 12); ox.lineTo(p[0], p[1] + 12);
    ox.stroke();
  }
  liveOverlay();
}

function down(e) {
  try { cv.setPointerCapture(e.pointerId); } catch { /* synthetic event */ }
  const p = toBoard(e);
  const [r, g, b] = rgb();
  if (e.altKey || s.tool === "pick") return pickAt(p);
  if (s.tool === "live" && liveInside(p)) { e.preventDefault(); return liveFocus(); }
  beginOp();
  if (s.tool === "fill") {
    bsend(fillMsg());
    bmsg(`${D()}/flood`, r, g, b, p[0], p[1], s.tol | 0);
    previewFlood(p[0], p[1]);
  } else if (s.tool === "brush") {
    drawing = true;
    last = null;
    pending = [];
    queue(p);
    previewDot(...p);
  } else if (DRAG.includes(s.tool)) {
    drawing = true;
    start = end = p;
    rotating = null;
  } else if (s.tool === "text" || s.tool === "ttf") {
    // angle: the shared "angle" slider, clockwise about the centre of the text
    // (as the shapes); the click point stays the top-left of the unrotated text
    if (s.tool === "text")
      bmsg(`${D()}/text`, r, g, b, p[0], p[1], s.text, s.scale | 0, 16, net.float(s.angle));
    else if (s.font)       // a string after the text = the font file (dz_draw.c)
      bmsg(`${D()}/ttf`, r, g, b, p[0], p[1], s.ttf | 0, s.text, s.font, net.float(s.angle));
    else
      bmsg(`${D()}/ttf`, r, g, b, p[0], p[1], s.ttf | 0, s.text, net.float(s.angle));
    previewStyle();
    cx.fillStyle = s.color;
    cx.font = s.tool === "text" ? `${16 * s.scale}px monospace` : `${s.ttf}px sans-serif`;
    cx.textBaseline = "top";
    // the same rules as the board (lib/dz_text.c text_norm): line breaks, tabs, controls
    const lines = normText(s.text, s.tool === "text").split("\n"), lh = s.tool === "text" ? 16 * s.scale : s.ttf;
    const tw = Math.max(...lines.map((l) => cx.measureText(l).width)), th = lh * lines.length;
    cx.save();
    cx.translate(p[0] + tw / 2, p[1] + th / 2);
    cx.rotate(rad(s.angle));
    lines.forEach((l, k) => cx.fillText(l, -tw / 2, -th / 2 + k * lh));
    cx.restore();
  } else if (s.tool === "sprite") {
    bmsg(`/sprite/${sprites.selected()}/draw`, s.slot, p[0], p[1], net.float(s.sscale), net.float(s.angle), net.float(s.alpha));
    cx.strokeStyle = s.color;
    cx.globalAlpha = 1;
    cx.globalCompositeOperation = "source-over";
    cx.strokeRect(p[0] - 20, p[1] - 20, 40, 40);
  }
  if (!drawing) endOp();	// click tools: one action; strokes and drags end in up()
}
function move(e) {
  if (!(drawing && DRAG.includes(s.tool))) cursorAt(toBoard(e));
  if (drawing && start && DRAG.includes(s.tool)) {
    const p = toBoard(e), lock = e.ctrlKey || e.metaKey;
    if (e.shiftKey && (SHAPES.includes(s.tool) || s.tool === "live")) {	// Shift: rotate about the centre
      const g = geom(start, end, lock), a = (Math.atan2(p[1] - g.cy, p[0] - g.cx) * 180) / Math.PI;
      if (!rotating) rotating = { base: a, rot0: s.rot };
      const v = rotating.rot0 + a - rotating.base;
      setRot(lock ? Math.round(v / 15) * 15 : v);	// Ctrl+Shift: 15 degree steps
    } else {
      rotating = null;
      end = p;
    }
    return band(start, end, lock);
  }
  if (!drawing || s.tool !== "brush") return;
  for (const ev of e.getCoalescedEvents ? e.getCoalescedEvents() : [e]) {
    const p = toBoard(ev);
    const prev = pending.length ? pending[pending.length - 1] : last;
    if (prev && Math.abs(prev[0] - p[0]) + Math.abs(prev[1] - p[1]) < 2) continue;
    if (prev) previewSeg(prev, p);
    queue(p);
  }
}
function up(e) {
  if (!drawing) return;
  drawing = false;
  ox.clearRect(0, 0, W, H);
  if (s.tool === "line" && start) {
    const p = toBoard(e);
    const [r, g, b] = rgb();
    bmsg(`${D()}/line`, r, g, b, start[0], start[1], p[0], p[1], Math.max(1, (s.size * 2) | 0));
    previewStyle();
    cx.strokeStyle = s.color;
    cx.lineWidth = Math.max(1, s.size * 2);
    cx.lineCap = "round";
    cx.beginPath();
    cx.moveTo(...start);
    cx.lineTo(...p);
    cx.stroke();
    start = null;
  } else if (SHAPES.includes(s.tool) && start) {
    const g = geom(start, rotating ? end : toBoard(e), e.ctrlKey || e.metaKey);
    if (g.w > 1 && g.h > 1) {
      bsend(fillMsg());
      bsend(shapeMsg(s.tool, g));
      drawShape(cx, s.tool, g, true);
    }
    start = rotating = null;
  } else if (s.tool === "live" && start) {
    const g = geom(start, rotating ? end : toBoard(e), e.ctrlKey || e.metaKey);
    start = rotating = null;
    if (g.w > 8 && g.h > 8) { lbox = { cx: g.cx, cy: g.cy, w: g.w, h: g.h }; liveSendNow(); }
    endOp();
    // the pointer up gives the focus to the canvas: take it back after it
    return setTimeout(liveFocus, 0);
  } else if (s.tool === "gradient" && s.gtype === "radial" && start) {
    const p = toBoard(e), r = Math.round(Math.hypot(p[0] - start[0], p[1] - start[1]));
    if (r > 8) {
      bmsg(`${D()}/gradient/radial`, ...rgb(), ...rgb2(), start[0], start[1], r);
      previewRadial(start[0], start[1], r);
    }
    start = null;
  } else if (s.tool === "gradient" && start) {
    const p = toBoard(e);
    if (Math.hypot(p[0] - start[0], p[1] - start[1]) > 8) {
      const deg = dragAngle(start, p);
      bmsg(`${D()}/gradient/angle`, net.float(deg), ...rgb(), ...rgb2());
      previewGradient(deg, s.color, s.color2);
    }
    start = null;
  } else {
    flush();
  }
  endOp();
}

// the Live text card and the (invisible) input that takes the typing
function liveCard() {
  livein = h("textarea.livein", { spellcheck: false, autocomplete: "off", "aria-label": "live text",
    oninput: () => { s.ltext = livein.value; save(); liveRedraw(); liveSendNow(); },
    onfocus: liveRedraw, onblur: liveRedraw, onkeyup: liveRedraw, onselect: liveRedraw, onclick: liveRedraw,
    onkeydown: (e) => {
      if (e.key === "Enter" && (e.shiftKey || e.ctrlKey || e.metaKey)) { e.preventDefault(); liveCommit(); }
      else if (e.key === "Escape") { e.preventDefault(); livein.blur(); }
      else if (e.key === "Tab") {
        e.preventDefault();
        const a = livein.selectionStart;
        livein.setRangeText("\t", a, livein.selectionEnd, "end");
        s.ltext = livein.value; save(); liveRedraw(); liveSendNow();
      }
    } });
  livein.value = s.ltext;
  const sel = (key, opts, title, on) => h("select", { title, onchange: (e) => { s[key] = e.target.value; save(); on?.(); liveRedraw(); } },
    opts.map(([v, l]) => h("option", { value: v, selected: v === s[key] }, l)));
  const chk = (key, title, on) => h("input", { type: "checkbox", checked: s[key], title, onchange: (e) => { s[key] = e.target.checked; save(); on?.(); liveRedraw(); } });
  liveInfo = h("span.hint", {}, "no box");
  return card("Live text", livein,
    row("font", sel("lfont", [["ttf", "TrueType (font above)"], ["pixel", "pixel font"]],
      "TrueType: the font of the Text card, max size = ttf px; pixel: max size = pixel ×"), liveInfo),
    row("erase", chk("lerase", "fill the box with colour 2 before the text is drawn (always on in live mode)"),
      h("span.hint", {}, "box with colour 2 first")),
    row("live", chk("llive", "draw every change at once (erase + text, up to one per frame); " +
      "also in batch mode", () => { if (s.llive) liveSendNow(); }), h("span.hint", {}, "every key goes to the board")),
    row("after send", sel("lafter", [["keep", "keep the text and caret"], ["clear", "clear the text"], ["next", "clear, box one line down"]],
      "what Shift+Enter does after it draws: 'box one line down' moves the box by its height (along its rotation)")),
    row(null,
      h("button.primary", { title: "draw the box text (Shift+Enter or Ctrl+Enter while typing)", onclick: () => { liveCommit(); liveFocus(); } }, "Send ⇧⏎"),
      h("button", { title: "fill the box with colour 2", onclick: liveErase }, "Erase box"),
      h("button", { title: "remove the box (Esc)", onclick: () => { lbox = null; ox.clearRect(0, 0, W, H); if (liveInfo) liveInfo.textContent = "no box"; } }, "Drop box")),
    h("p.hint", {}, "⌨ tool [K]: drag a box (Shift while dragging: rotate, or the rotation slider), " +
      "then type - Backspace, Delete, arrows, Enter = new line. Shift+Enter draws it. Click in the box to type again. " +
      "The text wraps at the box width and gets smaller until it fits."));
}

// the sprite the ◰ tool draws (the selected number, shared with the Media
// tab's Sprites card): slider, preview, what it holds, and a file loader
function spriteRow() {
  const prev = h("div.spr-prev");
  const desc = h("div.hint.spr-desc", {}, "");
  const el = h("input", { type: "range", min: 0, max: sprites.N - 1, step: 1, value: sprites.selected(),
    title: "sprite #: the sprite the ◰ tool draws (/sprite/<id>/draw); the same number as the Media tab's Sprites card",
    oninput: () => sprites.select(el.value) });
  const out = h("span.hint", {}, "");
  const files = h("select", { title: "an image on the board (/media/debaz/img)", style: "max-width:160px" }, h("option", { value: "" }, "image…"));
  const fill = async () => {
    const names = await sprites.imageFiles();
    files.replaceChildren(h("option", { value: "" }, names.length ? "image…" : "no images"), ...names.map((n) => h("option", { value: n }, n)));
  };
  files.addEventListener("focus", fill, { once: true });
  const load = h("button", { title: "load the chosen image as this sprite\n/sprite/<id>/load \"<file>\"",
    onclick: () => { if (files.value) sprites.loadFile(sprites.selected(), files.value); else { fill(); toast("choose an image first", true); } } }, "Load");
  const show = () => {
    const id = sprites.selected();
    el.value = id;
    out.textContent = `#${id}`;
    prev.replaceChildren(sprites.thumb(id, 64));
    desc.textContent = sprites.describe(id).replace(/^sprite #\d+: /, "");
    s.sprite = id;
  };
  sprites.onChange(show);
  show();
  return h("div", {}, row("sprite #", el, out), h("div.row.spr-row", {}, prev, h("div", { style: "flex:1;min-width:0" }, desc, h("div.row", {}, files, load))));
}

function slider(key, min, max, step, label, onset) {
  const out = h("span.hint", {}, String(s[key]));
  const el = h("input", { type: "range", min, max, step, value: s[key], title: `${label}: a value of the draw message`,
    oninput: () => { s[key] = Number(el.value); out.textContent = el.value; save(); onset?.(); } });
  return row(label, el, out);
}

export function init(root) {
  cv = h("canvas", { width: W, height: H, onpointerdown: down, onpointermove: move,
    onpointerup: up, onpointercancel: up, onpointerleave: () => { if (!drawing) cursorAt(null); } });
  cx = cv.getContext("2d");
  cx.fillStyle = "#000";
  cx.fillRect(0, 0, W, H);
  ov = h("canvas.overlay", { width: W, height: H });
  ox = ov.getContext("2d");
  gv = h("canvas.overlay", { width: W, height: H });

  const slot = h("select", { title: "target slot: /draw/<slot>/..., /surface/<slot>/...", onchange: () => { s.slot = parseInt(slot.value); save(); refreshGuides(); } },
    [...Array(12).keys()].map((i) => h("option", { value: i, selected: i === s.slot }, `slot ${i}`)));
  // [tool, label, key, hover text]
  const TOOLS = [["brush", "🖌 brush", "B", "/draw/<slot>/stroke (soft round brush)"], ["line", "╱ line", "L", "/draw/<slot>/line"],
    ["rect", "▭ rect", "R", "/draw/<slot>/rect"], ["ellipse", "◯ ellipse", "E", "/draw/<slot>/ellipse"],
    ["shape", "★ shape", "P", "/draw/<slot>/polygon, /star, /starpoly"], ["gradient", "▤ gradient", "G", "/draw/<slot>/gradient/angle | radial (drag)"],
    ["fill", "🪣 fill", "F", "/draw/<slot>/flood: the area of similar colour around the click (solid, linear or radial: the shape fill)"],
    ["pick", "💧 pick", "I", "take a colour from the preview (Alt+click with any tool)"],
    ["text", "A text", "T", "/draw/<slot>/text (pixel font)"], ["ttf", "Aa ttf", "", "/draw/<slot>/ttf (TrueType, UTF-8)"],
    ["sprite", "◰ sprite", "", "/sprite/<id>/draw <slot> x y ..."],
    ["live", "⌨ live text", "K", "live text: drag a box (Shift: rotate), type, Shift+Enter draws it (/draw/<slot>/ttf or /text, fitted to the box)"]];
  const tools = TOOLS.map(([t, label, key, tip]) =>
    h("button", { title: tip + (key ? `  [${key}]` : ""), onclick: () => setTool(t) }, label));
  setTool = (t) => {
    s.tool = t; save(); tools.forEach((b, i) => b.classList.toggle("on", TOOLS[i][0] === t));
    if (ox) { ox.clearRect(0, 0, W, H); if (t === "live") liveFocus(); }
  };
  toolKeys = Object.fromEntries(TOOLS.filter((x) => x[2]).map((x) => [x[2].toLowerCase(), x[0]]));
  setTool(s.tool);
  const pick = (key, title) => {
    const el = h("input", { type: "color", value: s[key], title, oninput: () => { s[key] = el.value; save(); } });
    return el;
  };
  picker = colorPicker(s, (key) => {
    save();
    if (key === "alpha") { syncBrush(); if (!s.batch) net.throttled(`${D()}/alpha`, () => net.message(`${D()}/alpha`, net.float(s.alpha))); }
    drawBrushPreview();
  }, save);
  const fill = h("input", { type: "checkbox", checked: s.fill, title: "filled shapes (thickness 0) or outlines", onchange: () => { s.fill = fill.checked; save(); } });
  const num = (key, step, title, min, max) => {
    const el = h("input", { type: "number", step, min, max, value: s[key], title, style: "width:76px",
      onchange: () => { s[key] = Number(el.value); save(); } });
    return el;
  };
  const prevAll = (fn) => { cx.globalAlpha = 1; cx.globalCompositeOperation = "source-over"; fn(); };
  const blend = h("select", { title: "/draw/<slot>/blend normal|add|lighten|multiply", onchange: () => { s.blend = blend.value; save(); if (!s.batch) net.msg(`${D()}/blend`, s.blend); } },
    ["normal", "add", "lighten", "multiply"].map((b) => h("option", { value: b, selected: b === s.blend }, b)));
  // a text area (2026-11-19): Enter = a new line; \n \t \\ typed also work
  const text = h("textarea", { rows: 2, spellcheck: false, style: "width:100%;min-width:16em;resize:vertical;font-family:monospace",
    title: "the text of /draw/<slot>/text and /ttf (UTF-8 for ttf)\n" +
      "Enter or \\n = a new line, Tab or \\t = to the next 4-column stop, \\\\ = a backslash;\n" +
      "other control and invisible characters are not drawn; the pixel font draws ? for a non-ASCII character",
    oninput: () => { s.text = text.value; save(); },
    onkeydown: (e) => {     // Tab inserts a tab here instead of leaving the box
      if (e.key !== "Tab") return;
      e.preventDefault();
      const a = text.selectionStart, b = text.selectionEnd;
      text.value = text.value.slice(0, a) + "\t" + text.value.slice(b);
      text.selectionStart = text.selectionEnd = a + 1;
      s.text = text.value; save();
    } });
  text.value = s.text;
  // TrueType font of the Aa ttf tool (the board's fonts: /files fonts); the
  // preview here stays sans-serif
  const fontSel = h("select", { style: "max-width:14em",
    title: "font of the Aa ttf tool (/usr/share/fonts on the board; default LiberationSans).\n" +
      "A character the font lacks comes from DejaVuSans, FreeSerif or DroidSansFallbackFull.\n" +
      "/draw/<slot>/ttf r g b x y size \"text\" \"<font>\" angle",
    onchange: () => { s.font = fontSel.value; save(); } },
    h("option", { value: "" }, "default font"));
  const listFonts = async () => {
    try {
      const list = await net.collect(net.message("/files", "fonts"), "/file", "/file/end");
      fontSel.replaceChildren(h("option", { value: "" }, "default font"),
        ...list.map((a) => a[0]).sort().map((n) => h("option", { value: n }, n.replace(/\.(ttf|otf|ttc)$/i, ""))));
      fontSel.value = s.font || "";
    } catch { /* the default font still works */ }
  };
  listFonts();
  const fade = h("input", { type: "number", min: 0, max: 1, step: 0.05, value: 0.2, title: "/draw/<slot>/fade <amount 0..1>" });
  // hover text = the OSC message the button sends (<slot> = the target slot above)
  const ACT_TIP = { "Clear": "/draw/<slot>/clear r g b", "Clear black": "/draw/<slot>/clear 0 0 0",
    "Fade": "/draw/<slot>/fade <amount 0..1>", "Solid": "/draw/<slot>/solid r g b",
    "Test bars": "/draw/<slot>/bars", "Radial": "/draw/<slot>/gradient/radial r1 g1 b1 r2 g2 b2",
    "Angle": "/draw/<slot>/gradient/angle <deg> r1 g1 b1 r2 g2 b2",
    "Corners": "/draw/<slot>/gradient/corners tl(3) tr(3) bl(3) br(3)",
    "Save": "/surface/<slot>/save \"<name>.png|.jpg\" (in /media/debaz/img; PNG = lossless drafts, JPG = smaller, loads faster in a cue)", "Load": "/img/<slot>/load \"<name>\"",
    "Grab live input": "/surface/<slot>/grab 4 (the capture into the paint buffer)",
    "Show on display 0": "/disp/0/show <slot>", "Show on display 1": "/disp/1/show <slot>",
    "Quad": "/draw/<slot>/mirror quad", "↻": "dzweb HTTP GET /media" };
  // a button = one action (batch mode: undone as a whole)
  const act = (label, fn, title = ACT_TIP[label]) => h("button", { onclick: () => { beginOp(); fn(); endOp(); }, title }, label);

  // save / recall: the slot as <name>.png (default: lossless, for drafts you
  // load back to undo or try things) or <name>.jpg (quality 92: smaller and
  // about 3x faster to load, for the image a cue loads) in /media/debaz/img.
  // debazd encodes it itself (2026-11-19): PNG ~0.5 s for paint, several s
  // for photo-like content; JPG ~0.13 s. Back with /img/<slot>/load.
  const pad = (n) => String(n).padStart(2, "0");
  const stamp = () => { const d = new Date();
    return `paint-${d.getFullYear()}${pad(d.getMonth() + 1)}${pad(d.getDate())}-` +
      `${pad(d.getHours())}${pad(d.getMinutes())}${pad(d.getSeconds())}`; };
  const clean = (n) => n.replace(/\.(png|jpe?g)$/i, "").replace(/[^A-Za-z0-9._-]+/g, "_").replace(/^[._]+/, "").slice(0, 92);
  const saveName = h("input", { type: "text", value: stamp(), style: "width:210px",
    title: "file name: A-Z a-z 0-9 . _ - (.png or .jpg is added)" });
  const saveFmt = h("select", { title: "PNG = lossless (drafts: load it back to undo or try things)\n" +
      "JPG = quality 92, smaller, loads about 3x faster (the image a cue loads)",
    onchange: () => { s.saveFmt = saveFmt.value; save(); } },
    h("option", { value: "png", selected: s.saveFmt !== "jpg" }, "PNG"),
    h("option", { value: "jpg", selected: s.saveFmt === "jpg" }, "JPG"));
  const imgSel = h("select", { title: "images on the board (/media/debaz/img), newest first", style: "max-width:260px" });
  const listImages = async (pick) => {
    try {
      const r = await fetch(`${net.httpBase()}/media`, { cache: "no-store" });
      const files = (await r.json()).img.sort((a, b) => b.mtime - a.mtime);
      imgSel.replaceChildren(...(files.length ? files.map((f) =>
        h("option", { value: f.name, selected: f.name === pick }, f.name)) : [h("option", { value: "" }, "no images")]));
    } catch {
      imgSel.replaceChildren(h("option", { value: "" }, "list not available"));
    }
  };
  const saveImage = () => {
    const n = clean(saveName.value) || stamp(), f = `${n}.${saveFmt.value}`;
    net.msg(`/surface/${s.slot}/save`, f);
    toast(`saving slot ${s.slot} as ${f}`);
    // the encode: JPG ~0.1 s, PNG 0.5 s (paint) to several s (photo-like)
    setTimeout(() => listImages(f), 1200);
    setTimeout(() => listImages(f), 5000);
    saveName.value = stamp();
  };
  const loadImage = () => {
    const n = imgSel.value;
    if (!n) return;
    net.msg(`/img/${s.slot}/load`, n);
    const im = new Image(); // preview; PPM does not decode in a browser (board only)
    im.crossOrigin = "anonymous";
    im.onload = () => prevAll(() => cx.drawImage(im, 0, 0, W, H));
    im.src = `${net.httpBase()}/media/img/${encodeURIComponent(n)}`;
  };
  listImages();

  // live / batch bar
  const modeLive = h("button", { title: "every stroke goes to the board at once", onclick: () => setMode(false) }, "Live");
  const modeBatch = h("button", { title: "draw here first: Undo / Redo, then Send it all to the board", onclick: () => setMode(true) }, "Batch");
  const bUndo = h("button", { title: "undo the last action (Ctrl+Z)", onclick: undo }, "↶ Undo");
  const bRedo = h("button", { title: "redo (Ctrl+Shift+Z, Ctrl+Y)", onclick: redoOp }, "↷ Redo");
  const bSend = h("button.primary", { title: "send the waiting actions to the board, in order (Enter)", onclick: sendBatch }, "Send");
  const bDrop = h("button", { title: "throw the waiting actions away (the preview goes back)", onclick: discard }, "Discard");
  batchEl = h("span.hint", {}, "");
  const setMode = (b) => {
    if (!b && ops.length) {
      if (confirm(`Send the ${ops.length} waiting action(s) to the board? (Cancel = throw them away)`)) sendBatch();
      else discard();
    }
    s.batch = b;
    save();
    modeLive.classList.toggle("on", !b);
    modeBatch.classList.toggle("on", b);
    for (const x of [bUndo, bRedo, bSend, bDrop]) x.disabled = !b;
    if (!b) { net.msg(`${D()}/alpha`, net.float(s.alpha)); net.msg(`${D()}/blend`, s.blend); }
    batchInfo();
  };
  setMode(!!s.batch);

  guideBox = h("input", { type: "checkbox", checked: s.guides !== false, title: "show the output sizes and the display windows (this browser only)",
    onchange: () => { s.guides = guideBox.checked; save(); drawGuides(); } });
  canvasSel = h("select", { title: "/surface/<slot>/canvas full|mode\nfull = the whole slot in every mode (8.3 MB of board RAM per slot in use);\n" +
    "mode = only the output size (old behaviour, faster full-frame ops, starts again after a mode change).\nA change starts the slot's paint buffer again (black).",
    onchange: () => { net.msg(`/surface/${s.slot}/canvas`, canvasSel.value); setTimeout(refreshGuides, 200); } },
    h("option", { value: "full" }, "full slot"), h("option", { value: "mode" }, "output size"));
  canvasInfo = h("span.hint", { title: "/surface/<slot>/canvas -> full|mode w h kB-in-use kB-free\n" +
    "/surface/<slot>/free gives the RAM back (the slot keeps its picture)" }, "");
  const left = h("div.paint-left", {},
      h("div.row", {}, h("label", {}, "draw into"), slot,
        act("Show on display 0", () => { net.msg("/disp/0/show", s.slot); setTimeout(refreshGuides, 200); }),
        act("Show on display 1", () => { net.msg("/disp/1/show", s.slot); setTimeout(refreshGuides, 200); })),
      h("div.row.modebar", {}, h("div.seg", {}, modeLive, modeBatch), bUndo, bRedo, bSend, bDrop, batchEl),
      h("div.canvas-wrap", {}, cv, gv, ov),
      h("div.row", {}, h("label", {}, "guides"), guideBox, h("span.hint", {}, "output sizes"),
        h("label", {}, "canvas"), canvasSel, canvasInfo),
      h("p.hint", {}, "The canvas is the whole 1920×1080 slot. A display shows a window of the output size: " +
        "dashed = the output sizes from the top left, orange / green = the window of display 0 / 1 when it shows this slot " +
        "(move it in the Wall tab). Preview of your own drawing only. Board-side effects (grab, transforms, LFOs, Load) show on " +
        "the display and go to the board at once, also in batch mode."));

  // Brush card: big labelled controls with a value field each, a live sample, presets
  const bp = h("canvas.brush-prev", { width: 300, height: 96 });
  brushPrev = bp.getContext("2d");
  const big = (key, min, max, step, label, unit, mul, tip, onset) => {
    const el = h("input.big-range", { type: "range", min, max, step, value: s[key], title: tip });
    const out = h("input.cp-num", { type: "number", min: min * mul, max: max * mul, step: step * mul,
      value: Math.round(s[key] * mul), title: tip });
    const set = (v, quiet) => {
      v = Math.min(max, Math.max(min, v));
      s[key] = v;
      el.value = v;
      if (document.activeElement !== out) out.value = Math.round(v * mul);
      if (quiet) return;
      save();
      drawBrushPreview();
      onset?.();
    };
    el.oninput = () => set(+el.value);
    out.onchange = () => set(+out.value / mul);
    brushSet[key] = set;
    return h("div.big-row", {}, h("label", {}, label), el, out, h("span.hint", {}, unit));
  };
  const PRESETS = [["pencil", 2, 1, 1], ["pen", 5, 0.9, 1], ["marker", 14, 0.75, 0.85], ["soft", 40, 0, 0.6], ["airbrush", 80, 0, 0.12]];
  const brushCard = card("Brush",
    bp,
    h("div.tools", {}, PRESETS.map(([n, sz, hd, al]) => h("button", { title: `size ${sz}, hardness ${hd * 100} %, slot alpha ${al * 100} %`,
      onclick: () => { brushSet.size(sz); brushSet.hard(hd); brushSet.alpha(al); picker.refresh(); } }, n))),
    big("size", 1, 200, 1, "size", "px", 1, "brush radius in px; the line tool is 2 × size wide, outlines are size wide  [ / ]"),
    big("hard", 0, 1, 0.01, "hardness", "%", 100, "0 % = soft edge, 100 % = hard edge"),
    big("alpha", 0, 1, 0.01, "slot alpha", "%", 100, "/draw/<slot>/alpha: one alpha for the whole slot - brush, shapes, text, ASCII, sprites; below 100 % ASCII into the slot is slow (full-frame blend)",
      () => { picker.refresh(); if (!s.batch) net.throttled(`${D()}/alpha`, () => net.message(`${D()}/alpha`, net.float(s.alpha))); }),
    big("tol", 0, 255, 1, "tolerance", "", 1, "paint bucket: colours that differ by up to this much (0-255 per channel) are filled"),
    h("p.hint", {}, "The dashed ring under the pointer shows the hard core; the outer ring the full size."));
  root.append(h("div.paint", {}, left,
    h("div", {},
      card("Tool", h("div.tools", {}, tools),
        row("blend", blend, h("span.hint", {}, "how strokes mix with the slot"))),
      card("Colour", picker.el),
      brushCard,
      card("Shape and fill",
        row("filled", fill, h("span.hint", {}, "off = outline, 'size' px wide")),
        row("fill",
          h("select", { title: "fill of rect, ellipse and shape", onchange: (e) => { s.sfill = e.target.value; save(); } },
            ["solid", "linear", "radial"].map((v) => h("option", { value: v, selected: v === s.sfill }, v))),
          h("span.hint", {}, "angle"), num("gangle", 1, "linear gradient angle (degrees, in the shape)", -360, 360),
          h("span.hint", {}, "colour 1 → 2")),
        (() => { // rotation, also set by Shift+drag
          rotOut = h("span.hint", {}, String(s.rot));
          rotEl = h("input", { type: "range", min: -180, max: 180, step: 1, value: s.rot,
            title: "shape rotation in degrees (also Shift+drag): the last argument of\n" +
              "/draw/<s>/rect|ellipse|polygon|star ... <thickness> <angle>",
            oninput: () => setRot(Number(rotEl.value)) });
          return row("rotation", rotEl, rotOut);
        })(),
        row("shape",
          h("select", { title: "/draw/<slot>/polygon | /star | /starpoly", onchange: (e) => { s.pstyle = e.target.value; save(); } },
            [["polygon", "polygon"], ["star", "star"], ["starpoly", "star polygon {n/k}"]].map(([v, t]) =>
              h("option", { value: v, selected: v === s.pstyle }, t))),
          h("span.hint", {}, "n"), num("sides", 1, "sides / points (n)", 3, 64),
          h("span.hint", {}, "k"), num("skip", 1, "star polygon: join every k-th point (5/2 = pentagram, 6/2 = star of David)", 2, 31),
          h("span.hint", {}, "inner"), num("inner", 0.05, "star: inner radius ratio (0 = classic)", 0, 1)),
        h("p.hint", {}, "Drag a box. Ctrl: square/circle/regular. Shift while dragging: rotate " +
          "(Ctrl+Shift: 15° steps). Shape: n sides; star: n points, inner ratio; star polygon: n and k. " +
          "The fill (solid, linear, radial) is also the paint bucket's.")),
      card("Text and sprite",
        row("text", text, fontSel),
        slider("scale", 1, 8, 1, "pixel ×"),
        slider("ttf", 8, 300, 1, "ttf px"),
        spriteRow(),
        slider("sscale", 0.05, 4, 0.05, "sprite ×"),
        slider("angle", -180, 180, 1, "angle")),
      liveCard())));
  // board-side operations under the canvas, where there is room
  left.append(h("div.grid.paint-ops", {},
      card("Surface",
        row(null,
          act("Clear", () => { const [r, g, b] = rgb(); bmsg(`${D()}/clear`, r, g, b);
            cx.globalAlpha = 1; cx.globalCompositeOperation = "source-over"; cx.fillStyle = s.color; cx.fillRect(0, 0, W, H); }),
          act("Clear black", () => { bmsg(`${D()}/clear`, 0, 0, 0);
            cx.globalAlpha = 1; cx.globalCompositeOperation = "source-over"; cx.fillStyle = "#000"; cx.fillRect(0, 0, W, H); })),
        row("fade", fade, act("Fade", () => { bmsg(`${D()}/fade`, net.float(Number(fade.value)));
          cx.globalAlpha = Number(fade.value); cx.globalCompositeOperation = "source-over"; cx.fillStyle = "#000"; cx.fillRect(0, 0, W, H); })),
        row(null, act("Grab live input", () => net.msg(`/surface/${s.slot}/grab`, 4)),
          act("Free RAM", () => { net.msg(`/surface/${s.slot}/free`); setTimeout(refreshGuides, 200); }, `/surface/<slot>/free: give the paint buffer's board RAM back (8.3 MB for a full slot); the slot keeps its picture, the next draw starts from black`)),
        h("p.hint", {}, "Grab copies the live HDMI input into this slot: then paint on the frozen frame.")),
      anim.saveCard(() => s.slot),
      card("Image",
        row("save as", saveName, saveFmt, act("Save", saveImage)),
        row("recall", imgSel, act("Load", loadImage), act("↻", () => listImages(imgSel.value))),
        h("p.hint", {}, "Save writes this slot's paint buffer (what you drew, also a grab) as a PNG on the board; " +
          "Load draws a saved image back into the slot at its own size, at the top left (a larger one is made smaller). Images also show in Media.")),
      card("Fill",
        row(null,
          act("Solid", () => { bmsg(`${D()}/solid`, ...rgb());
            prevAll(() => { previewStyle(); cx.fillStyle = s.color; cx.fillRect(0, 0, W, H); }); }),
          act("Test bars", () => {
            bmsg(`${D()}/bars`);
            prevAll(() => ["#fff", "#ff0", "#0ff", "#0f0", "#f0f", "#f00", "#00f", "#000"].forEach((c, i) => {
              cx.fillStyle = c; cx.fillRect((i * W) / 8, 0, W / 8 + 1, H); }));
          })),
        row("tool",
          h("select", { title: "gradient tool: drag direction (linear) or centre and radius (radial)",
            onchange: (e) => { s.gtype = e.target.value; save(); } },
            ["linear", "radial"].map((v) => h("option", { value: v, selected: v === s.gtype }, `gradient tool: ${v}`)))),
        row("gradient",
          act("Radial", () => { bmsg(`${D()}/gradient/radial`, ...rgb(), ...rgb2());
            previewRadial(W / 2, H / 2, Math.hypot(W, H) / 2); }),
          act("H", () => { bmsg(`${D()}/gradient/h`, ...rgb(), ...rgb2()); previewGradient(0, s.color, s.color2); }), "/draw/<slot>/gradient/h r1 g1 b1 r2 g2 b2",
          act("V", () => { bmsg(`${D()}/gradient/v`, ...rgb(), ...rgb2()); previewGradient(90, s.color, s.color2); }), "/draw/<slot>/gradient/v r1 g1 b1 r2 g2 b2",
          num("gangle", 1, "angle in degrees (0 = left to right, 90 = top to bottom)", -360, 360),
          act("Angle", () => { bmsg(`${D()}/gradient/angle`, net.float(s.gangle), ...rgb(), ...rgb2());
            previewGradient(s.gangle, s.color, s.color2); })),
        row("corners", pick("tl", "top left"), pick("tr", "top right"), pick("bl", "bottom left"), pick("br", "bottom right"),
          act("Corners", () => {
            bmsg(`${D()}/gradient/corners`, ...hexToRgb(s.tl), ...hexToRgb(s.tr), ...hexToRgb(s.bl), ...hexToRgb(s.br));
            prevAll(() => { // two vertical gradients blended across
              for (let x = 0; x < W; x += 8) {
                const t = x / W, mix = (a, b) => hexToRgb(a).map((v, k) => Math.round(v + (hexToRgb(b)[k] - v) * t));
                const g = cx.createLinearGradient(0, 0, 0, H);
                g.addColorStop(0, `rgb(${mix(s.tl, s.tr)})`);
                g.addColorStop(1, `rgb(${mix(s.bl, s.br)})`);
                cx.fillStyle = g; cx.fillRect(x, 0, 8, H);
              }
            });
          })),
        h("p.hint", {}, "Colour 1 → colour 2. The gradient tool: drag on the canvas, the drag direction sets the angle.")),
      card("Transforms",
        row("rotozoom", num("rz", 0.5, "angle per step (deg)", -180, 180), num("zoom", 0.01, "zoom per step", 0.1, 4),
          act("Step", () => net.msg(`${D()}/rotozoom`, net.float(s.rz), net.float(s.zoom)), "/draw/<slot>/rotozoom <deg> <zoom>")),
        row("scroll", num("dx", 1, "dx px", -1920, 1920), num("dy", 1, "dy px", -1080, 1080),
          act("Step", () => net.msg(`${D()}/scroll`, s.dx | 0, s.dy | 0), "/draw/<slot>/scroll <dx> <dy>")),
        row("mirror", act("H", () => net.msg(`${D()}/mirror`, "h"), "/draw/<slot>/mirror h"), act("V", () => net.msg(`${D()}/mirror`, "v"), "/draw/<slot>/mirror v"),
          act("Quad", () => net.msg(`${D()}/mirror`, "quad"))),
        row("wave",
          h("select", { title: "axis", onchange: (e) => { s.waxis = Number(e.target.value); save(); } },
            h("option", { value: 0, selected: s.waxis === 0 }, "rows"),
            h("option", { value: 1, selected: s.waxis === 1 }, "columns")),
          num("wamp", 1, "amplitude px", 0, 200), num("wper", 1, "period px", 4, 2000),
          act("Step", () => net.msg(`${D()}/wave`, s.waxis | 0, net.float(s.wamp), net.float(s.wper), net.float(Math.random())), "/draw/<slot>/wave <axis> <amp> <period> <phase>")),
        h("p.hint", {}, "Each Step runs once on the board. For motion, give an LFO a target, e.g. " +
          "/draw/6/rotozoom $f0 1.02 (every 2 frames)."))));
  drawBrushPreview();
  watchGuides();

  // keys (not while typing in a field)
  document.addEventListener("keydown", (e) => {
    if (!cv.closest(".tab")?.classList.contains("active")) return;
    if (["INPUT", "TEXTAREA", "SELECT"].includes(document.activeElement?.tagName)) return;
    const k = e.key.toLowerCase(), mod = e.ctrlKey || e.metaKey;
    if (mod && k === "z") { e.preventDefault(); e.shiftKey ? redoOp() : undo(); return; }
    if (mod && k === "y") { e.preventDefault(); redoOp(); return; }
    if (mod || e.altKey) return;
    if (k === "enter" && s.batch) { e.preventDefault(); sendBatch(); }
    else if (k === "[" || k === "]") brushSet.size(k === "]" ? Math.max(s.size + 1, Math.round(s.size * 1.25)) : Math.min(s.size - 1, Math.round(s.size * 0.8)));
    else if (k === "x") picker.swap();
    else if (k === "escape" && drawing && DRAG.includes(s.tool)) { drawing = false; start = null; ox.clearRect(0, 0, W, H); endOp(); liveOverlay(); }
    else if (k === "escape" && lbox && s.tool === "live") { lbox = null; ox.clearRect(0, 0, W, H); }
    else if (toolKeys[k]) setTool(toolKeys[k]);
  });
}

// ---- guides: output sizes and the display windows (2026-11-04) ----
let guideBox, canvasSel, canvasInfo;
const view = { disp: [-1, -1], crop: [[0, 0], [0, 0]], mw: 1280, mh: 720 };

function drawGuides() {
  if (!gv) return;
  const g = gv.getContext("2d");
  g.clearRect(0, 0, W, H);
  if (s.guides === false) return;
  g.font = "22px system-ui";
  g.lineWidth = 2;
  g.setLineDash([12, 10]);
  for (const [w, hh] of SIZES) {
    const cur = w === view.mw && hh === view.mh;
    g.strokeStyle = cur ? "rgba(255,255,255,0.75)" : "rgba(255,255,255,0.35)";
    g.strokeRect(1, 1, w - 2, hh - 2);
    g.fillStyle = g.strokeStyle;
    g.fillText(`${w}×${hh}${cur ? " (output)" : ""}`, w - 200, hh - 10);
  }
  g.setLineDash([]);
  g.lineWidth = 4;
  ["#ff9a3c", "#4cc38a"].forEach((col, d) => {
    if (view.disp[d] !== s.slot) return;
    const [x, y] = view.crop[d];
    g.strokeStyle = col;
    g.strokeRect(x + 2, y + 2, view.mw - 4, view.mh - 4);
    g.fillStyle = col;
    g.fillText(`display ${d}`, x + 12, y + 30);
  });
}

async function refreshGuides() {
  if (!net.connected()) return drawGuides();
  const v = await net.ask(net.message("/video/mode"), (m) => m.path === "/video/mode" && m.args.length >= 2);
  if (v) [view.mw, view.mh] = v.args;
  for (const d of [0, 1]) {
    const r = await net.ask(net.message(`/disp/${d}`), (m) => m.path === `/disp/${d}`);
    view.disp[d] = r ? r.args[0] : -1;
    const c = await net.ask(net.message(`/disp/${d}/crop`), (m) => m.path === `/disp/${d}/crop`);
    if (c) view.crop[d] = [c.args[0], c.args[1]];
  }
  const c = await net.ask(net.message(`/surface/${s.slot}/canvas`), (m) => m.path === `/surface/${s.slot}/canvas`);
  if (c && canvasSel) {
    const [mode, w, hh, kb, free] = c.args;
    canvasSel.value = mode;
    canvasInfo.textContent = `${w}×${hh}, ${kb ? (kb / 1024).toFixed(1) + " MB in use" : "no RAM in use"}, ${(free / 1024).toFixed(0)} MB free`;
  }
  drawGuides();
}

export function show() {
  refreshGuides();
}

export function connected() {
  refreshGuides();
}

// the display windows follow the board (Wall tab, LFOs, cues): poll once a
// second while this tab is open
function watchGuides() {
  net.on("/disp/", (m) => {
    const r = /^\/disp\/([01])(\/crop)?$/.exec(m.path);
    if (!r || !m.args.length) return;
    const d = +r[1], old = JSON.stringify([view.disp[d], view.crop[d]]);
    if (r[2] && m.args.length >= 2) view.crop[d] = [m.args[0], m.args[1]];
    else if (!r[2] && typeof m.args[0] === "number") view.disp[d] = m.args[0];
    if (JSON.stringify([view.disp[d], view.crop[d]]) !== old) drawGuides();
  });
  net.on("/event/mode", () => refreshGuides());
  setInterval(() => {
    if (document.hidden || !cv.closest(".tab")?.classList.contains("active") || !net.connected()) return;
    net.send(net.bundle(net.message("/disp/0"), net.message("/disp/0/crop"),
      net.message("/disp/1"), net.message("/disp/1/crop")));
  }, 1000);
}
