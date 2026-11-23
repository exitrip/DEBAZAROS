// lfo.js - the 16 soft oscillators in debazd. debazd keeps the settings but
// reports only value and on, so this page keeps a copy of what it sent.
// Shape "audio" (2026-11-01): the value follows a feature of debazd's audio
// analysis (react.c), chosen with /audio/react/source.
// Step sequencer (2026-11-22, shape step): a step editor (drag = values,
// "lengths" = step lengths: bar width), step clock (frames / Hz / BPM / the
// steps of another LFO), ease + glide, every change / step. The cycle = the
// sum of the steps. Long sequences go as one string (/lfo/<n>/seq "v v ...").
import * as net from "./net.js";
import { h, card, store } from "./ui.js";

const N = 16;
const SHAPES = ["sine", "tri", "saw", "ramp", "square", "random", "smooth", "step", "noise", "audio"];
const FEATURES = ["level", "peak", "bass", "low", "mid", "high", "air", "flux", "beat",
  ...[...Array(16).keys()].map((b) => `band${b}`)];
const REACT = ["level", "peak", "bass", "low", "mid", "high", "air", "flux", "beat"]; // /audio/react args 2..
const EXAMPLES = [
  "/hdmi/1/feedback/r",
  "/hdmi/0/gain/g",
  "/dds/0/hz",
  "/draw/6/brush 200 80 20 $0 $1 30 0",
  "/sprite/0/draw 6 640 360 1 $f2",
  "/draw/6/rotozoom $f3 1.02",
  "/disp/1/seq/rate $4",
  "/disp/1/show $5",
];
// target presets for the tools that are not fields (2026-11-02): message templates;
// <s> = the slot (or display) box next to the menu, $v = this LFO's value ($k int, $fk
// float); choosing one also sets min / max. Live ffmpeg options act only while that
// filter runs (/movie/<s>/vf ...).
const PRESETS = [
  ["ASCII columns", "/ascii/<s>/cols $v", 4, 320],
  ["ASCII level (braille / half)", "/ascii/<s>/level $fv", 0, 1],
  ["ASCII every k frames", "/ascii/<s>/every $v", 1, 10],
  ["ASCII fg grey", "/ascii/<s>/fg $fv $fv $fv", 0, 1],
  ["crop x (display <s>)", "/disp/<s>/crop/x $v", 0, 640],
  ["crop y (display <s>)", "/disp/<s>/crop/y $v", 0, 360],
  ["movie corrupt (dzmosh)", "/movie/<s>/corrupt $fv", 0, 0.002],
  ["movie trails (fbfeed)", "/movie/<s>/trails $fv", 0, 0.98],
  ["movie ghost (fbfeed)", "/movie/<s>/ghost $fv", 0, 0.95],
  ["live hue (vf hue)", "/movie/<s>/vf/hue/h $fv", 0, 360],
  ["live hue saturation (vf hue)", "/movie/<s>/vf/hue/s $fv", 0, 3],
  ["live chromashift (vf chromashift)", "/movie/<s>/vf/chromashift/cbh $v", -40, 40],
  ["live lagfun decay (vf lagfun)", "/movie/<s>/vf/lagfun/decay $fv", 0.9, 1],
  ["live audio volume (af volume)", "/movie/<s>/af/volume/volume $fv", 0, 1],
  ["slot alpha", "/draw/<s>/alpha $fv", 0, 1],
];
const DEF = { on: 0, shape: "sine", rate: 1, frames: 0, lo: 0, hi: 1, width: 0.5, curve: 1,
  steps: 0, every: 1, once: 0, phase: 0, target: "", audio: "level", gain: 1, attack: 0, release: 0.15,
  seq: [0, 1, 0.5, 0.25], dur: [], smode: "off", sval: 15, sdiv: 4, ease: "step", glide: 0, emode: "frames",
  sync: -1, delay: 0, align: 0, fast: 0 };
const SMODES = [["off", "off (steps share rate)", ""], ["frames", "frames / step", 15], ["hz", "steps / s", 4],
  ["bpm", "BPM", 120], ["clock", "clock = LFO", 0]];

// seq, dur, step before shape (they select shape step; the shape wins)
const ALL = ["audio", "gain", "attack", "release", "seq", "dur", "step", "align", "sync", "delay", "fast", "ease", "glide", "shape", "rate", "frames",
  "range", "width", "curve", "steps", "every", "mode", "phase", "target", "on"];
const fmt = (a) => a.map((v) => +(+v).toFixed(4)).join(" ");
// the board's frame rate (/video/mode) and the fast thread's rate (/lfo/fastrate)
let frameHz = 60, fastHz = 1000;
// the shortest step length (in dur units) that still lasts one tick: one frame,
// or one fast tick (1/fastrate). A lengths drag stops there, never at 0: a 0
// step has no width on the canvas and cannot be dragged back (0 = skip is still
// allowed in the text box). Clock k: one step of LFO k.
function minLen(c) {
  const tick = 1 / (c.fast ? fastHz : frameHz);  // seconds
  const sum = () => c.seq.reduce((a, _, k) => a + (c.dur.length ? Math.max(0, +c.dur[k % c.dur.length]) : 1), 0) || c.seq.length;
  let m;
  if (c.sync >= 0) m = 0;                          // leader's cycle: not known here
  else if (c.smode === "frames") m = tick * frameHz / (c.sval || 1);
  else if (c.smode === "hz") m = tick * (c.sval || 1);
  else if (c.smode === "bpm") m = tick * (c.sval || 120) * (c.sdiv || 1) / 60;
  else if (c.smode === "clock") m = 1;
  else m = sum() * tick / (c.frames > 0 ? c.frames / frameHz : 1 / (c.rate || 1)); // steps share the cycle
  return Math.min(4, Math.max(1e-4, m));
}
let cfg = [];
// message targets from /state (not fields): address -> the OSC types of its values
// ("i", "fff"); Set on a bare address appends this LFO's value per type
const msgTargets = new Map(), fieldPaths = new Set();
function expandTarget(t, i) {
  if (!t || /\s/.test(t) || fieldPaths.has(t) || !msgTargets.has(t)) return t;
  return t + " " + [...msgTargets.get(t)].map((ty) => (ty === "i" ? `$${i}` : `$f${i}`)).join(" ");
}
const meters = [];
const unsent = [], updPaint = [], lastFrom = [], cardEl = [], sentAt = []; // per LFO: settings copied in the page, not sent yet (Update)
// the settings Copy takes: all but the target (two LFOs on one target fight)
// and on / off (the destination keeps its own)
const NOCOPY = new Set(["target", "pslot", "on"]);
let timer = null;

function save() {
  store.set("lfo", cfg);
}

function apply(i, keys) {
  const c = cfg[i];
  const p = `/lfo/${i}`;
  const m = [];
  for (const k of keys) {
    if (k === "shape") m.push(net.message(`${p}/shape`, c.shape));
    else if (k === "rate") m.push(net.message(`${p}/rate`, net.float(c.rate)));
    else if (k === "frames" && c.frames > 0) m.push(net.message(`${p}/frames`, c.frames | 0));
    else if (k === "range") m.push(net.message(`${p}/range`, net.float(c.lo), net.float(c.hi)));
    else if (k === "min") m.push(net.message(`${p}/min`, net.float(c.lo)));
    else if (k === "max") m.push(net.message(`${p}/max`, net.float(c.hi)));
    else if (k === "width") m.push(net.message(`${p}/width`, net.float(c.width)));
    else if (k === "curve") m.push(net.message(`${p}/curve`, net.float(c.curve)));
    else if (k === "steps") m.push(net.message(`${p}/steps`, c.steps | 0));
    else if (k === "every") m.push(c.emode === "frames" ? net.message(`${p}/every`, Math.max(1, c.every | 0))
      : net.message(`${p}/every`, c.emode));
    else if (k === "seq" && c.seq.length) m.push(net.message(`${p}/seq`, fmt(c.seq)));
    else if (k === "dur") m.push(c.dur.length ? net.message(`${p}/dur`, fmt(c.dur)) : net.message(`${p}/dur`));
    else if (k === "step") m.push(c.smode === "off" ? net.message(`${p}/step`, "off")
      : c.smode === "clock" ? net.message(`${p}/step`, "clock", c.sval | 0)
      : c.smode === "bpm" ? net.message(`${p}/step`, "bpm", net.float(c.sval), net.float(c.sdiv))
      : net.message(`${p}/step`, c.smode, net.float(c.sval)));
    else if (k === "ease") m.push(net.message(`${p}/ease`, c.ease));
    else if (k === "sync") m.push(c.sync >= 0 ? net.message(`${p}/sync`, c.sync | 0, net.float(c.delay)) : net.message(`${p}/sync`, "off"));
    else if (k === "delay") m.push(net.message(`${p}/delay`, net.float(c.delay)));
    else if (k === "align") m.push(net.message(`${p}/align`, c.align ? 1 : 0));
    else if (k === "fast") m.push(net.message(`${p}/fast`, c.fast ? 1 : 0));
    else if (k === "glide") m.push(net.message(`${p}/glide`, net.float(c.glide)));
    else if (k === "mode") m.push(net.message(`${p}/mode`, c.once ? "once" : "loop"));
    else if (k === "phase") m.push(net.message(`${p}/phase`, net.float(c.phase)));
    else if (k === "target") m.push(c.target ? net.message(`${p}/target`, c.target) : net.message(`${p}/target`));
    else if (k === "on") m.push(net.message(`${p}/on`, c.on ? 1 : 0));
    else if (k === "audio") m.push(net.message(`${p}/audio`, c.audio));	// also selects shape audio
    else if (k === "gain") m.push(net.message(`${p}/gain`, net.float(c.gain)));
    else if (k === "attack") m.push(net.message(`${p}/attack`, net.float(c.attack)));
    else if (k === "release") m.push(net.message(`${p}/release`, net.float(c.release)));
  }
  if (m.length) net.send(m.length === 1 ? m[0] : net.bundle(...m));
  sentAt[i] = performance.now();
  save();
  if (seqUi[i] && !seqUi[i].sec.hidden) seqUi[i].draw(); // step clock / fast / rate change the shortest step
}

// ---- step playhead: what the editor highlights ----
// The page polls /lfo/<n> every 250 ms, so the board's step number aliases
// once a step is shorter than ~0.5 s. Below that rate the editor shows the
// board's step; up to POV_HZ it runs its own playhead at the computed step rate
// (sequential, like the board, not in phase with it); above that one step per
// second, only to show that it runs.
const REAL_HZ = 2, POV_HZ = 12;
const lensOf = (c) => c.seq.map((_, k) => (c.dur.length ? Math.max(0, +c.dur[k % c.dur.length]) : 1));
// seconds per cycle of LFO i (null = not known), from the page's copy of its settings
function cycleSec(i, depth = 0) {
  const c = cfg[i];
  if (!c || depth > 4) return null;
  if (c.sync >= 0) return cycleSec(c.sync, depth + 1);
  const tot = lensOf(c).reduce((a, b) => a + b, 0);
  if (c.shape === "step" && c.smode !== "off") {
    if (c.smode === "frames") return tot * (c.sval || 1) / frameHz;
    if (c.smode === "hz") return tot / (c.sval || 1);
    if (c.smode === "bpm") return tot * 60 / ((c.sval || 120) * (c.sdiv || 1));
    if (c.smode === "clock") {          // one step per step (or cycle) of LFO k
      const k = c.sval | 0, L = cycleSec(k, depth + 1), lc = cfg[k];
      if (L == null || !lc) return null;
      const per = lc.shape === "step" ? L / Math.max(1, lensOf(lc).reduce((a, b) => a + b, 0)) : L; // seconds per unit step of k
      return tot * per;
    }
  }
  return c.frames > 0 ? c.frames / frameHz : 1 / (c.rate || 1);
}
let headRaf = 0;
function headLoop(now) {
  headRaf = 0;
  let any = false;
  for (const u of seqUi) if (u && !u.sec.hidden && u.tick(now)) any = true;
  if (any && document.getElementById("tab-lfo")?.classList.contains("active")) headRaf = requestAnimationFrame(headLoop);
}
const headStart = () => { if (!headRaf) headRaf = requestAnimationFrame(headLoop); };

// ---- the step editor ----
const seqUi = []; // per LFO: { draw, sec, step }
function seqSection(i, onShape) {
  const c = cfg[i];
  const cv = h("canvas.lfo-seq", { width: 600, height: 150,
    title: "drag: step values (top = max)\nlengths mode: drag = step length (bottom = the shortest step: one frame / one fast tick; max 4; 0 = skip only in the text box)\n" +
      `/lfo/${i}/seq "v v ..."  /lfo/${i}/dur "w w ..."` });
  const g = cv.getContext("2d");
  let edit = "values", cur = -1, last = null;
  const minInfo = h("span.hint", { title: "the shortest step length a lengths drag sets (dur units): one frame, one fast tick (fast on) or one step of the clock LFO" }, "");
  const W = () => cv.width, H = () => cv.height;
  const lens = () => c.seq.map((_, k) => (c.dur.length ? Math.max(0, +c.dur[k % c.dur.length]) : 1));
  const edges = () => { const L = lens(), tot = L.reduce((a, b) => a + b, 0) || 1; let x = 0;
    return L.map((w) => { const a = x; x += w; return [a / tot * W(), x / tot * W()]; }); };
  const easeAt = (v0, v1, f) => {
    if (c.ease === "step" || c.glide <= 0) return v0;
    let t = (f - (1 - Math.min(1, c.glide))) / Math.min(1, c.glide);
    if (t <= 0) return v0;
    t = Math.min(1, t);
    if (c.ease === "smooth") t = t * t * (3 - 2 * t);
    return v0 + (v1 - v0) * t;
  };
  const draw = () => {
    const ml = minLen(c), sec = c.fast ? 1 / fastHz : 1 / frameHz;
    minInfo.textContent = `shortest ${+ml.toFixed(4)}` + (c.smode === "clock" ? " (1 clock step)" : c.sync >= 0 ? "" :
      ` (${c.fast ? "1 fast tick" : "1 frame"} = ${+(sec * 1000).toFixed(2)} ms)`);
    const w = W(), hh = H(), n = c.seq.length, E = edges(), css = getComputedStyle(document.body);
    g.clearRect(0, 0, w, hh);
    g.fillStyle = css.getPropertyValue("--panel2") || "#222";
    g.fillRect(0, 0, w, hh);
    for (let k = 0; k < n; k++) {
      const [a, b] = E[k], y = (1 - Math.max(0, Math.min(1, c.seq[k]))) * hh;
      g.fillStyle = k === cur ? "rgba(255,154,60,0.95)" : edit === "lengths" ? "rgba(120,170,255,0.7)" : "rgba(255,154,60,0.55)";
      if (b - a > 0) g.fillRect(a + (b - a > 4 ? 1 : 0), y, Math.max(1, b - a - (b - a > 4 ? 1 : 0)), hh - y);
    }
    // the eased curve as debazd plays it
    g.strokeStyle = css.getPropertyValue("--text") || "#fff";
    g.lineWidth = 1.5;
    g.beginPath();
    for (let x = 0; x <= w; x++) {
      let k = E.findIndex(([a, b]) => x >= a && x < b);
      if (k < 0) k = n - 1;
      const [a, b] = E[k], f = b > a ? (x - a) / (b - a) : 0;
      const last1 = c.once && k === n - 1, v = easeAt(c.seq[k], last1 ? c.seq[k] : c.seq[(k + 1) % n], f);
      const y = (1 - Math.max(0, Math.min(1, v))) * hh;
      x ? g.lineTo(x, y) : g.moveTo(x, y);
    }
    g.stroke();
    if (play >= 0 && play < n) {     // playhead (/lfo/<n> -> i:step)
      g.fillStyle = "rgba(255,255,255,0.25)";
      g.fillRect(E[play][0], 0, Math.max(2, E[play][1] - E[play][0]), hh);
    }
  };
  let play = -1;
  const at = (e) => { const r = cv.getBoundingClientRect(); return [(e.clientX - r.left) / r.width * W(), (e.clientY - r.top) / r.height * H()]; };
  const stepAt = (x) => { const E = edges(); const k = E.findIndex(([a, b]) => x >= a && x < b); return k < 0 ? (x <= 0 ? 0 : c.seq.length - 1) : k; };
  const setAt = (x, y) => {
    const k = stepAt(x), v = Math.max(0, Math.min(1, 1 - y / H()));
    if (edit === "values") c.seq[k] = +v.toFixed(4);
    else {                         // lengths: 0..4 steps, own array of seq's length
      if (c.dur.length !== c.seq.length) c.dur = c.seq.map((_, j) => (c.dur.length ? c.dur[j % c.dur.length] : 1));
      c.dur[k] = +Math.max(minLen(c), Math.round(v * 16) / 4).toFixed(4);
    }
    cur = k;
    return k;
  };
  const sendEdit = () => net.throttled(`/lfo/${i}/${edit === "values" ? "seq" : "dur"}`,
    () => (edit === "values" ? net.message(`/lfo/${i}/seq`, fmt(c.seq)) : net.message(`/lfo/${i}/dur`, fmt(c.dur))));
  cv.onpointerdown = (e) => {
    cv.setPointerCapture(e.pointerId);
    const [x, y] = at(e);
    last = [x, y]; setAt(x, y); draw(); sendEdit(); text.value = fmt(edit === "values" ? c.seq : c.dur);
  };
  cv.onpointermove = (e) => {
    if (!last) return;
    const [x, y] = at(e), steps = Math.max(1, Math.ceil(Math.abs(x - last[0]) / 2));
    for (let s2 = 1; s2 <= steps; s2++) setAt(last[0] + (x - last[0]) * s2 / steps, last[1] + (y - last[1]) * s2 / steps);
    last = [x, y]; draw(); sendEdit(); text.value = fmt(edit === "values" ? c.seq : c.dur);
  };
  cv.onpointerup = () => { last = null; cur = -1; draw(); save(); };
  const count = h("input", { type: "number", min: 1, max: 1024, value: c.seq.length, style: "width:5em",
    title: "number of steps (1..1024): new steps repeat the last value",
    onchange: () => {
      const n = Math.max(1, Math.min(1024, count.value | 0));
      while (c.seq.length < n) c.seq.push(c.seq[c.seq.length - 1] ?? 0);
      c.seq.length = n;
      if (c.dur.length) { while (c.dur.length < n) c.dur.push(1); c.dur.length = n; }
      count.value = n; text.value = fmt(edit === "values" ? c.seq : c.dur); draw(); apply(i, ["seq", "dur"]);
    } });
  const text = h("input", { type: "text", value: fmt(c.seq), style: "flex:1;min-width:8em;font-family:var(--mono)",
    title: "the values (or the lengths) as text: paste, Enter = send",
    onchange: () => {
      const a = text.value.split(/[\s,]+/).filter(Boolean).map(Number).filter((v) => !isNaN(v)).slice(0, 1024);
      if (edit === "values") { if (!a.length) return; c.seq = a; count.value = a.length; } else c.dur = a;
      draw(); apply(i, [edit === "values" ? "seq" : "dur"]);
    } });
  const editSel = h("select", { title: "what a drag sets", onchange: () => { edit = editSel.value; text.value = fmt(edit === "values" ? c.seq : c.dur); draw(); } },
    h("option", { value: "values" }, "values"), h("option", { value: "lengths" }, "lengths"));
  const evenBtn = h("button", { title: `all steps the same length\n/lfo/${i}/dur  (no argument)`,
    onclick: () => { c.dur = []; if (edit === "lengths") text.value = ""; draw(); apply(i, ["dur"]); } }, "Even");
  // flip: reverse the sequence here and send it (= play it backwards)
  const flipV = h("input", { type: "checkbox", checked: true, title: "Flip reverses the step values" });
  const flipL = h("input", { type: "checkbox", checked: true, title: "Flip reverses the step lengths" });
  const flipBtn = h("button", { title: `reverse the sequence (= play it backwards): the values and / or the lengths, as ticked\n/lfo/${i}/seq "..."  /lfo/${i}/dur "..."`,
    onclick: () => {
      const keys = [];
      if (flipV.checked && c.seq.length > 1) { c.seq.reverse(); keys.push("seq"); }
      if (flipL.checked && c.dur.length) {     // a short dur list repeats: write it out first
        c.dur = c.seq.map((_, j) => c.dur[j % c.dur.length]).reverse(); keys.push("dur");
      }
      if (!keys.length) return;
      text.value = fmt(edit === "values" ? c.seq : c.dur); draw(); apply(i, keys);
    } }, "Flip");
  const smode = h("select", { title: `/lfo/${i}/step off | frames k | hz f | bpm b [div] | clock k`,
    onchange: () => { c.smode = smode.value; const d = SMODES.find((x) => x[0] === c.smode); if (d[2] !== "") { c.sval = d[2]; sval.value = d[2]; }
      sdivL.hidden = c.smode !== "bpm"; svalL.hidden = c.smode === "off"; alignL.hidden = c.smode !== "clock"; apply(i, ["step"]); onShape(); } },
    SMODES.map(([v, l]) => h("option", { value: v, selected: v === c.smode }, l)));
  const sval = h("input", { type: "number", step: "any", value: c.sval, style: "width:5.5em",
    title: "frames per step / steps per second / BPM / the LFO that clocks this one",
    onchange: () => { c.sval = Number(sval.value); apply(i, ["step"]); } });
  const sdiv = h("input", { type: "number", step: "any", min: 0.25, value: c.sdiv, style: "width:4em",
    title: "steps per beat (4 = 16th notes)", onchange: () => { c.sdiv = Number(sdiv.value) || 1; apply(i, ["step"]); } });
  const svalL = h("label", { hidden: c.smode === "off" }, sval), sdivL = h("label", { hidden: c.smode !== "bpm" }, "÷", sdiv);
  // clock k: step with LFO k, and (align) back to step 0 at its new cycle
  const align = h("input", { type: "checkbox", checked: !!c.align,
    title: `step clock = LFO: back to step 0 when that LFO starts a new cycle (3 steps on 16: 0 1 2 0 1 2 .. 0, lined up); off = free polymeter\n/lfo/${i}/align 0|1`,
    onchange: () => { c.align = align.checked ? 1 : 0; apply(i, ["align"]); } });
  const alignL = h("label", { hidden: c.smode !== "clock" }, align, " align to its cycle");
  const ease = h("select", { title: `/lfo/${i}/ease step|linear|smooth`, onchange: () => { c.ease = ease.value; draw(); apply(i, ["ease"]); } },
    ["step", "linear", "smooth"].map((v) => h("option", { value: v, selected: v === c.ease }, v)));
  const glide = h("input", { type: "range", min: 0, max: 1, step: 0.01, value: c.glide, style: "width:7em",
    title: `the part of each step the ease takes, at its end (0 = jump, 1 = the whole step)\n/lfo/${i}/glide 0..1`,
    oninput: () => { c.glide = Number(glide.value); draw(); net.throttled(`/lfo/${i}/glide`, () => net.message(`/lfo/${i}/glide`, net.float(c.glide))); },
    onchange: save });
  const sec = h("div.lfo-seqsec", { hidden: c.shape !== "step" },
    cv,
    h("div.row", {}, h("label", {}, "edit ", editSel), h("label", {}, "count ", count), evenBtn, flipBtn, h("label", {}, flipV, "flip values"), h("label", {}, flipL, "flip lengths"), minInfo),
    h("div.row", {}, text),
    h("div.row", {}, h("label", {}, "step clock ", smode), svalL, sdivL, alignL),
    h("div.row", {}, h("label", {}, "ease ", ease), h("label", {}, "glide ", glide)));
  // the highlight: board step (slow), own playhead (to POV_HZ), 1 step/s (faster)
  let board = -1, simT0 = 0, simK0 = 0, mode = "real";
  const hl = (k) => { if (k !== play) { play = k; draw(); } };
  const tick = (now) => {
    if (board < 0) { mode = "real"; hl(-1); return false; }
    const T = c.once ? null : cycleSec(i), L = lensOf(c), tot = L.reduce((a, b) => a + b, 0);
    const act = L.map((w, k) => (w > 0 ? k : -1)).filter((k) => k >= 0);
    const hz = T && tot > 0 ? act.length / T : 0;   // steps per second
    const m = !hz || hz <= REAL_HZ ? "real" : hz <= POV_HZ ? "sim" : "run";
    if (m !== mode) { mode = m; simT0 = now; simK0 = Math.max(0, board); }
    if (mode === "real") { hl(board); return true; }
    if (mode === "run") { hl(act[(act.indexOf(simK0) + Math.floor((now - simT0) / 1000)) % act.length] ?? 0); return true; }
    // sim: walk the step lengths from the board's step at the switch
    let t = ((now - simT0) / 1000 / T * tot) % tot, k = simK0;
    for (let g = 0; g < L.length * 2; g++) { if (t < L[k]) break; t -= L[k]; k = (k + 1) % L.length; }
    hl(k);
    return true;
  };
  seqUi[i] = { draw, sec, tick, step: (k) => { board = k; if (mode === "real") hl(k); headStart(); } };
  requestAnimationFrame(draw);
  return sec;
}

function lfoCard(i) {
  const c = cfg[i];
  const num = (key, step, title, sendKey = key) => {
    const osc = { range: "range <min> <max>", min: "min <f>", max: "max <f>", frames: "frames <n>",
      steps: "steps <n>", every: "every <k>", gain: "gain <k>", attack: "attack <s>",
      release: "release <s>" }[sendKey] || `${sendKey} <f>`;
    const el = h("input", { type: "number", step, value: c[key], title: `${title}\n/lfo/${i}/${osc}`,
      onchange: () => { c[key] = Number(el.value); apply(i, [sendKey]); } });
    if (key === "lo") loEl = el;
    if (key === "hi") hiEl = el;
    return h("label", {}, title, el);
  };
  let loEl, hiEl;
  const onBtn = h("button", { title: `/lfo/${i}/on <0|1>  (/lfo/${i} -> value on)`, onclick: () => { c.on = c.on ? 0 : 1; paint(); apply(i, ["on"]); } });
  const paint = () => { onBtn.textContent = c.on ? "On" : "Off"; onBtn.classList.toggle("on", !!c.on); };
  paint();
  const shape = h("select", { title: `/lfo/${i}/shape <name>`, onchange: () => {
      c.shape = shape.value; seqSec.hidden = c.shape !== "step";
      apply(i, c.shape === "step" ? ["seq", "dur", "step", "ease", "glide", "shape"] : ["shape"]); } },
    SHAPES.map((s) => h("option", { value: s, selected: s === c.shape }, s)));
  const feat = h("select", { title: `/lfo/${i}/audio <feature>  (also sets shape audio)`,
    onchange: () => { c.audio = feat.value; c.shape = "audio"; shape.value = "audio"; apply(i, ["audio"]); } },
    FEATURES.map((f) => h("option", { value: f, selected: f === c.audio }, f)));
  const mode = h("select", { title: `/lfo/${i}/mode loop|once`, onchange: () => { c.once = mode.value === "once" ? 1 : 0; apply(i, ["mode"]); } },
    h("option", { value: "loop", selected: !c.once }, "loop"),
    h("option", { value: "once", selected: !!c.once }, "once"));
  const target = h("input", { type: "text", value: c.target, list: "lfo-targets",
    title: `/lfo/${i}/target "<field path>" or "<message with $k / $fk>"`,
    placeholder: "/field/path  or  /message a b $0 $f1" });
  const pslot = h("input", { type: "number", min: 0, max: 11, value: c.pslot ?? 6, style: "width:4em",
    title: "slot (or display, for the crop) the preset uses" });
  const preset = h("select", { title: "a target for a tool that is not a field: sets the target and min / max",
    onchange: () => {
      const pr = PRESETS[+preset.value];
      preset.value = "";
      if (!pr) return;
      c.pslot = +pslot.value;
      c.target = pr[1].replaceAll("<s>", String(c.pslot)).replaceAll("$fv", `$f${i}`).replaceAll("$v", `$${i}`);
      target.value = c.target;
      [c.lo, c.hi] = [pr[2], pr[3]];
      loEl.value = c.lo; hiEl.value = c.hi;
      apply(i, ["range", "target"]);
    } },
    h("option", { value: "" }, "preset…"), PRESETS.map(([n], k) => h("option", { value: k }, n)));
  // every: k frames, at each change, at each step
  const emode = h("select", { title: `/lfo/${i}/every k | change | step\nchange: when the value changes (shape step: once per new step value)\nstep: at each step start (other shapes: each wrap)`,
    onchange: () => { c.emode = emode.value; apply(i, ["every"]); } },
    [["frames", "every n frames"], ["change", "on change"], ["step", "each step"]].map(([v, l]) => h("option", { value: v, selected: v === c.emode }, l)));
  const seqSec = seqSection(i, () => { if (c.smode !== "off") { c.shape = "step"; shape.value = "step"; seqSec.hidden = false; } });
  // phase sync (2026-11-22): this LFO takes another's place in its cycle
  const sync = h("select", { title: `/lfo/${i}/sync <k> [delay frames] | off\nfollow LFO k's cycle (any shape, any step counts) instead of the own rate / step clock`,
    onchange: () => { c.sync = +sync.value; apply(i, ["sync"]); } },
    h("option", { value: -1, selected: c.sync < 0 }, "off"),
    [...Array(N).keys()].filter((k) => k !== i).map((k) => h("option", { value: k, selected: k === c.sync }, `LFO ${k}`)));
  const fast = h("input", { type: "checkbox", checked: !!c.fast,
    title: `fast: run at /lfo/fastrate (default 1000 Hz) instead of once per frame; FIELD targets are written at that rate (mid-frame: tearing bands, ~1 ms jitter); message targets stay per frame. Not for sync / clock followers.\n/lfo/${i}/fast 0|1`,
    onchange: () => { c.fast = fast.checked ? 1 : 0; apply(i, ["fast"]); } });
  const meter = h("div.meter", {}, h("i"));
  const val = h("span.hint", {}, "–");
  meters[i] = { meter, val };
  onBtn.style.marginLeft = "auto";
  // copy another LFO's settings into this card (page only), Update = send them
  const from = h("select", { title: "the LFO to copy the settings from (all but target and on / off)", onchange: () => { lastFrom[i] = +from.value; } },
    [...Array(N).keys()].filter((k) => k !== i).map((k) => h("option", { value: k, selected: k === lastFrom[i] }, `LFO ${k}`)));
  const upd = h("button", { title: `send all of this card's settings to the board (after a copy and tweaks)\n/lfo/${i}/shape, /rate, /range, /seq, /dur, /step, /target ...` });
  const paintUpd = () => { upd.textContent = unsent[i] ? "Update ●" : "Update"; upd.classList.toggle("primary", !!unsent[i]); };
  upd.onclick = () => { apply(i, ALL); unsent[i] = false; paintUpd(); };
  paintUpd();
  updPaint[i] = paintUpd;
  const copyBtn = h("button", { title: "copy the chosen LFO's settings into this card; nothing is sent until Update",
    onclick: () => {
      const k = +from.value, src = cfg[k];
      lastFrom[i] = k;
      for (const key of Object.keys(src)) if (!NOCOPY.has(key))
        cfg[i][key] = Array.isArray(src[key]) ? src[key].slice() : src[key];
      if (cfg[i].sync === i) cfg[i].sync = -1;          // no sync to itself
      unsent[i] = true;
      save();
      rebuild(i);                                       // the inputs hold the old values
    } }, "Copy");
  const el = card([`LFO ${i}`, onBtn],
    meter, val,
    h("div.row", {}, h("label", {}, "copy from ", from), copyBtn, upd),
    h("div.lfo", {},
      h("label", {}, "shape", shape),
      num("rate", "0.01", "rate Hz", "rate"),
      num("frames", "1", "or frames/cycle", "frames"),
      num("lo", "any", "min", "min"),
      num("hi", "any", "max", "max"),
      num("width", "0.05", "width 0..1"),
      num("curve", "0.1", "curve"),
      num("steps", "1", "steps"),
      h("label", {}, "fast", h("span", {}, fast, " sub-frame")),
      h("label", {}, "sync to", sync),
      num("delay", "1", "delay frames (sync / clock)", "delay"),
      h("label", {}, "apply", emode),
      num("every", "1", "every n frames"),
      num("phase", "0.05", "phase 0..1"),
      h("label", {}, "mode", mode),
      h("label", {}, "audio feature", feat),
      num("gain", "0.5", "audio gain (0 = auto)"),
      num("attack", "0.01", "attack s"),
      num("release", "0.01", "release s"),
      h("label", {}, " ", h("button", { title: `/lfo/${i}/trigger`, onclick: () => { c.on = 1; paint(); net.msg(`/lfo/${i}/trigger`); save(); } }, "Trigger")),
      seqSec,
      h("label.target", {}, "target",
        h("div.row", {}, target,
          h("button.primary", { title: `/lfo/${i}/target "<text>"\na bare message address from the list gets this LFO's value: ` +
            `$${i} (int) or $f${i} (float) per argument`,
            onclick: () => { c.target = expandTarget(target.value.trim(), i); target.value = c.target; apply(i, ["target"]); } }, "Set"),
          h("button", { title: `/lfo/${i}/target  (no argument = no target)`, onclick: () => { c.target = ""; target.value = ""; apply(i, ["target"]); } }, "Clear")),
        h("div.row", {}, preset, h("label", {}, "slot ", pslot)))));
  cardEl[i] = el;
  return el;
}
const rebuild = (i) => cardEl[i]?.replaceWith(lfoCard(i));

// ---- the cards from the board (2026-11-23) ----
// Cues, state recalls and resume change LFO settings on the board, so the page
// reads them back (/state "/lfo/") on connect, when the tab is shown, when the
// board's on / off differs from a card, and with "Load from board". Only the
// LFO's own settings: what it writes into its target is not touched. Cards
// with an unsent copy (Update ●) and the card being edited are kept.
const num0 = (v) => { const x = typeof v === "number" ? v : Number(v) || 0; return +x.toPrecision(6); }; // board floats are 32-bit
const listOf = (a) => (a.length === 1 && typeof a[0] === "string" ? a[0].split(/[\s,]+/).filter(Boolean).map(Number) : a.map(num0));
function fromRows(rows) {
  const got = [];
  for (const r of rows) {
    const mm = /^\/lfo\/(\d+)\/(\w+)$/.exec(r[0] || "");
    if (!mm || +mm[1] >= N) continue;
    const i = +mm[1], k = mm[2], a = r.slice(2), o = (got[i] ||= {});
    switch (k) {
      case "seq": if (a.length) o.seq = listOf(a); break;
      case "dur": o.dur = a.length ? listOf(a) : []; break;
      case "step": o.smode = a[0] || "off";
        if (a[0] === "bpm") { o.sval = num0(a[1]); o.sdiv = num0(a[2]) || 1; } else if (a.length > 1) o.sval = num0(a[1]); break;
      case "sync": o.sync = a[0] === "off" || !a.length ? -1 : num0(a[0]); break;
      case "every": if (typeof a[0] === "string") o.emode = a[0]; else { o.emode = "frames"; o.every = num0(a[0]) || 1; } break;
      case "min": o.lo = num0(a[0]); break;
      case "max": o.hi = num0(a[0]); break;
      case "mode": o.once = a[0] === "once" ? 1 : 0; break;
      case "target": o.target = a.length ? String(a[0]) : ""; break;
      case "shape": case "ease": case "audio": o[k] = String(a[0]); break;
      default: if (k in DEF && a.length) o[k] = num0(a[0]);
    }
  }
  return got;
}
function applyRows(rows) {
  const got = fromRows(rows);
  let changed = 0;
  got.forEach((o, i) => {
    if (!o || unsent[i] || !cardEl[i]) return;
    if (cardEl[i].contains(document.activeElement) && document.activeElement !== document.body) return;
    const next = { ...cfg[i], ...o };
    if (JSON.stringify(next) === JSON.stringify(cfg[i])) return;
    cfg[i] = next;
    rebuild(i);
    changed++;
  });
  if (changed) save();
  return changed;
}
let loading = null;
function loadFromBoard() {
  if (loading || !net.connected()) return loading;
  loading = net.collect(net.message("/state", "/lfo/"), "/state/target", "/state/end", 3000)
    .then((rows) => applyRows(rows)).finally(() => { loading = null; });
  return loading;
}

// the fast thread's rate (all fast LFOs share it) and what it reaches
let fastInfo = null;
function fastRow() {
  const hz = h("input", { type: "number", min: 10, max: 4000, step: 10, value: store.get("lfofast", 1000), style: "width:6em",
    title: "/lfo/fastrate <hz> (10..4000): the rate of every fast LFO",
    onchange: () => { store.set("lfofast", +hz.value); net.msg("/lfo/fastrate", net.float(+hz.value)); } });
  fastInfo = h("span.hint", { title: "/lfo/fastrate -> hz measured_hz late_max_ms fast_lfos" }, "");
  return h("label", {}, "fast rate Hz ", hz, " ", fastInfo);
}

function poll() {
  if (!net.connected()) return;
  net.send(net.bundle(net.message("/audio/react"), net.message("/lfo/fastrate"), ...[...Array(N).keys()].map((i) => net.message(`/lfo/${i}`))));
}
let reactUi = null;

// the audio analysis source + a live readout of its features
function audioRow() {
  const src = h("select", { title: "/audio/react/source auto|capture|peak|off\nauto = capture while a sink (an audio LFO, a scope, this meter) asks, off 5 s after; capture = HDMI 2 input via ALSA (all features); " +
      "peak = the PL peak meter (level/peak only, no ALSA)",
    onchange: () => net.msg("/audio/react/source", src.value) },
    ["auto", "off", "capture", "peak"].map((v) => h("option", { value: v }, v)));
  const fft = h("select", { title: "/audio/react/fft 256|512|1024 (bins: 187 / 94 / 47 Hz)",
    onchange: () => net.msg("/audio/react/fft", Number(fft.value)) },
    [1024, 512, 256].map((v) => h("option", { value: v }, `FFT ${v}`)));
  const out = h("span.hint", { title: "/audio/react -> source running level peak bass low mid high air flux beat" }, "–");
  reactUi = { src, out };
  return h("div.row", {}, h("label", {}, "audio source ", src), fft, out);
}

export function init(root) {
  cfg = store.get("lfo", []);
  for (let i = 0; i < N; i++) cfg[i] = { ...DEF, ...(cfg[i] || {}) };
  const list = h("datalist", { id: "lfo-targets" });
  root.append(list,
    h("div.row", {},
      h("button", { title: "/lfo/reset", onclick: () => { net.msg("/lfo/reset"); cfg = cfg.map(() => ({ ...DEF })); save(); root.replaceChildren(); init(root); } }, "Reset all"),
      h("button", { title: "/lfo/<n>/shape, /rate, /range, ... for all 16", onclick: () => cfg.forEach((_, i) => { apply(i, ALL); unsent[i] = false; updPaint[i]?.(); }) }, "Send all settings"),
      h("button", { title: "read every LFO's settings from the board (/state \"/lfo/\"): after a cue, a recall or another page. Cards with an unsent copy (Update ●) are kept",
        onclick: async (e) => { const n = await loadFromBoard(); e.target.textContent = `Load from board (${n ?? 0} changed)`; setTimeout(() => (e.target.textContent = "Load from board"), 2000); } }, "Load from board"),
      fastRow(),
      h("span.hint", {}, "$k = value of LFO k (int), $fk = float. Targets run once per frame (every n).")),
    audioRow(),
    h("div.grid", {}, [...Array(N).keys()].map(lfoCard)));
  for (const ex of EXAMPLES) list.append(h("option", { value: ex }));
  net.on("/audio/react", (m) => {
    if (m.path !== "/audio/react" || !reactUi) return;
    if (document.activeElement !== reactUi.src) reactUi.src.value = m.args[0];
    const status = m.args[11] ?? "";
    reactUi.out.textContent = m.args[1] ? REACT.map((n, k) => `${n} ${Number(m.args[2 + k]).toFixed(2)}`).join(" · ")
      : `${m.args[0]}: ${status || "not running"}`;
    reactUi.out.className = /busy|held|retry|no samples/.test(status) ? "warn-text" : "hint";
  });
  net.on("/lfo/fastrate", (m) => {
    if (m.path !== "/lfo/fastrate" || !fastInfo) return;
    const [, meas, late, n] = m.args;
    if (m.args[0] > 0 && m.args[0] !== fastHz) { fastHz = m.args[0]; seqUi.forEach((u) => u && !u.sec.hidden && u.draw()); }
    fastInfo.textContent = n ? `${n} fast · ${Number(meas).toFixed(0)} Hz · late max ${Number(late).toFixed(2)} ms` : "no fast LFO";
  });
  net.on("/lfo", (m) => {
    const i = parseInt(m.path.split("/")[2]);
    if (!(i >= 0 && i < N) || m.path !== `/lfo/${i}`) return;
    const [v, on, step] = m.args;
    if (step !== undefined && seqUi[i] && !seqUi[i].sec.hidden) seqUi[i].step(on ? step : -1);
    const c = cfg[i];
    if (!!on !== !!c.on && !unsent[i] && performance.now() - (sentAt[i] || 0) > 1500) loadFromBoard(); // a cue / recall changed it
    const span = c.hi - c.lo || 1;
    meters[i].meter.firstChild.style.width = `${Math.max(0, Math.min(1, (v - c.lo) / span)) * 100}%`;
    meters[i].val.textContent = `${on ? "running" : "off"} · ${Number(v).toFixed(3)}`;
  });
}

export function connected() {
  net.ask(net.message("/video/mode"), (m) => m.path === "/video/mode" && typeof m.args[2] === "number", 800)
    .then((m) => { if (m && m.args[2] > 0) { frameHz = m.args[2]; seqUi.forEach((u) => u && u.draw()); } }).catch(() => {});
  // field paths as target suggestions
  const list = document.getElementById("lfo-targets");
  net.collect(net.message("/fields"), "/field", "/field/end").then((fs) => {
    for (const f of fs) if (!f[4]) { fieldPaths.add(f[0]); list.append(h("option", { value: f[0] }, "field")); }
  });
  // every other single-value target debazd tracks (/state: ASCII, crops, movie
  // effects, anim, DDS, LFOs ...): numeric ones only
  net.collect(net.message("/state"), "/state/target", "/state/end", 3000).then((ts) => {
    applyRows(ts);                      // the LFO cards = what the board runs
    for (const t of ts) {
      const addr = t[1], types = (t.tags || "").slice(2);
      if (!addr || fieldPaths.has(addr) || msgTargets.has(addr) || !types || /[^if]/.test(types)) continue;
      msgTargets.set(addr, types);
      list.append(h("option", { value: addr }, `now ${t.slice(2).map((v) => (typeof v === "number" ? +v.toFixed(3) : v)).join(" ")}`));
    }
  });
}

export function show() {
  loadFromBoard();
  clearInterval(timer);
  timer = setInterval(() => {
    if (document.getElementById("tab-lfo").classList.contains("active")) poll();
    else clearInterval(timer);
  }, 250);
}
