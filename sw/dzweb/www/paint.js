// paint.js - draw into a slot with mouse, pen or touch. The canvas uses board
// coordinates (1280x720) and shows a local preview of what you draw; effects
// that run on the board (grab, transforms) show on the display only.
import * as net from "./net.js";
import { h, card, row, hexToRgb, store } from "./ui.js";

const W = 1280, H = 720;
const MAXPTS = 13; // stroke: 5 fixed args + 13 points = 31 args (< 32)
const DEF = { slot: 6, tool: "brush", color: "#ff9a3c", color2: "#2040ff", fill: true, size: 24, hard: 0.4,
  alpha: 1, blend: "normal", text: "DEBAZAROS", ttf: 64, scale: 2, sprite: 0, sscale: 1, angle: 0,
  gangle: 45, tl: "#ff0000", tr: "#00ff00", bl: "#0000ff", br: "#ffffff",
  rz: 3, zoom: 1.04, dx: 8, dy: 0, waxis: 0, wamp: 12, wper: 90 };
const s = { ...DEF, ...store.get("paint", {}) };
const DRAG = ["line", "rect", "ellipse", "gradient"]; // tools that use press-drag-release
let cv, cx, ov, ox, drawing = false, start = null, pending = [], last = null, raf = false;

const save = () => store.set("paint", s);
const rgb = () => hexToRgb(s.color);
const rgb2 = () => hexToRgb(s.color2);
const box = (a, b) => [Math.min(a[0], b[0]), Math.min(a[1], b[1]), Math.abs(b[0] - a[0]), Math.abs(b[1] - a[1])];
const thick = () => (s.fill ? 0 : Math.max(1, s.size | 0)); // 0 = filled
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
function previewShape(tool, a, b) {
  previewStyle();
  cx.fillStyle = cx.strokeStyle = s.color;
  cx.lineWidth = Math.max(1, s.size);
  const [x, y, w, hh] = box(a, b);
  cx.beginPath();
  if (tool === "rect") cx.rect(x, y, w, hh);
  else cx.ellipse(x + w / 2, y + hh / 2, Math.max(1, w / 2), Math.max(1, hh / 2), 0, 0, Math.PI * 2);
  s.fill ? cx.fill() : cx.stroke();
}
// rubber band on the overlay while a drag tool is down
function band(a, b) {
  ox.clearRect(0, 0, W, H);
  ox.strokeStyle = "#fff";
  ox.setLineDash([12, 8]);
  ox.lineWidth = 3;
  ox.beginPath();
  const [x, y, w, hh] = box(a, b);
  if (s.tool === "rect") ox.rect(x, y, w, hh);
  else if (s.tool === "ellipse") ox.ellipse(x + w / 2, y + hh / 2, Math.max(1, w / 2), Math.max(1, hh / 2), 0, 0, Math.PI * 2);
  else { ox.moveTo(...a); ox.lineTo(...b); }
  ox.stroke();
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
    start = p;
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
  if (drawing && start && DRAG.includes(s.tool)) return band(start, toBoard(e));
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
  } else if ((s.tool === "rect" || s.tool === "ellipse") && start) {
    const p = toBoard(e);
    const [r, g, b] = rgb();
    const [x, y, w, hh] = box(start, p);
    if (w > 1 && hh > 1) {
      if (s.tool === "rect") net.msg(`${D()}/rect`, r, g, b, x, y, w, hh, thick());
      else net.msg(`${D()}/ellipse`, r, g, b, x + (w >> 1), y + (hh >> 1), Math.max(1, w >> 1), Math.max(1, hh >> 1), thick());
      previewShape(s.tool, start, p);
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
  const tools = ["brush", "line", "rect", "ellipse", "gradient", "text", "ttf", "sprite"].map((t) =>
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
        row("filled", fill, h("span.hint", {}, "rect/ellipse; off = outline of 'size' px")),
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
      card("Fill",
        row(null,
          act("Solid", () => { net.msg(`${D()}/solid`, ...rgb());
            prevAll(() => { previewStyle(); cx.fillStyle = s.color; cx.fillRect(0, 0, W, H); }); }),
          act("Test bars", () => {
            net.msg(`${D()}/bars`);
            prevAll(() => ["#fff", "#ff0", "#0ff", "#0f0", "#f0f", "#f00", "#00f", "#000"].forEach((c, i) => {
              cx.fillStyle = c; cx.fillRect((i * W) / 8, 0, W / 8 + 1, H); }));
          })),
        row("gradient",
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
