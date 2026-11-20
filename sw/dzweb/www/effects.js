// effects.js - every control register, built from /fields (so a gateware
// change appears here without code changes). Mixer as a 9-channel table.
import * as net from "./net.js";
import { h, card, row } from "./ui.js";

const MODES = [
  [0, "0 zero"], [1, "1 MAC (sum of gains)"], [3, "3 pass"], [4, "4 constant K"], [5, "5 signed constant (g0)"],
  [0x10, "10 clip ≥ lo"], [0x11, "11 clip ≤ hi"], [0x12, "12 clip = lo"], [0x13, "13 clip band"],
  [0x20, "20 K if ≥ lo"], [0x21, "21 K if ≤ hi"], [0x22, "22 K if = lo"], [0x23, "23 K if band"],
];
const GROUPS = [ // title, path prefix
  ["HDMI_0 output", "/hdmi/0/"],
  ["HDMI_1 output", "/hdmi/1/"],
  ["DDS oscillators (PL)", "/dds/"],
  ["HDMI audio (out HDMI_1, in HDMI_2)", "/audio/"],
  ["User I/O lines PL_KEY0-5 (function 0 = input)", "/io/"],
  ["I2S (on the user I/O lines)", "/i2s/"],
];

let root;
let fields = [];
let hueUi = null;	// the Colour FX card's hue controls
let keyUpd = null;	// the Colour key card's /fx/key/color reply handler (the card is rebuilt)
const controls = new Map(); // path -> { set(raw), el }

function maxOf(width) {
  return width >= 31 ? 0x7fffffff : 2 ** width - 1;
}

function fieldControl(f, prefix = "") {
  const [path, , width, unit, ro, help] = f;
  const name = path.startsWith(prefix) ? path.slice(prefix.length) : path;
  const label = h("span.name", { title: `${path}\n${help}` }, name);
  if (ro) {
    const v = h("span", {}, "–");
    controls.set(path, { set: (raw) => (v.textContent = raw) });
    return h("div.field", {}, label, v, h("span"));
  }
  if (unit === "bool") {
    const cb = h("input", { type: "checkbox", title: `${path} <0|1>`, onchange: () => net.msg(path, cb.checked ? 1 : 0) });
    controls.set(path, { set: (raw) => (cb.checked = !!raw) });
    return h("div.field", {}, label, cb, h("span"));
  }
  if (unit === "q16s") { // signed gain (mixer coreRevision 25): signed int, 0x10000 = 1.0
    const half = 2 ** (width - 1);
    const num = h("input", { type: "number", step: 1, min: -half, max: half - 1, value: 0,
      title: `${path} <int>: signed, 0x10000 = 1.0` });
    num.onchange = () => net.msg(path, Math.round(Number(num.value)) | 0);
    controls.set(path, { set: (raw) => (num.value = raw >= half ? raw - 2 * half : raw) });
    return h("div.field", {}, label, h("span"), num);
  }
  if (unit === "hz") {
    const num = h("input", { type: "number", step: "0.1", min: 0, title: `${path} <Hz, float>` });
    const rng = h("input", { type: "range", min: 0, max: 200, step: 0.1, title: `${path} <Hz, float>` });
    const sendHz = (v) => net.throttled(path, () => net.message(path, net.float(Number(v))));
    num.oninput = () => { rng.value = num.value; sendHz(num.value); };
    rng.oninput = () => { num.value = rng.value; sendHz(rng.value); };
    controls.set(path, { set: (raw, norm) => { num.value = norm.toFixed(2); rng.value = norm; } });
    return h("div.field", {}, label, rng, num);
  }
  const max = maxOf(width);
  const num = h("input", { type: "number", min: 0, max, title: `${path} <0..${max}> (int raw; float 0..1 = scaled)` });
  const sendRaw = (v) => net.throttled(path, () => net.message(path, Math.round(Number(v)) | 0));
  if (width > 16) {
    num.onchange = () => sendRaw(num.value);
    controls.set(path, { set: (raw) => (num.value = raw) });
    num.title = `${path} <0…${max}>`;
    return h("div.field", {}, label, h("span"), num);
  }
  const rng = h("input", { type: "range", min: 0, max, step: 1, title: `${path} <0..${max}>` });
  rng.oninput = () => { num.value = rng.value; sendRaw(rng.value); };
  num.onchange = () => { rng.value = num.value; sendRaw(num.value); };
  controls.set(path, { set: (raw) => { rng.value = raw; num.value = raw; } });
  return h("div.field", {}, label, rng, num);
}

const hex24 = (hex) => parseInt(hex.slice(1), 16);
let refreshTimer;
const refreshSoon = () => { clearTimeout(refreshTimer); refreshTimer = setTimeout(refresh, 300); };

// Colour matrix (hue, map) and colour key: debazd /fx/... (sw/debazd/fx.c).
// Both write the mixer; "Boot setup" puts back the debazarosit.sh values.
function fxCard() {
  const deg = h("input", { type: "range", min: -180, max: 180, step: 1, value: 0,
    title: "/fx/hue/deg <degrees>  (or /fx/hue <deg> [gain])" });
  const gain = h("input", { type: "range", min: 0, max: 2, step: 0.01, value: 1,
    title: "/fx/hue/gain <0..1> (signed: 0..4)" });
  const sat = h("input", { type: "range", min: -1, max: 3, step: 0.05, value: 1,
    title: "/fx/hue/sat <f>: 1 = as is, 0 = grey, > 1 more, < 0 the complement\n(needs signed for > 1 and < 0)" });
  const degOut = h("span", {}, "0°"), satOut = h("span", {}, "1.00");
  const sendHue = () => {
    degOut.textContent = `${deg.value}°`;
    net.throttled("/fx/hue", () => net.message("/fx/hue", net.float(Number(deg.value)),
      net.float(Number(gain.value))));	// = /fx/hue/deg + /fx/hue/gain
    refreshSoon();
  };
  const sendSat = () => {
    satOut.textContent = Number(sat.value).toFixed(2);
    net.throttled("/fx/hue/sat", () => net.message("/fx/hue/sat", net.float(Number(sat.value))));
    refreshSoon();
  };
  deg.oninput = sendHue;
  gain.oninput = sendHue;
  sat.oninput = sendSat;
  const signed = h("input", { type: "checkbox",
    title: "/fx/signed <0|1>: write the matrix as mode 5 signed constants (bitstream smix or later)\n" +
      "exact hue at every angle, saturation, negative entries; results outside 0..255 wrap",
    onchange: () => { net.msg("/fx/signed", signed.checked ? 1 : 0); sendHue(); } });
  hueUi = { deg, degOut, gain, sat, satOut, signed };	// for the /fx/hue, /fx/signed replies (init)
  const pick = (v, t) => h("input", { type: "color", value: v, title: t });
  const mapR = pick("#ff0000", "where input red goes\n/fx/map <0xRRGGBB r> <g> <b>"),
    mapG = pick("#00ff00", "where input green goes\n/fx/map <r> <0xRRGGBB g> <b>"),
    mapB = pick("#0000ff", "where input blue goes\n/fx/map <r> <g> <0xRRGGBB b>");
  const wrap = h("input", { type: "checkbox", title: "allow row sums > 1 (bright colours wrap)",
    onchange: () => net.msg("/fx/wrap", wrap.checked ? 1 : 0) });
  const boot = () => {
    const m = [];
    for (let c = 0; c < 9; c++) {
      const diag = c === 0 || c === 5 || c === 7;
      m.push(net.message(`/mixer/${c}/mode`, diag ? 4 : 0x23),
        net.message(`/mixer/${c}/k`, diag ? 0x8000 : 0xffff));
      if (!diag) m.push(net.message(`/mixer/${c}/lo`, 0x20), net.message(`/mixer/${c}/hi`, 0xed));
    }
    net.send(net.bundle(...m));
    refreshSoon();
  };
  return card("Colour FX (HDMI_0)",
    row("Hue", deg, degOut),
    row("Gain", gain),
    row("Saturation", sat, satOut),
    row("", h("label", {}, signed, " signed gains (mode 5)")),
    row("Map R G B →", mapR, mapG, mapB,
      h("button", { title: "/fx/map <0xRRGGBB> <0xRRGGBB> <0xRRGGBB>", onclick: () => { net.msg("/fx/map", hex24(mapR.value), hex24(mapG.value),
        hex24(mapB.value)); refreshSoon(); } }, "Apply")),
    row("", h("button", { title: "/fx/identity", onclick: () => { deg.value = 0; degOut.textContent = "0°";
      net.msg("/fx/identity"); refreshSoon(); } }, "Identity"),
      h("button.ghost", { title: "the debazarosit.sh mixer setup\n/mixer/<c>/mode, /k, /lo, /hi (all 9 channels)", onclick: boot }, "Boot setup"), h("label", {}, wrap, " wrap")),
    h("p.hint", {}, "Hue and map set all 9 mixer channels to constant gains. " +
      "Unsigned (mode 4): between 0°, 120° and 240° the colours lose saturation, and saturation > 1 does little. " +
      "Signed (mode 5): exact at every angle; as in the rest of the gateware, a result outside 0..255 wraps."),
    h("p.hint", {}, "The colour key has its own card (Colour key)."));
}

// Colour key (2026-11-20, own card): debazd /fx/key/... (fx.c) over the mixer's
// per-channel lo/hi bands (channels 0 / 6 / 3 = R / G / B, their KEY bits).
// The eyedropper saves the tested display's slot as keypick.jpg (debazd
// /surface/<s>/save, served by dzweb /media/img) and averages 5 x 5 pixels of
// it in the browser: a colour taken from the picture needs a small tolerance,
// a pure colour from the colour dialog (#00ff00) is often 60-90 levels away
// from the same green in real video on every channel.
function keyCard() {
  const clamp = (v) => Math.max(0, Math.min(255, v | 0));
  const hex2 = (v) => v.toString(16).padStart(2, "0");
  const rgbOf = (hex) => [1, 3, 5].map((i) => parseInt(hex.slice(i, i + 2), 16));
  const hexOf = ([r, g, b]) => `#${hex2(r)}${hex2(g)}${hex2(b)}`;
  const st = { on: false, col: "#00ff00", tol: 30, src: 0, lo: [0, 225, 0], hi: [30, 255, 30], custom: false };

  const col = h("input", { type: "color", value: st.col, title: "the key colour\n/fx/key/color <0xRRGGBB> <tolerance>" });
  const swatch = h("span.hint", {}, "");
  const tol = h("input", { type: "range", min: 0, max: 128, step: 1, value: st.tol, style: "flex:1;min-width:140px",
    title: "how far each of red, green and blue may be from the key colour (0..255 levels)\n/fx/key/tol <0..128>" });
  const tolOut = h("span.hint", {}, "");
  const boxOut = h("div.hint", {}, "");
  const on = h("input", { type: "checkbox", title: "on: /fx/key/color (or /fx/key/range)\noff: /fx/key/off" });
  const srcSel = h("select", { title: "which picture is compared with the key colour\n/fx/key/source <0|1>" },
    h("option", { value: 0 }, "HDMI_1's picture"),
    h("option", { value: 1 }, "HDMI_0's own picture"));
  // per-channel ranges (advanced): lo / hi per channel -> /fx/key/range lo hi
  const rng = ["R", "G", "B"].map((name, k) => {
    const lo = h("input", { type: "number", min: 0, max: 255, value: st.lo[k], style: "width:70px", title: `${name} low (0..255)` });
    const hi = h("input", { type: "number", min: 0, max: 255, value: st.hi[k], style: "width:70px", title: `${name} high (0..255)` });
    lo.oninput = hi.oninput = () => { st.custom = true; st.lo[k] = clamp(lo.value); st.hi[k] = clamp(hi.value); showBox(); };
    return { name, lo, hi };
  });
  const showBox = () => {
    const pct = Math.round((st.tol / 255) * 100);
    tolOut.textContent = `± ${st.tol} of 255 (${pct} %) per channel`;
    const [r, g, b] = rgbOf(st.col);
    swatch.textContent = `${r}, ${g}, ${b}`;
    if (!st.custom) {
      st.lo = [r, g, b].map((v) => clamp(v - st.tol));
      st.hi = [r, g, b].map((v) => clamp(v + st.tol));
      rng.forEach((x, k) => { x.lo.value = st.lo[k]; x.hi.value = st.hi[k]; });
    }
    boxOut.textContent = "keyed where " + rng.map((x, k) => `${x.name} ${st.lo[k]}–${st.hi[k]}`).join("  ·  ") +
      (st.custom ? "  (per-channel ranges)" : "");
  };
  const send = () => {
    showBox();
    if (!st.on) return;
    if (st.custom) {
      const pack = (v) => (v[0] << 16) | (v[1] << 8) | v[2];
      net.throttled("/fx/key", () => net.message("/fx/key/range", pack(st.lo), pack(st.hi)));
    } else {
      net.throttled("/fx/key", () => net.message("/fx/key/color", parseInt(st.col.slice(1), 16), st.tol));
    }
  };
  col.oninput = () => { st.col = col.value; st.custom = false; send(); };
  tol.oninput = () => { st.tol = Number(tol.value); st.custom = false; send(); };
  on.onchange = () => { st.on = on.checked; if (st.on) send(); else net.msg("/fx/key/off"); };
  srcSel.onchange = () => { st.src = Number(srcSel.value); net.msg("/fx/key/source", st.src); };

  // eyedropper: a frame of the tested display, click = the colour there
  const img = h("img", { alt: "", style: "max-width:100%;cursor:crosshair;display:none;border:1px solid var(--line);border-radius:6px",
    title: "click: take the colour here (5 x 5 pixels averaged) as the key colour" });
  const pickNote = h("span.hint", {}, "");
  const grab = async () => {
    const d = st.src ? 0 : 1;
    const r = await net.ask(net.message(`/disp/${d}`), (m) => m.path === `/disp/${d}`);
    const slot = r && typeof r.args[0] === "number" ? r.args[0] : (d ? 2 : 0);
    net.msg(`/surface/${slot}/save`, "keypick.jpg");
    pickNote.textContent = `slot ${slot} (display ${d})…`;
    await new Promise((res) => setTimeout(res, 900));
    img.onload = () => { img.style.display = ""; pickNote.textContent = `slot ${slot} (display ${d}): click a colour`; };
    img.onerror = () => { pickNote.textContent = "no picture (Media tab: is keypick.jpg there?)"; };
    img.src = `${net.httpBase()}/media/img/keypick.jpg?t=${Date.now()}`;
  };
  img.onclick = (e) => {
    const r = img.getBoundingClientRect();
    const x = Math.round(((e.clientX - r.left) / r.width) * img.naturalWidth);
    const y = Math.round(((e.clientY - r.top) / r.height) * img.naturalHeight);
    const cv = document.createElement("canvas");
    cv.width = img.naturalWidth; cv.height = img.naturalHeight;
    const cx = cv.getContext("2d");
    cx.drawImage(img, 0, 0);
    const d = cx.getImageData(Math.max(0, x - 2), Math.max(0, y - 2), 5, 5).data;
    const sum = [0, 0, 0];
    for (let i = 0; i < d.length; i += 4) { sum[0] += d[i]; sum[1] += d[i + 1]; sum[2] += d[i + 2]; }
    const n = d.length / 4;
    st.col = hexOf(sum.map((v) => Math.round(v / n)));
    col.value = st.col;
    st.custom = false;
    if (!st.on) { st.on = true; on.checked = true; }
    send();
    net.msg("/fx/key/source", st.src);
  };
  const keyField = (p) => {
    const f = fields.find((x) => x[0] === p);
    return f ? fieldControl(f, "/key/") : null;
  };
  // the board's key colour / tolerance now (one listener in init calls this)
  keyUpd = (m) => {
    if (m.args.length < 2 || document.activeElement === tol) return;
    st.col = `#${(m.args[0] >>> 0).toString(16).padStart(6, "0").slice(-6)}`;
    st.tol = m.args[1];
    col.value = st.col; tol.value = st.tol; st.custom = false; showBox();
  };
  setTimeout(() => net.msg("/fx/key/color"), 400);
  showBox();

  return card("Colour key (HDMI_0)",
    h("p.hint", {}, "HDMI_0 shows HDMI_1's picture wherever the tested picture has the key colour, " +
      "and its own picture everywhere else. \"Has the key colour\" means: red, green and blue are ALL " +
      "within the box below. Test HDMI_1's picture: where it has the colour, it shows through. Test HDMI_0's " +
      "own picture: a green screen in HDMI_0's video is replaced by HDMI_1."),
    row("", h("label", {}, on, " key on")),
    row("Test", srcSel),
    row("Pick", h("button", { onclick: grab, title: "save a frame of the tested display's slot (keypick.jpg in Images) and show it here" },
      "Grab a frame"), pickNote),
    img,
    row("Key colour", col, swatch),
    row("Tolerance", tol),
    row("", tolOut),
    boxOut,
    h("p.hint", {}, "Take the key colour from the picture (Grab a frame, then click on it): real footage is never " +
      "a pure colour, and the same green can sit 60–90 levels away from #00ff00 on every channel - then only a " +
      "huge tolerance catches it. From the picture, ± 15–40 is usually enough; raise it until the area is " +
      "keyed, lower it when other areas start to key too."),
    h("details", {}, h("summary", {}, "Per-channel ranges (advanced)"),
      h("p.hint", {}, "One low..high range per channel instead of colour ± tolerance, e.g. a green screen whose " +
        "brightness varies a lot: G wide, R and B narrow. Editing a value switches to these ranges; moving the " +
        "colour or tolerance goes back."),
      ...rng.map((x) => row(x.name, x.lo, "–", x.hi)),
      row("", h("button", { onclick: () => { st.custom = true; send(); }, title: "/fx/key/range <0xRRGGBB low> <0xRRGGBB high>" }, "Apply ranges"))),
    ...["/key/invert", "/key/stream"].map(keyField),
    h("p.hint", {}, "invert: key everything OUTSIDE the box instead (keep the key colour, replace the rest). " +
      "stream: fill the keyed area from HDMI_1's line-delayed copy (stream B) instead of its live picture. " +
      "The test compares HDMI_1's OUTPUT (after its gains and feedback), so pick while HDMI_1 shows what it will show."));
}

// HDMI_1 cross-fade (debazd trans.c): own slot <-> HDMI_0's output through the two gain
// words; the board keeps own + feedback = the level G per lane, so the adder never wraps
function xfadeCard() {
  const t = h("input", { type: "range", min: 0, max: 1, step: 0.001, value: 0,
    title: "drag = at once\n/fx/xfade t (0 = HDMI_1's own slot, 1 = HDMI_0's output)" });
  const tOut = h("span", {}, "0.000");
  const secs = h("input", { type: "number", min: 0, max: 600, step: 0.1, value: 3, style: "width:5em",
    title: "fade time of the buttons, seconds" });
  const smooth = h("input", { type: "checkbox", title: "S curve instead of linear" });
  const st = h("span.hint", {}, "");
  const show = (v) => { t.value = v; tOut.textContent = Number(v).toFixed(3); };
  t.oninput = () => {
    show(t.value);
    net.throttled("/fx/xfade", () => net.message("/fx/xfade", net.float(Number(t.value))));
  };
  const go = (to) => {
    const a = [net.float(to), net.float(Number(secs.value) || 0)];
    if (smooth.checked) a.push("smooth");
    net.msg("/fx/xfade", ...a);
    poll();
  };
  let timer = 0;
  const poll = () => {        // follow a running fade
    clearTimeout(timer);
    let n = Math.ceil(((Number(secs.value) || 0) + 0.5) / 0.2);
    const step = () => {
      net.send(net.bundle(net.message("/fx/xfade"), net.message("/trans/status")));
      if (--n > 0) timer = setTimeout(step, 200);
    };
    step();
  };
  net.on("/fx/xfade", (m) => { if (m.args.length && document.activeElement !== t) show(m.args[0]); });
  net.on("/trans/status", (m) => { st.textContent = m.args[0] ? `${m.args[0]} ramp(s) running` : "idle"; });
  net.send(net.bundle(net.message("/fx/xfade"), net.message("/trans/status"))); // position now
  return card("Cross-fade (HDMI_1)",
    row("t", t, tOut),
    row("fade", secs, h("label", {}, "s"), h("label", {}, smooth, " smooth")),
    row(null,
      h("button", { title: "/fx/xfade 0 <s> [smooth]", onclick: () => go(0) }, "→ own (0)"),
      h("button", { title: "/fx/xfade 0.5 <s> [smooth]", onclick: () => go(0.5) }, "½"),
      h("button.primary", { title: "/fx/xfade 1 <s> [smooth]", onclick: () => go(1) }, "→ HDMI_0 (1)"),
      h("button", { title: "/trans/stop: hold where it is", onclick: () => { net.msg("/trans/stop"); poll(); } }, "Stop"),
      h("button", { title: "/fx/xfade (query)", onclick: poll }, "Read")),
    row(null, st),
    h("p.hint", {}, "Fades HDMI_1 between its own slot and HDMI_0's output with the own and feedback " +
      "gains; per colour lane own + feedback stays at the level they had together (at most 255)."));
}

function mixerTable() {
  const tr = (c) => {
    const p = `/mixer/${c}`;
    const mode = h("select", { title: `${p}/mode <n>`, onchange: () => net.msg(`${p}/mode`, parseInt(mode.value)) },
      MODES.map(([v, t]) => h("option", { value: v }, t)));
    const num = (k, max) => {
      const n = h("input", { type: "number", min: 0, max, title: `${p}/${k} <0..${max}>`,
        onchange: () => net.msg(`${p}/${k}`, parseInt(n.value) || 0) });
      controls.set(`${p}/${k}`, { set: (raw) => (n.value = raw) });
      return h("td", {}, n);
    };
    const bit = (k, title) => {
      const cb = h("input", { type: "checkbox", title,
        onchange: () => net.msg(`${p}/${k}`, cb.checked ? 1 : 0) });
      controls.set(`${p}/${k}`, { set: (raw) => (cb.checked = !!raw) });
      return h("td", {}, cb);
    };
    // a signed gain (mixer coreRevision 25): an int, the 24-bit two's complement
    // value of gain [23:0] (0x10000 = 1.0; RGB gains are useful below ~255, the
    // oscillator gains below that); g0 = the mode 5 constant
    const sgain = (k) => {
      const n = h("input", { type: "number", step: 1, min: -8388608, max: 8388607, value: 0, style: "width:6.5em",
        title: `${p}/${k} <int>: signed, 0x10000 = 1.0, negative subtracts\n(raw unsigned: ${p}/gain/${k.slice(2)})`,
        onchange: () => net.msg(`${p}/${k}`, Math.round(Number(n.value)) | 0) });
      controls.set(`${p}/${k}`, { set: (raw) => (n.value = raw >= 0x800000 ? raw - 0x1000000 : raw) });
      return h("td", {}, n);
    };
    controls.set(`${p}/mode`, { set: (raw) => (mode.value = raw) });
    return h("tr", {}, h("td", {}, String(c)), h("td", {}, mode), num("k", 65535),
      num("lo", 255), num("hi", 255), bit("stream", "stream B (delayed copy)"),
      bit("key", "lo..hi band joins the colour key"), bit("src", "compare HDMI_0's video"),
      bit("diff", "mode 1: R B G inputs = stream A - stream B (edge / comb with the delay)"),
      bit("centre", "mode 1: R B G inputs - 128 (bipolar video)"),
      bit("dsign", "mode 1: sine / saw (din3, din4) as two's complement"),
      ...[0, 1, 2, 3, 4].map((g) => sgain(`g/${g}`)));
  };
  return h("div", { style: "overflow-x:auto" }, h("table.mixer", {},
    h("thead", {}, h("tr", {}, ...["ch", "mode", "K", "lo", "hi", "B", "key", "src", "A−B", "−128", "±dds",
      "g0 R", "g1 B", "g2 G", "g3 sin", "g4 saw"].map((t) => h("th", {}, t)))),
    h("tbody", {}, [...Array(9).keys()].map(tr))));
}

async function load() {
  fields = await net.collect(net.message("/fields"), "/field", "/field/end");
  controls.clear();
  const grid = h("div.grid");
  for (const [title, prefix] of GROUPS) {
    const fs = fields.filter((f) => f[0].startsWith(prefix) && !f[4] && f[3] !== "rgb");
    if (fs.length) grid.append(card(title, ...fs.map((f) => fieldControl(f, prefix))));
  }
  const status = fields.filter((f) => f[4]);
  grid.append(card(["Inputs (read only)",
    h("button.ghost", { title: "query every field (/<field> -> /value)", onclick: refresh, style: "margin-left:auto" }, "Refresh")],
    ...status.map((f) => fieldControl(f, "/"))));
  grid.append(fxCard());
  grid.append(keyCard());
  grid.prepend(xfadeCard()); // first: the quick test of /fx/xfade
  root.replaceChildren(grid, card("Mixer (HDMI_0 colour matrix, 9 channels)", mixerTable(),
    h("p.hint", {}, "Each channel makes one gain of the 3×3 colour matrix. Inputs: " +
      "din0 R, din1 B, din2 G of HDMI_1 (stream A, or the delayed stream B), din3 sine, din4 saw. " +
      "Gains g0..g4 are signed ints (0x10000 = 1.0, negative subtracts; bitstream smix or later). Mode 1 options: A−B (stream A minus " +
      "the delayed stream B: edges / comb), −128 (bipolar video), ±dds (sine and saw signed). " +
      "Mode 1 is timed for 720p60 only.")));
  refresh();
}

function refresh() {
  const paths = fields.filter((f) => f[3] !== "rgb").map((f) => f[0]);
  for (let i = 0; i < paths.length; i += 24) // bundles of 24 queries
    net.send(net.bundle(...paths.slice(i, i + 24).map((p) => net.message(p))));
}

export function init(el) {
  root = el;
  root.append(h("p.hint", {}, "Connecting…"));
  net.on("/value", (m) => {
    const [path, raw, norm] = m.args;
    controls.get(path)?.set(raw, norm);
  });
  // the board's state: /fx/hue -> deg gain sat, /fx/signed -> i
  net.on("/fx/hue", (m) => {
    const u = hueUi, [d, g, s] = m.args;
    if (!u) return;
    if (document.activeElement !== u.deg) { u.deg.value = d; u.degOut.textContent = `${Math.round(d)}°`; }
    if (document.activeElement !== u.gain) u.gain.value = g;
    if (s !== undefined && document.activeElement !== u.sat) { u.sat.value = s; u.satOut.textContent = Number(s).toFixed(2); }
  });
  net.on("/fx/signed", (m) => { if (hueUi) hueUi.signed.checked = !!m.args[0]; });
  net.on("/fx/key/color", (m) => { if (keyUpd) keyUpd(m); });
}

export function connected() {
  load();
  net.msg("/fx/hue");
  net.msg("/fx/signed");
}

export function show() {
  if (fields.length) refresh();
  net.msg("/fx/xfade");
  net.msg("/fx/hue");
  net.msg("/fx/signed");
}
