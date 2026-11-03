// movfx.js - Media tab cards: datamosh (dzmosh, /movie/<s>/...) and the ASCII picture
// (/ascii/<d>/...). Both act on the Media tab's target slot. The board keeps the
// state; the cards read it back (/movie/<s>/fx, /ascii/<d>/status) when the slot
// changes, so several browsers (and later the cues) agree.
import * as net from "./net.js";
import { h, card, row, hexToRgb } from "./ui.js";
import { VIDEO, AUDIO, openFx, openCustom } from "./fxdialog.js";

const hex = (v) => "#" + (v >>> 0).toString(16).padStart(6, "0").slice(-6);

// ---- datamosh ----

// corrupt slider 0..100 -> probability per byte, square law: fine control near 0
const corruptOf = (v) => ((v / 100) ** 2) * 0.01;
const sliderOf = (p) => Math.round(Math.sqrt(p / 0.01) * 100);

export function moshCard(slot) {
  statsSlot = slot;
  const p = () => `/movie/${slot()}`;
  const st = h("span.hint", {}, "");
  const tog = (label, title, send) => {
    const b = h("button", { title, onclick: () => { b.classList.toggle("on"); send(b.classList.contains("on")); } }, label);
    return b;
  };
  const moshHold = tog("Mosh (hold)", "drop every key frame while on: the new motion moves the old pixels\n/movie/<s>/mosh -1 | 0",
    (on) => net.msg(`${p()}/mosh`, on ? -1 : 0));
  const moshOnce = h("button", { title: "drop only the next key frame (mkmedia files: one each second)\n/movie/<s>/mosh 1",
    onclick: () => net.msg(`${p()}/mosh`, 1) }, "Mosh once");
  const bloomN = h("input", { type: "number", min: 1, max: 600, value: 15, title: "repeats for Bloom\n/movie/<s>/bloom N" });
  const bloom = h("button", { title: "send the next P frame N more times (its motion again and again)\n/movie/<s>/bloom N",
    onclick: () => net.msg(`${p()}/bloom`, parseInt(bloomN.value) || 1) }, "Bloom");
  const smear = tog("Smear (hold)", "repeat the last P frame until off; the movie waits\n/movie/<s>/bloom -1 | 0",
    (on) => net.msg(`${p()}/bloom`, on ? -1 : 0));
  const corrupt = h("input", { type: "range", min: 0, max: 100, value: 0,
    title: "flip bits in the frame data; key frames clean it up\n/movie/<s>/corrupt p (0..1 per byte)" });
  const cval = h("span.hint", {}, "0");
  corrupt.oninput = () => {
    const v = corruptOf(+corrupt.value);
    cval.textContent = v.toPrecision(2);
    net.throttled(`${p()}/corrupt`, () => net.message(`${p()}/corrupt`, net.float(v)));
  };
  const stats = h("span.hint", { title: "/movie/<s>/stats, once per second while this tab is open" }, "");
  const pause = tog("Pause", "hold the picture and the movie's audio\n/movie/<s>/pause 1 | 0",
    (on) => net.msg(`${p()}/pause`, on ? 1 : 0));
  const clear = h("button", { title: "all off\n/movie/<s>/mosh 0, /bloom 0, /corrupt 0, /pause 0 (one bundle)", onclick: () => {
    net.send(net.bundle(net.message(`${p()}/mosh`, 0), net.message(`${p()}/bloom`, 0),
      net.message(`${p()}/corrupt`, net.float(0)), net.message(`${p()}/pause`, 0)));
    for (const b of [moshHold, smear, pause]) b.classList.remove("on");
    corrupt.value = 0; cval.textContent = "0";
  } }, "Clear");

  // frame memory in fbfeed (cheap, live) and ffmpeg filters (restart the movie)
  const memSl = (name, title) => {
    const el = h("input", { type: "range", min: 0, max: 0.99, step: 0.01, value: 0, title });
    const out = h("span.hint", {}, "off");
    el.oninput = () => {
      out.textContent = +el.value ? el.value : "off";
      net.throttled(`${p()}/${name}`, () => net.message(`${p()}/${name}`, net.float(+el.value)));
    };
    return { el, out };
  };
  const trails = memSl("trails", "trails: luma = max(new, old × d), 0 = off (live, cheap)\n/movie/<s>/trails <0..1>");
  const ghost = memSl("ghost", "ghost: frame = old × k + new × (1 − k), 0 = off (live, cheap)\n/movie/<s>/ghost <0..1>");
  const VF = ["", ...Object.keys(VIDEO), "custom"];
  const AF = ["", ...Object.keys(AUDIO), "custom"];
  // a choice opens its parameter dialog (fxdialog.js); Apply sends the chain, Cancel goes back
  const pick = (name, list, title) => {
    const table = name === "vf" ? VIDEO : AUDIO;
    let was = "";
    const sel = h("select", { title, onfocus: () => { was = sel.value; } },
      list.map((v) => h("option", { value: v }, v === "" ? "none" : v === "custom" ? "custom…" : v)));
    const send = (chain) => { net.msg(`${p()}/${name}`, chain); was = sel.value; setTimeout(() => moshRefresh(slot()), 600); };
    const back = () => { sel.value = was; };
    sel.onchange = () => {
      const v = sel.value;
      if (v === "") send("");
      else if (v === "custom") openCustom(name, sel.dataset.chain || "", send, back);
      else openFx(table, v, name, send, back);
    };
    // ⚙: the dialog of the effect that runs now; live options act at once
    const gear = h("button.ghost", { title: `edit the running ${name === "vf" ? "video" : "audio"} effect ` +
      "(● options act live, the others restart the movie)", onclick: () => {
        const v = sel.value;
        if (v === "custom") return openCustom(name, sel.dataset.chain || "", send, () => {});
        if (!v) return;
        openFx(table, v, name, send, () => {}, { chain: sel.dataset.chain || "",
          live: (f, o, val) => net.throttled(`${p()}/${name}/${f}/${o}`, () =>
            net.message(`${p()}/${name}/${f}/${o}`, typeof val === "number" ? net.float(val) : String(val))) });
      } }, "⚙");
    sel.gear = gear;
    return sel;
  };
  const vf = pick("vf", VF, "ffmpeg video filter: a choice opens its parameters; Apply restarts the movie " +
    "(lagfun, tmix, diff, edges: slow)\n/movie/<s>/vf \"<chain>\"  (\"\" = none)");
  const af = pick("af", AF, "ffmpeg filter on the movie's audio: a choice opens its parameters; Apply restarts " +
    "the movie\n/movie/<s>/af \"<chain>\"");

  // which effect a chain is: the sequence of its filter names ("scale,edgedetect" = edges)
  const names = (chain) => chain.split(",").map((x) => x.split("=")[0]).join(",");
  const effectOf = (table, chain) => {
    const n = names(chain);
    for (const [k, fx] of Object.entries(table)) {
      const defaults = Object.fromEntries(fx.params.map((q) => [q.name, q.value]));
      if (names(fx.chain(defaults)) === n) return k;
    }
    return "custom";
  };
  net.on("/movie", (m) => {
    const f = /^\/movie\/(\d+)\/(vf|af)$/.exec(m.path);
    if (f && +f[1] === +slot()) {  // the chain now -> its preset name (or a custom entry)
      const sel = f[2] === "vf" ? vf : af, chain = m.args[0] || "";
      const name = chain ? effectOf(f[2] === "vf" ? VIDEO : AUDIO, chain) : "";
      sel.dataset.chain = chain;     // the custom dialog starts from the chain now
      sel.title = sel.title.split("\nnow: ")[0] + (chain ? `\nnow: ${chain}` : "");
      sel.value = name;
      return;
    }
    const q = /^\/movie\/(\d+)\/stats$/.exec(m.path);
    if (q && +q[1] === +slot()) {
      const [run, fps, ms, , cpu, procs, mosh, , , dropI, bl, flips, late, mfps, queued, cap] = m.args;
      if (!run) { stats.textContent = ""; return; }
      const parts = [fps > 0 ? `${fps.toFixed(1)} fps shown${cap > 0 ? ` (cap ${cap})` : ""}, ${ms.toFixed(1)} ms per frame in fbfeed`
        : "no new frames for 2 s (paused, or the decoder waits)"];
      parts.push(`CPU ${cpu < 0 ? "…" : `${cpu.toFixed(0)} %`}${procs ? ` (${procs})` : ""}`);
      if (mosh) parts.push(`dzmosh ${mfps.toFixed(1)} fps, behind ${late}×, key frames dropped ${dropI}, repeats ${bl}, bit flips ${flips}`);
      if (queued) parts.push(`${queued} live commands waiting`);
      stats.textContent = parts.join(" · ");
      stats.classList.toggle("warn-text", late > 0 && mosh && mfps > 0 && fps > 0 && fps < mfps * 0.9);
      return;
    }
    const r = /^\/movie\/(\d+)\/fx$/.exec(m.path);
    if (!r || +r[1] !== +slot()) return;
    const [run, mosh, bl, co, pa, tr, gh] = m.args;
    if (tr !== undefined) {
      trails.el.value = tr; trails.out.textContent = tr ? tr.toFixed(2) : "off";
      ghost.el.value = gh; ghost.out.textContent = gh ? gh.toFixed(2) : "off";
    }
    moshHold.classList.toggle("on", mosh < 0);
    smear.classList.toggle("on", bl < 0);
    pause.classList.toggle("on", !!pa);
    corrupt.value = sliderOf(co); cval.textContent = co ? co.toPrecision(2) : "0";
    st.textContent = run ? "movie playing" : "no movie in this slot";
  });

  return card("Movie effects (target slot)",
    row(null, moshHold, moshOnce),
    row("bloom", bloomN, bloom, smear),
    row("corrupt", corrupt, cval),
    row(null, pause, clear, st),
    row("load", stats),
    row("trails", trails.el, trails.out),
    row("ghost", ghost.el, ghost.out),
    row("video fx", vf, vf.gear, h("label", {}, "audio fx"), af, af.gear),
    h("p.hint", {}, "Works on MPEG-4 Part 2 movies (what mkmedia makes); start the movie first. " +
      "Other codecs answer with an error."));
}

// the movie's load, once per second while the Media tab is open
let statsSlot = null, asciiRun = false;
setInterval(() => {
  const tab = document.getElementById("tab-media");
  if (statsSlot === null || document.hidden || !tab?.classList.contains("active") || !net.connected()) return;
  const sl = statsSlot();
  net.send(asciiRun ? net.bundle(net.message(`/movie/${sl}/stats`), net.message(`/ascii/${sl}/status`))
    : net.message(`/movie/${sl}/stats`));
}, 1000);

export function moshRefresh(slot) {
  net.send(net.bundle(net.message(`/movie/${slot}/fx`), net.message(`/movie/${slot}/vf`),
    net.message(`/movie/${slot}/af`)));
}

// ---- ASCII ----

export function asciiCard(slot, slotPicker) {
  const p = () => `/ascii/${slot()}`;
  const src = slotPicker();
  src.value = 4; // capture
  src.title = "the picture to draw as text (a movie slot, 4 = capture, ...)\n/ascii/<d>/run <src>, /ascii/<d>/once <src>";
  const mode = h("select", { title: "/ascii/<d>/mode" },
    ["ascii", "shade", "braille", "half", "chars"].map((m) => h("option", { value: m }, m)));
  const cols = h("input", { type: "range", min: 4, max: 320, value: 80, title: "characters per line (cell = width / cols, 2:1)\n/ascii/<d>/cols n" });
  const colsV = h("span.hint", {}, "80");
  const color = h("select", { title: "/ascii/<d>/color 0|1|2" },
    h("option", { value: 0 }, "fg colour"), h("option", { value: 1 }, "cell colour"), h("option", { value: 2 }, "cell colour, bright"));
  const fg = h("input", { type: "color", value: "#ffffff", title: "/ascii/<d>/fg r g b" });
  const bg = h("input", { type: "color", value: "#000000", title: "/ascii/<d>/bg r g b" });
  const level = h("input", { type: "range", min: 0, max: 100, value: 50, title: "braille dot / mono half threshold\n/ascii/<d>/level 0..1" });
  const invert = h("input", { type: "checkbox", title: "dark = dense\n/ascii/<d>/invert 0|1" });
  const every = h("input", { type: "number", min: 1, max: 600, value: 2, title: "draw each k-th frame (2 = 30 fps at 60 Hz)\n/ascii/<d>/every k" });
  const chars = h("input", { type: "text", value: " .:ｦｱｳｴｵｶｷ01Zﾊﾐﾋｰ", style: "flex:1",
    title: "any UTF-8 characters; sorted by ink, so the order does not matter. Put a space in for black.\n/ascii/<d>/chars \"text\" [\"font\"]" });
  const font = h("select", { style: "max-width:14em",
    title: "TrueType font on the board (/usr/share/fonts). A character the font lacks comes from " +
      "DejaVuSans, FreeSerif or DroidSansFallbackFull (sw/tools/pushfonts.sh)\n" +
      "/ascii/<d>/chars \"text\" \"<font>\"  (list: /files fonts)" },
    h("option", { value: "" }, "default font"));
  const st = h("span.hint", { title: "/ascii/<d>/status -> run src cols mode color fg bg level invert every " +
    "chars font ms drawn chars fps" }, "");

  const send = (path, ...a) => net.msg(`${p()}/${path}`, ...a);
  mode.onchange = () => (mode.value === "chars" ? sendChars() : send("mode", mode.value));
  cols.oninput = () => { colsV.textContent = cols.value;
    net.throttled(`${p()}/cols`, () => net.message(`${p()}/cols`, +cols.value)); };
  color.onchange = () => send("color", +color.value);
  fg.oninput = () => send("fg", ...hexToRgb(fg.value));
  bg.oninput = () => send("bg", ...hexToRgb(bg.value));
  level.oninput = () => net.throttled(`${p()}/level`, () => net.message(`${p()}/level`, net.float(level.value / 100)));
  invert.onchange = () => send("invert", invert.checked ? 1 : 0);
  every.onchange = () => send("every", +every.value || 1);
  const sendChars = () => send("chars", chars.value, font.value);
  chars.onchange = sendChars;
  font.onchange = sendChars;

  net.on("/ascii", (m) => {
    const r = /^\/ascii\/(\d+)\/status$/.exec(m.path);
    if (!r || +r[1] !== +slot()) return;
    const [run, s, c, md, col, f, b, lv, inv, ev, ch, fn, ms, drawn, nch, fps] = m.args;
    asciiRun = !!run;
    // the once-per-second poll must not move a control the user holds
    const put = (el, v, prop = "value") => { if (document.activeElement !== el) el[prop] = v; };
    put(src, s); put(cols, c); if (document.activeElement !== cols) colsV.textContent = c;
    put(mode, md); put(color, col); put(fg, hex(f)); put(bg, hex(b)); put(level, Math.round(lv * 100));
    put(invert, !!inv, "checked"); put(every, ev);
    if (document.activeElement !== chars) chars.value = ch;
    if (fn && ![...font.options].some((o) => o.value === fn)) font.append(h("option", { value: fn }, fn));
    if (document.activeElement !== font) font.value = fn;
    const miss = md === "chars" && nch !== undefined && drawn < nch
      ? ` · ${nch - drawn} of ${nch} characters in no font` : "";
    const rate = run && fps !== undefined ? ` · ${fps.toFixed(1)} fps` : "";
    st.textContent = `${run ? "running" : "stopped"} · ${ms.toFixed(1)} ms per frame${rate}${miss}`;
    st.classList.toggle("warn-text", run && ms > 25);
  });

  fontSel = font;
  return card("ASCII (source → target slot)",
    row("source", src, h("button.primary", { title: "/ascii/<d>/run src", onclick: () => send("run", +src.value) }, "Run"),
      h("button", { title: "one frame\n/ascii/<d>/once src", onclick: () => send("once", +src.value) }, "Once"),
      h("button", { title: "/ascii/<d>/stop", onclick: () => send("stop") }, "Stop")),
    row("mode", mode, color),
    row("cols", cols, colsV),
    row("fg / bg", fg, bg, h("label", {}, invert, " invert")),
    row("level", level, h("label", {}, "every"), every),
    row("chars", chars, font),
    row(null, st),
    h("p.hint", {}, "The target slot shows text made from the source slot. Shade, braille and half are drawn " +
      "(no font). Chars draws your characters with the chosen TrueType font; characters it lacks come " +
      "from the fallback fonts, the status line counts any that no font has."));
}

let fontSel = null;
export async function asciiRefresh(slot) {
  if (fontSel) {           // the board's font list (bare names, any subfolder)
    const list = await net.collect(net.message("/files", "fonts"), "/file", "/file/end");
    const keep = fontSel.value;
    fontSel.replaceChildren(h("option", { value: "" }, "default font"),
      ...list.map((a) => a[0]).sort().map((n) => h("option", { value: n }, n.replace(/\.(ttf|otf|ttc)$/i, ""))));
    fontSel.value = keep;
  }
  net.msg(`/ascii/${slot}/status`);
}
