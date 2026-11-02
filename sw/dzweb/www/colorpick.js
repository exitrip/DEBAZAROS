// colorpick.js - inline colour picker for the Paint tab: saturation/value square,
// hue bar, alpha bar (the slot's draw alpha), hex and R G B fields, the two paint
// colours (click one to edit it, ⇄ swaps), recent colours and a palette.
import { h, store } from "./ui.js";

const PALETTE = ["#000000", "#404040", "#808080", "#c0c0c0", "#ffffff", "#ff0000", "#ff8000", "#ffff00",
  "#80ff00", "#00ff00", "#00ff80", "#00ffff", "#0080ff", "#0000ff", "#8000ff", "#ff00ff", "#ff0080", "#804000"];

export function hsvToRgb(hh, ss, vv) {
  const f = (n) => { const k = (n + hh / 60) % 6; return vv - vv * ss * Math.max(0, Math.min(k, 4 - k, 1)); };
  return [f(5), f(3), f(1)].map((x) => Math.round(x * 255));
}
export function rgbToHsv(r, g, b) {
  r /= 255; g /= 255; b /= 255;
  const mx = Math.max(r, g, b), mn = Math.min(r, g, b), d = mx - mn;
  let hh = 0;
  if (d) hh = mx === r ? ((g - b) / d) % 6 : mx === g ? (b - r) / d + 2 : (r - g) / d + 4;
  return [(hh * 60 + 360) % 360, mx ? d / mx : 0, mx];
}
const hex = (r, g, b) => "#" + [r, g, b].map((v) => v.toString(16).padStart(2, "0")).join("");
const unhex = (x) => [1, 3, 5].map((i) => parseInt(x.slice(i, i + 2), 16));

// state: { color, color2, alpha }; onchange(key) after every change, oncommit() at the
// end of a drag (recent colours, saving)
export function colorPicker(state, onchange, oncommit) {
  let target = "color", hsv = rgbToHsv(...unhex(state[target]));
  let recent = store.get("paint-recent", []);
  const SW = 236, SH = 140;
  const sv = h("canvas.cp-sv", { width: SW, height: SH, title: "saturation (left → right), value (bottom → top)" });
  const hue = h("canvas.cp-bar", { width: SW, height: 16, title: "hue" });
  const al = h("canvas.cp-bar", { width: SW, height: 16, title: "alpha of what you draw (/draw/<slot>/alpha)" });
  const svx = sv.getContext("2d"), hx = hue.getContext("2d"), ax = al.getContext("2d");
  const hexIn = h("input.cp-hex", { type: "text", maxLength: 7, title: "hex #rrggbb" });
  const chan = [0, 1, 2].map((k) => h("input.cp-num", { type: "number", min: 0, max: 255, title: "RGB"[k] }));
  const alIn = h("input.cp-num", { type: "number", min: 0, max: 100, title: "alpha %" });
  const sw1 = h("button.cp-swatch", { title: "colour 1 (click to edit)" });
  const sw2 = h("button.cp-swatch.small", { title: "colour 2: gradients, radial and linear fills (click to edit)" });
  const recentRow = h("div.cp-swatches", {});
  const palRow = h("div.cp-swatches", {}, PALETTE.map((c) => h("button.cp-chip", { style: `background:${c}`, title: c,
    onclick: () => { setHex(c); commit(); } })));

  function checker(ctx, w, hh) {
    for (let x = 0; x < w; x += 8) for (let y = 0; y < hh; y += 8) {
      ctx.fillStyle = (x / 8 + y / 8) % 2 ? "#777" : "#bbb";
      ctx.fillRect(x, y, 8, 8);
    }
  }
  function paint() {
    const [r, g, b] = hsvToRgb(...hsv);
    // S/V square: hue colour, white to the left, black to the bottom
    svx.fillStyle = `hsl(${hsv[0]} 100% 50%)`;
    svx.fillRect(0, 0, SW, SH);
    let gr = svx.createLinearGradient(0, 0, SW, 0);
    gr.addColorStop(0, "#fff"); gr.addColorStop(1, "rgba(255,255,255,0)");
    svx.fillStyle = gr; svx.fillRect(0, 0, SW, SH);
    gr = svx.createLinearGradient(0, 0, 0, SH);
    gr.addColorStop(0, "rgba(0,0,0,0)"); gr.addColorStop(1, "#000");
    svx.fillStyle = gr; svx.fillRect(0, 0, SW, SH);
    const px = hsv[1] * SW, py = (1 - hsv[2]) * SH;
    svx.lineWidth = 2;
    svx.strokeStyle = hsv[2] > 0.5 ? "#000" : "#fff";
    svx.beginPath(); svx.arc(px, py, 6, 0, Math.PI * 2); svx.stroke();
    // hue bar
    gr = hx.createLinearGradient(0, 0, SW, 0);
    for (let k = 0; k <= 6; k++) gr.addColorStop(k / 6, `hsl(${k * 60} 100% 50%)`);
    hx.fillStyle = gr; hx.fillRect(0, 0, SW, 16);
    hx.fillStyle = "#fff"; hx.fillRect((hsv[0] / 360) * SW - 2, 0, 4, 16);
    hx.strokeStyle = "#000"; hx.strokeRect((hsv[0] / 360) * SW - 2, 0, 4, 16);
    // alpha bar
    checker(ax, SW, 16);
    gr = ax.createLinearGradient(0, 0, SW, 0);
    gr.addColorStop(0, `rgba(${r},${g},${b},0)`); gr.addColorStop(1, `rgb(${r},${g},${b})`);
    ax.fillStyle = gr; ax.fillRect(0, 0, SW, 16);
    ax.fillStyle = "#fff"; ax.fillRect(state.alpha * SW - 2, 0, 4, 16);
    ax.strokeStyle = "#000"; ax.strokeRect(state.alpha * SW - 2, 0, 4, 16);
    // fields
    if (document.activeElement !== hexIn) hexIn.value = state[target];
    [r, g, b].forEach((v, k) => { if (document.activeElement !== chan[k]) chan[k].value = v; });
    if (document.activeElement !== alIn) alIn.value = Math.round(state.alpha * 100);
    sw1.style.background = state.color;
    sw2.style.background = state.color2;
    sw1.classList.toggle("on", target === "color");
    sw2.classList.toggle("on", target === "color2");
  }
  function drawRecent() {
    recentRow.replaceChildren(...recent.map((c) => h("button.cp-chip", { style: `background:${c}`, title: c,
      onclick: () => { setHex(c); commit(); } })));
  }
  function fromHsv() {
    state[target] = hex(...hsvToRgb(...hsv));
    paint();
    onchange(target);
  }
  function setHex(c) {
    if (!/^#[0-9a-f]{6}$/i.test(c)) return;
    state[target] = c.toLowerCase();
    const n = rgbToHsv(...unhex(state[target]));
    if (n[1] === 0 || n[2] === 0) n[0] = hsv[0];	// grey/black: keep the hue
    hsv = n;
    paint();
    onchange(target);
  }
  function commit() {
    const c = state[target];
    recent = [c, ...recent.filter((x) => x !== c)].slice(0, 18);
    store.set("paint-recent", recent);
    drawRecent();
    oncommit?.();
  }
  function drag(el, fn) {
    const at = (e) => { const r = el.getBoundingClientRect();
      fn(Math.min(1, Math.max(0, (e.clientX - r.left) / r.width)), Math.min(1, Math.max(0, (e.clientY - r.top) / r.height))); };
    el.addEventListener("pointerdown", (e) => { el.setPointerCapture(e.pointerId); at(e); });
    el.addEventListener("pointermove", (e) => { if (el.hasPointerCapture(e.pointerId)) at(e); });
    el.addEventListener("pointerup", () => commit());
  }
  drag(sv, (x, y) => { hsv = [hsv[0], x, 1 - y]; fromHsv(); });
  drag(hue, (x) => { hsv = [x * 360, hsv[1] || (hsv[2] ? hsv[1] : 1), hsv[2] || 1]; fromHsv(); });
  drag(al, (x) => { state.alpha = Math.round(x * 100) / 100; paint(); onchange("alpha"); });
  hexIn.onchange = () => { setHex(hexIn.value.startsWith("#") ? hexIn.value : "#" + hexIn.value); commit(); };
  chan.forEach((el) => (el.onchange = () => { setHex(hex(...chan.map((c) => Math.max(0, Math.min(255, +c.value | 0))))); commit(); }));
  alIn.onchange = () => { state.alpha = Math.max(0, Math.min(100, +alIn.value)) / 100; paint(); onchange("alpha"); oncommit?.(); };
  const edit = (t) => { target = t; hsv = rgbToHsv(...unhex(state[t])); paint(); };
  sw1.onclick = () => edit("color");
  sw2.onclick = () => edit("color2");
  const swap = h("button.ghost", { title: "swap colours (X)", onclick: () => api.swap() }, "⇄");

  const api = {
    el: h("div.cp", {},
      h("div.cp-top", {}, h("div.cp-pair", {}, sw1, sw2, swap), h("div.cp-fields", {},
        hexIn, h("div.cp-rgb", {}, chan), h("label.cp-al", {}, "α", alIn, "%"))),
      sv, hue, al,
      h("div.hint", {}, "recent"), recentRow,
      h("div.hint", {}, "palette"), palRow),
    // outside changes (eyedropper, swap, shortcuts): show them
    refresh() { hsv = rgbToHsv(...unhex(state[target])); paint(); },
    set(c) { setHex(c); commit(); },
    swap() { [state.color, state.color2] = [state.color2, state.color]; api.refresh(); onchange("color"); oncommit?.(); },
  };
  drawRecent();
  paint();
  return api;
}
