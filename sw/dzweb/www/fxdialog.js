// fxdialog.js - parameter dialog for the movie filters (/movie/<s>/vf, /af). Each effect
// lists its parameters (range or choice, preset value) and builds its ffmpeg chain; Apply
// sends the chain and debazd restarts the movie with it. live = "filter:option" that ffmpeg
// can change while it runs: in the dialog of the RUNNING effect (⚙), those sliders send
// /movie/<s>/<vf|af>/<filter>/<option> at once, without a restart.
import { h } from "./ui.js";

const R = (name, label, min, max, step, value, live) => ({ name, label, min, max, step, value, live });
const C = (name, label, options, value, live) => ({ name, label, options, value, live });

export const VIDEO = {
  split: { title: "Colour split (chromashift)", speed: "fast", params: [
    R("cbh", "blue-diff x", -64, 64, 1, 12, "chromashift:cbh"), R("cbv", "blue-diff y", -64, 64, 1, 0, "chromashift:cbv"),
    R("crh", "red-diff x", -64, 64, 1, -12, "chromashift:crh"), R("crv", "red-diff y", -64, 64, 1, 0, "chromashift:crv"),
    C("edge", "edge", ["smear", "wrap"], "smear", "chromashift:edge")],
    chain: (p) => `chromashift=cbh=${p.cbh}:cbv=${p.cbv}:crh=${p.crh}:crv=${p.crv}:edge=${p.edge}` },
  invert: { title: "Invert", speed: "fast", params: [], chain: () => "negate" },
  hue: { title: "Hue / saturation", speed: "fast", params: [
    R("h", "hue (degrees)", -180, 180, 1, 90, "hue:h"), R("s", "saturation", 0, 5, 0.1, 2, "hue:s"),
    R("b", "brightness", -5, 5, 0.1, 0, "hue:b")],
    chain: (p) => `hue=h=${p.h}:s=${p.s}:b=${p.b}` },
  swap: { title: "Swap U and V (colour swap)", speed: "fast", params: [], chain: () => "swapuv" },
  mirror: { title: "Mirror", speed: "fast", params: [C("dir", "direction", ["hflip", "vflip", "both"], "hflip")],
    chain: (p) => (p.dir === "both" ? "hflip,vflip" : p.dir) },
  shuffle: { title: "Frame shuffle (random)", speed: "fast", params: [R("frames", "shuffle window (frames)", 2, 32, 1, 8)],
    chain: (p) => `random=frames=${p.frames}` },
  stutter: { title: "Stutter (keep every n-th frame)", speed: "fast", params: [R("step", "n", 2, 12, 1, 3)],
    chain: (p) => `framestep=${p.step}` },
  pixel: { title: "Pixelate", speed: "fast", params: [R("w", "pixels across", 16, 640, 2, 160)],
    chain: (p) => `scale=${p.w}:${Math.max(2, Math.round((p.w * 9) / 32) * 2)}:flags=neighbor` },
  noise: { title: "Noise", speed: "fast", params: [R("alls", "strength", 1, 100, 1, 40),
    C("allf", "type", ["t", "u", "t+u", "p"], "t")],
    chain: (p) => `noise=alls=${p.alls}:allf=${p.allf}` },
  lagfun: { title: "lagfun (ffmpeg trails; slow: use the trails slider)", speed: "slow ~10 fps",
    params: [R("decay", "decay", 0.5, 0.99, 0.01, 0.95, "lagfun:decay")], chain: (p) => `lagfun=decay=${p.decay}` },
  tmix: { title: "tmix (average of frames; slow: use ghost)", speed: "slow ~6 fps",
    params: [R("frames", "frames", 2, 8, 1, 3)], chain: (p) => `tmix=frames=${p.frames}` },
  diff: { title: "Frame blend (tblend)", speed: "slow ~20 fps", params: [
    C("mode", "mode", ["difference", "lighten", "darken", "multiply", "screen", "addition", "xor",
      "grainextract", "negation", "phoenix"], "difference", "tblend:all_mode"),
    R("opacity", "opacity", 0, 1, 0.05, 1, "tblend:all_opacity")],
    chain: (p) => `tblend=all_mode=${p.mode}:all_opacity=${p.opacity}` },
  edges: { title: "Edges (edgedetect)", speed: "slow ~16 fps at 320", params: [
    C("mode", "mode", ["colormix", "wires", "canny"], "colormix"),
    R("low", "low threshold", 0.01, 1, 0.01, 0.1), R("high", "high threshold", 0.01, 1, 0.01, 0.4),
    R("w", "work width", 160, 640, 32, 320)],
    chain: (p) => `scale=${p.w}:${Math.round((p.w * 9) / 32) * 2},edgedetect=mode=${p.mode}:low=${p.low}:high=${p.high}` },
};

export const AUDIO = {
  echo: { title: "Echo", params: [R("in", "input gain", 0.1, 1, 0.05, 0.8), R("out", "output gain", 0.1, 1, 0.05, 0.8),
    R("d1", "delay 1 (ms)", 1, 2000, 1, 250), R("k1", "decay 1", 0, 1, 0.05, 0.5),
    R("d2", "delay 2 (ms, 0 = off)", 0, 2000, 1, 500), R("k2", "decay 2", 0, 1, 0.05, 0.3)],
    chain: (p) => (p.d2 > 0 ? `aecho=${p.in}:${p.out}:${p.d1}|${p.d2}:${p.k1}|${p.k2}` : `aecho=${p.in}:${p.out}:${p.d1}:${p.k1}`) },
  chorus: { title: "Chorus", params: [R("delay", "delay (ms)", 20, 100, 1, 50), R("decay", "decay", 0, 1, 0.05, 0.4),
    R("speed", "speed (Hz)", 0.1, 5, 0.05, 0.25), R("depth", "depth (ms)", 0.5, 10, 0.5, 2)],
    chain: (p) => `chorus=0.6:0.9:${p.delay}:${p.decay}:${p.speed}:${p.depth}` },
  flanger: { title: "Flanger", params: [R("delay", "delay (ms)", 0, 30, 0.5, 5), R("depth", "depth (ms)", 0, 10, 0.5, 5),
    R("regen", "feedback (%)", -95, 95, 1, 0), R("speed", "speed (Hz)", 0.1, 10, 0.1, 0.4), R("width", "mix (%)", 0, 100, 1, 71)],
    chain: (p) => `flanger=delay=${p.delay}:depth=${p.depth}:regen=${p.regen}:speed=${p.speed}:width=${p.width}` },
  phaser: { title: "Phaser", params: [R("speed", "speed (Hz)", 0.1, 2, 0.05, 0.4), R("decay", "decay", 0, 0.99, 0.01, 0.4),
    R("delay", "delay (ms)", 0, 5, 0.1, 3), C("type", "wave", ["t", "s"], "t")],
    chain: (p) => `aphaser=speed=${p.speed}:decay=${p.decay}:delay=${p.delay}:type=${p.type}` },
  tremolo: { title: "Tremolo", params: [R("f", "rate (Hz)", 0.1, 40, 0.1, 6), R("d", "depth", 0, 1, 0.05, 0.8)],
    chain: (p) => `tremolo=f=${p.f}:d=${p.d}` },
  vibrato: { title: "Vibrato", params: [R("f", "rate (Hz)", 0.1, 40, 0.1, 6), R("d", "depth", 0, 1, 0.05, 0.5)],
    chain: (p) => `vibrato=f=${p.f}:d=${p.d}` },
  crush: { title: "Bit crusher", params: [R("bits", "bits", 1, 16, 1, 6, "acrusher:bits"), R("samples", "sample hold", 1, 250, 1, 8, "acrusher:samples"),
    R("mix", "mix", 0, 1, 0.05, 1, "acrusher:mix")],
    chain: (p) => `acrusher=bits=${p.bits}:samples=${p.samples}:mix=${p.mix}` },
  lowpass: { title: "Low pass", params: [R("f", "cutoff (Hz)", 50, 12000, 10, 600, "lowpass:f")], chain: (p) => `lowpass=f=${p.f}` },
  highpass: { title: "High pass", params: [R("f", "cutoff (Hz)", 50, 12000, 10, 1500, "highpass:f")], chain: (p) => `highpass=f=${p.f}` },
  radio: { title: "Radio", params: [R("lo", "low cut (Hz)", 100, 1000, 10, 400, "highpass:f"), R("hi", "high cut (Hz)", 1500, 8000, 50, 3000, "lowpass:f"),
    R("bits", "bits", 4, 16, 1, 10, "acrusher:bits")],
    chain: (p) => `highpass=f=${p.lo},lowpass=f=${p.hi},acrusher=bits=${p.bits}:mix=0.5` },
};

// the last values per effect (this browser), so a second open starts where you left
const memo = {};
let dlg = null;

// open the dialog for effect `name` of `table`; onApply(chain) is called with the chain
// the value of filter:option in chain ("hue=h=45:s=2" -> hue:h = 45), or undefined
function fromChain(chain, live) {
  const [f, o] = live.split(":");
  const seg = (chain || "").split(",").find((x) => x === f || x.startsWith(f + "="));
  const m = seg && new RegExp(`(?:^|[=:])${o}=([^:]+)`).exec(seg.slice(f.length));
  return m ? m[1] : undefined;
}

// opts.live(filter, option, value): the effect runs now -> live sliders send at once;
// opts.chain: its chain now (the sliders start from it)
export function openFx(table, name, kind, onApply, onCancel, opts = {}) {
  const fx = table[name];
  if (!fx) return;
  if (!fx.params.length) { if (!opts.live) onApply(fx.chain({})); return; }
  const key = `${kind}.${name}`;
  const vals = { ...Object.fromEntries(fx.params.map((p) => [p.name, p.value])), ...(memo[key] || {}) };
  for (const p of fx.params) {
    const v = p.live && opts.chain !== undefined ? fromChain(opts.chain, p.live) : undefined;
    if (v !== undefined) vals[p.name] = p.options ? v : Number(v);
  }
  const live = (p) => { if (opts.live && p.live) { const [f, o] = p.live.split(":"); opts.live(f, o, vals[p.name]); } };
  const chainOut = h("code.fxchain", {}, "");
  const show = () => { chainOut.textContent = fx.chain(vals); };
  const rows = fx.params.map((p) => {
    const tip = p.live ? `live: /movie/<s>/${kind}/${p.live.replace(":", "/")} <value>` +
      (opts.live ? " (acts now)" : " (in the ⚙ dialog of the running effect)") : "needs Apply (restart)";
    const mark = opts.live && p.live ? " ●" : "";
    if (p.options) {
      const sel = h("select", { title: tip, onchange: () => { vals[p.name] = sel.value; show(); live(p); } },
        p.options.map((o) => h("option", { value: o, selected: o === vals[p.name] }, o)));
      return h("label.fxrow", {}, h("span", {}, p.label + mark), sel);
    }
    const out = h("span.hint", {}, String(vals[p.name]));
    const rng = h("input", { type: "range", min: p.min, max: p.max, step: p.step, value: vals[p.name], title: tip,
      oninput: () => { vals[p.name] = Number(rng.value); out.textContent = rng.value; show(); live(p); } });
    return h("label.fxrow", {}, h("span", {}, p.label + mark), rng, out);
  });
  show();
  if (dlg) dlg.remove();
  const close = (apply) => {
    memo[key] = { ...vals };
    dlg.close();
    dlg.remove();
    dlg = null;
    if (apply) onApply(fx.chain(vals));
    else onCancel?.();
  };
  dlg = h("dialog.fxdlg", { onclose: () => dlg && close(false) },
    h("h2", {}, fx.title),
    fx.speed ? h("p.hint", {}, `speed on the board: ${fx.speed}`) : null,
    opts.live && fx.params.some((p) => p.live)
      ? h("p.hint", {}, "● = live: acts at once. The others need Apply (the movie starts again).") : null,
    ...rows,
    h("p.hint", {}, "ffmpeg chain: ", chainOut),
    h("div.row", {},
      h("button.primary", { onclick: () => close(true), title: `/movie/<s>/${kind} "<chain>" (the movie starts again)` },
        "Apply (restarts the movie)"),
      h("button", { onclick: () => close(false) }, opts.live ? "Close" : "Cancel")));
  document.body.append(dlg);
  dlg.showModal();
}

// "Custom…": any chain (debazd checks it)
export function openCustom(kind, current, onApply, onCancel) {
  if (dlg) dlg.remove();
  const txt = h("input", { type: "text", value: current || "", style: "width:100%",
    placeholder: kind === "vf" ? "hue=h=45,negate" : "aecho=0.8:0.8:300:0.4,lowpass=f=2000",
    title: "letters, digits and = : . , _ + - * / ( ) | only; no filters that open files" });
  const close = (apply) => { dlg.close(); dlg.remove(); dlg = null; apply ? onApply(txt.value.trim()) : onCancel?.(); };
  dlg = h("dialog.fxdlg", { onclose: () => dlg && close(false) },
    h("h2", {}, kind === "vf" ? "Custom video filter chain" : "Custom audio filter chain"),
    txt,
    h("p.hint", {}, "Any ffmpeg filters of the board's build, comma separated. Empty = no filter."),
    h("div.row", {},
      h("button.primary", { onclick: () => close(true), title: `/movie/<s>/${kind} "<chain>"` }, "Apply (restarts the movie)"),
      h("button", { onclick: () => close(false) }, "Cancel")));
  document.body.append(dlg);
  dlg.showModal();
  txt.focus();
}
