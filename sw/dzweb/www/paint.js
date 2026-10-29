// paint.js - draw into a slot with mouse, pen or touch. The canvas uses board
// coordinates (1280x720) and shows a local preview of what you draw; effects
// that run on the board (grab, transforms) show on the display only.
import * as net from "./net.js";
import { h, card, row, hexToRgb, store, toast } from "./ui.js";

const W = 1280, H = 720;
const MAXPTS = 13; // stroke: 5 fixed args + 13 points = 31 args (< 32)
const DEF = { slot: 6, tool: "brush", color: "#ff9a3c", color2: "#2040ff", fill: true, size: 24, hard: 0.4,
  alpha: 1, blend: "normal", text: "DEBAZAROS", ttf: 64, scale: 2, sprite: 0, sscale: 1, angle: 0,
  gangle: 45, tl: "#ff0000", tr: "#00ff00", bl: "#0000ff", br: "#ffffff",
  rz: 3, zoom: 1.04, dx: 8, dy: 0, waxis: 0, wamp: 12, wper: 90,
  rot: 0, sfill: "solid", sides: 5, pstyle: "star", inner: 0, skip: 2, gtype: "linear" };
const s = { ...DEF, ...store.get("paint", {}) };
const SHAPES = ["rect", "ellipse", "shape"]; // rotatable, gradient-filled (dz_shape.c)
const DRAG = ["line", "gradient", ...SHAPES]; // tools that use press-drag-release
let cv, cx, ov, ox, drawing = false, start = null, pending = [], last = null, raf = false;
let end = null, rotating = null, rotOut = null, rotEl = null; // drag state, rotation slider

const save = () => store.set("paint", s);
const rgb = () => hexToRgb(s.color);
const rgb2 = () => hexToRgb(s.color2);
const thick = () => (s.fill ? 0 : Math.max(1, s.size | 0)); // 0 = filled
const rad = (d) => (d * Math.PI) / 180;
const gcd = (a, b) => (b ? gcd(b, a % b) : a);
const D = () => `/draw/${s.slot}`;

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
}
// rubber band on the overlay while a drag tool is down
function band(a, b, lock) {
  ox.clearRect(0, 0, W, H);
  ox.strokeStyle = "#fff";
  ox.setLineDash([12, 8]);
  ox.lineWidth = 3;
  if (SHAPES.includes(s.tool)) return drawShape(ox, s.tool, geom(a, b, lock), false);
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

// ---- sending strokes, batched per animation frame ----
function flush() {
  raf = false;
  if (!pending.length) return;
  const [r, g, b] = rgb();
  while (pending.length) {
    const pts = pending.splice(0, MAXPTS - (last ? 1 : 0));
    const all = (last ? [last] : []).concat(pts);
    net.msg(`${D()}/stroke`, r, g, b, s.size | 0, net.float(s.hard), ...all.flat());
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

function down(e) {
  try { cv.setPointerCapture(e.pointerId); } catch { /* synthetic event */ }
  const p = toBoard(e);
  const [r, g, b] = rgb();
  if (s.tool === "brush") {
    drawing = true;
    last = null;
    pending = [];
    queue(p);
    previewDot(...p);
  } else if (DRAG.includes(s.tool)) {
    drawing = true;
    start = end = p;
    rotating = null;
  } else if (s.tool === "text") {
    net.msg(`${D()}/text`, r, g, b, p[0], p[1], s.text, s.scale | 0, 16);
    previewStyle();
    cx.fillStyle = s.color;
    cx.font = `${16 * s.scale}px monospace`;
    cx.textBaseline = "top";
    cx.fillText(s.text, p[0], p[1]);
  } else if (s.tool === "ttf") {
    net.msg(`${D()}/ttf`, r, g, b, p[0], p[1], s.ttf | 0, s.text);
    previewStyle();
    cx.fillStyle = s.color;
    cx.font = `${s.ttf}px sans-serif`;
    cx.textBaseline = "top";
    cx.fillText(s.text, p[0], p[1]);
  } else if (s.tool === "sprite") {
    net.msg(`/sprite/${s.sprite}/draw`, s.slot, p[0], p[1], net.float(s.sscale), net.float(s.angle), net.float(s.alpha));
    cx.strokeStyle = s.color;
    cx.globalAlpha = 1;
    cx.globalCompositeOperation = "source-over";
    cx.strokeRect(p[0] - 20, p[1] - 20, 40, 40);
  }
}
function move(e) {
  if (drawing && start && DRAG.includes(s.tool)) {
    const p = toBoard(e), lock = e.ctrlKey || e.metaKey;
    if (e.shiftKey && SHAPES.includes(s.tool)) {	// Shift: rotate about the centre
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
    net.msg(`${D()}/line`, r, g, b, start[0], start[1], p[0], p[1], Math.max(1, (s.size * 2) | 0));
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
      net.send(net.bundle(fillMsg(), shapeMsg(s.tool, g)));
      drawShape(cx, s.tool, g, true);
    }
    start = rotating = null;
  } else if (s.tool === "gradient" && s.gtype === "radial" && start) {
    const p = toBoard(e), r = Math.round(Math.hypot(p[0] - start[0], p[1] - start[1]));
    if (r > 8) {
      net.msg(`${D()}/gradient/radial`, ...rgb(), ...rgb2(), start[0], start[1], r);
      previewRadial(start[0], start[1], r);
    }
    start = null;
  } else if (s.tool === "gradient" && start) {
    const p = toBoard(e);
    if (Math.hypot(p[0] - start[0], p[1] - start[1]) > 8) {
      const deg = dragAngle(start, p);
      net.msg(`${D()}/gradient/angle`, net.float(deg), ...rgb(), ...rgb2());
      previewGradient(deg, s.color, s.color2);
    }
    start = null;
  } else {
    flush();
  }
}

function slider(key, min, max, step, label, onset) {
  const out = h("span.hint", {}, String(s[key]));
  const el = h("input", { type: "range", min, max, step, value: s[key],
    oninput: () => { s[key] = Number(el.value); out.textContent = el.value; save(); onset?.(); } });
  return row(label, el, out);
}

export function init(root) {
  cv = h("canvas", { width: W, height: H, onpointerdown: down, onpointermove: move,
    onpointerup: up, onpointercancel: up });
  cx = cv.getContext("2d");
  cx.fillStyle = "#000";
  cx.fillRect(0, 0, W, H);
  ov = h("canvas.overlay", { width: W, height: H });
  ox = ov.getContext("2d");

  const slot = h("select", { onchange: () => { s.slot = parseInt(slot.value); save(); } },
    [...Array(12).keys()].map((i) => h("option", { value: i, selected: i === s.slot }, `slot ${i}`)));
  const tools = ["brush", "line", "rect", "ellipse", "shape", "gradient", "text", "ttf", "sprite"].map((t) =>
    h("button", { onclick: () => { s.tool = t; save(); tools.forEach((b) => b.classList.toggle("on", b.textContent === t)); } }, t));
  tools.forEach((b) => b.classList.toggle("on", b.textContent === s.tool));
  const pick = (key, title) => {
    const el = h("input", { type: "color", value: s[key], title, oninput: () => { s[key] = el.value; save(); } });
    return el;
  };
  const color = pick("color", "colour");
  const color2 = pick("color2", "second colour (gradients)");
  const fill = h("input", { type: "checkbox", checked: s.fill, onchange: () => { s.fill = fill.checked; save(); } });
  const swap = h("button", { title: "swap colours", onclick: () => {
    [s.color, s.color2] = [s.color2, s.color]; color.value = s.color; color2.value = s.color2; save(); } }, "⇄");
  const num = (key, step, title, min, max) => {
    const el = h("input", { type: "number", step, min, max, value: s[key], title, style: "width:76px",
      onchange: () => { s[key] = Number(el.value); save(); } });
    return el;
  };
  const prevAll = (fn) => { cx.globalAlpha = 1; cx.globalCompositeOperation = "source-over"; fn(); };
  const blend = h("select", { onchange: () => { s.blend = blend.value; save(); net.msg(`${D()}/blend`, s.blend); } },
    ["normal", "add", "lighten", "multiply"].map((b) => h("option", { value: b, selected: b === s.blend }, b)));
  const text = h("input", { type: "text", value: s.text, oninput: () => { s.text = text.value; save(); } });
  const fade = h("input", { type: "number", min: 0, max: 1, step: 0.05, value: 0.2 });
  const act = (label, fn) => h("button", { onclick: fn }, label);

  // save / recall: the slot's paint buffer as <name>.png in /media/debaz/img
  // (debazd encodes it in the background, about 1 s), back with /img/<slot>/load
  const pad = (n) => String(n).padStart(2, "0");
  const stamp = () => { const d = new Date();
    return `paint-${d.getFullYear()}${pad(d.getMonth() + 1)}${pad(d.getDate())}-` +
      `${pad(d.getHours())}${pad(d.getMinutes())}${pad(d.getSeconds())}`; };
  const clean = (n) => n.replace(/\.png$/i, "").replace(/[^A-Za-z0-9._-]+/g, "_").replace(/^[._]+/, "").slice(0, 92);
  const saveName = h("input", { type: "text", value: stamp(), style: "width:210px",
    title: "file name: A-Z a-z 0-9 . _ - (.png is added)" });
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
    const n = clean(saveName.value) || stamp();
    net.msg(`/surface/${s.slot}/save`, n);
    toast(`saving slot ${s.slot} as ${n}.png`);
    setTimeout(() => listImages(`${n}.png`), 2500); // the encode takes about 1 s
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

  const left = h("div.paint-left", {},
      h("div.row", {}, h("label", {}, "draw into"), slot,
        act("Show on display 0", () => net.msg("/disp/0/show", s.slot)),
        act("Show on display 1", () => net.msg("/disp/1/show", s.slot))),
      h("div.canvas-wrap", {}, cv, ov),
      h("p.hint", {}, "Preview of your own drawing only. Board-side effects (grab, transforms, LFOs) show on the display."));
  root.append(h("div.paint", {}, left,
    h("div", {},
      card("Tool", h("div.tools", {}, tools),
        row("colour", color, swap, color2, blend),
        row("filled", fill, h("span.hint", {}, "off = outline, 'size' px wide")),
        row("fill",
          h("select", { title: "fill of rect, ellipse and shape", onchange: (e) => { s.sfill = e.target.value; save(); } },
            ["solid", "linear", "radial"].map((v) => h("option", { value: v, selected: v === s.sfill }, v))),
          h("span.hint", {}, "angle"), num("gangle", 1, "linear gradient angle (degrees, in the shape)", -360, 360),
          h("span.hint", {}, "colour 1 → 2")),
        (() => { // rotation, also set by Shift+drag
          rotOut = h("span.hint", {}, String(s.rot));
          rotEl = h("input", { type: "range", min: -180, max: 180, step: 1, value: s.rot,
            oninput: () => setRot(Number(rotEl.value)) });
          return row("rotation", rotEl, rotOut);
        })(),
        row("shape",
          h("select", { onchange: (e) => { s.pstyle = e.target.value; save(); } },
            [["polygon", "polygon"], ["star", "star"], ["starpoly", "star polygon {n/k}"]].map(([v, t]) =>
              h("option", { value: v, selected: v === s.pstyle }, t))),
          h("span.hint", {}, "n"), num("sides", 1, "sides / points (n)", 3, 64),
          h("span.hint", {}, "k"), num("skip", 1, "star polygon: join every k-th point (5/2 = pentagram, 6/2 = star of David)", 2, 31),
          h("span.hint", {}, "inner"), num("inner", 0.05, "star: inner radius ratio (0 = classic)", 0, 1)),
        h("p.hint", {}, "Drag a box. Ctrl: square/circle/regular. Shift while dragging: rotate " +
          "(Ctrl+Shift: 15° steps). Shape: n sides; star: n points, inner ratio; star polygon: n and k."),
        slider("size", 1, 200, 1, "size"),
        slider("hard", 0, 1, 0.05, "hardness"),
        slider("alpha", 0, 1, 0.05, "alpha", () => net.msg(`${D()}/alpha`, net.float(s.alpha))),
        row("text", text),
        slider("scale", 1, 8, 1, "pixel ×"),
        slider("ttf", 8, 300, 1, "ttf px"),
        slider("sprite", 0, 63, 1, "sprite #"),
        slider("sscale", 0.05, 4, 0.05, "sprite ×"),
        slider("angle", -180, 180, 1, "angle")))));
  // board-side operations under the canvas, where there is room
  left.append(h("div.grid.paint-ops", {},
      card("Surface",
        row(null,
          act("Clear", () => { const [r, g, b] = rgb(); net.msg(`${D()}/clear`, r, g, b);
            cx.globalAlpha = 1; cx.globalCompositeOperation = "source-over"; cx.fillStyle = s.color; cx.fillRect(0, 0, W, H); }),
          act("Clear black", () => { net.msg(`${D()}/clear`, 0, 0, 0);
            cx.globalAlpha = 1; cx.globalCompositeOperation = "source-over"; cx.fillStyle = "#000"; cx.fillRect(0, 0, W, H); })),
        row("fade", fade, act("Fade", () => { net.msg(`${D()}/fade`, net.float(Number(fade.value)));
          cx.globalAlpha = Number(fade.value); cx.globalCompositeOperation = "source-over"; cx.fillStyle = "#000"; cx.fillRect(0, 0, W, H); })),
        row(null, act("Grab live input", () => net.msg(`/surface/${s.slot}/grab`, 4))),
        h("p.hint", {}, "Grab copies the live HDMI input into this slot: then paint on the frozen frame.")),
      card("Image",
        row("save as", saveName, act("Save", saveImage)),
        row("recall", imgSel, act("Load", loadImage), act("↻", () => listImages(imgSel.value))),
        h("p.hint", {}, "Save writes this slot's paint buffer (what you drew, also a grab) as a PNG on the board; " +
          "Load draws a saved image back into the slot, scaled to the full frame. Images also show in Media.")),
      card("Fill",
        row(null,
          act("Solid", () => { net.msg(`${D()}/solid`, ...rgb());
            prevAll(() => { previewStyle(); cx.fillStyle = s.color; cx.fillRect(0, 0, W, H); }); }),
          act("Test bars", () => {
            net.msg(`${D()}/bars`);
            prevAll(() => ["#fff", "#ff0", "#0ff", "#0f0", "#f0f", "#f00", "#00f", "#000"].forEach((c, i) => {
              cx.fillStyle = c; cx.fillRect((i * W) / 8, 0, W / 8 + 1, H); }));
          })),
        row("tool",
          h("select", { title: "gradient tool: drag direction (linear) or centre and radius (radial)",
            onchange: (e) => { s.gtype = e.target.value; save(); } },
            ["linear", "radial"].map((v) => h("option", { value: v, selected: v === s.gtype }, `gradient tool: ${v}`)))),
        row("gradient",
          act("Radial", () => { net.msg(`${D()}/gradient/radial`, ...rgb(), ...rgb2());
            previewRadial(W / 2, H / 2, Math.hypot(W, H) / 2); }),
          act("H", () => { net.msg(`${D()}/gradient/h`, ...rgb(), ...rgb2()); previewGradient(0, s.color, s.color2); }),
          act("V", () => { net.msg(`${D()}/gradient/v`, ...rgb(), ...rgb2()); previewGradient(90, s.color, s.color2); }),
          num("gangle", 1, "angle in degrees (0 = left to right, 90 = top to bottom)", -360, 360),
          act("Angle", () => { net.msg(`${D()}/gradient/angle`, net.float(s.gangle), ...rgb(), ...rgb2());
            previewGradient(s.gangle, s.color, s.color2); })),
        row("corners", pick("tl", "top left"), pick("tr", "top right"), pick("bl", "bottom left"), pick("br", "bottom right"),
          act("Corners", () => {
            net.msg(`${D()}/gradient/corners`, ...hexToRgb(s.tl), ...hexToRgb(s.tr), ...hexToRgb(s.bl), ...hexToRgb(s.br));
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
          act("Step", () => net.msg(`${D()}/rotozoom`, net.float(s.rz), net.float(s.zoom)))),
        row("scroll", num("dx", 1, "dx px", -1280, 1280), num("dy", 1, "dy px", -720, 720),
          act("Step", () => net.msg(`${D()}/scroll`, s.dx | 0, s.dy | 0))),
        row("mirror", act("H", () => net.msg(`${D()}/mirror`, "h")), act("V", () => net.msg(`${D()}/mirror`, "v")),
          act("Quad", () => net.msg(`${D()}/mirror`, "quad"))),
        row("wave",
          h("select", { title: "axis", onchange: (e) => { s.waxis = Number(e.target.value); save(); } },
            h("option", { value: 0, selected: s.waxis === 0 }, "rows"),
            h("option", { value: 1, selected: s.waxis === 1 }, "columns")),
          num("wamp", 1, "amplitude px", 0, 200), num("wper", 1, "period px", 4, 2000),
          act("Step", () => net.msg(`${D()}/wave`, s.waxis | 0, net.float(s.wamp), net.float(s.wper), net.float(Math.random())))),
        h("p.hint", {}, "Each Step runs once on the board. For motion, give an LFO a target, e.g. " +
          "/draw/6/rotozoom $f0 1.02 (every 2 frames)."))));
}
