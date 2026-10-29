// audio.js - audio routing, file playback, recording and input levels
// (debazd sound.c + the ALSA card DEBAZ). Files: the Media tab's "Audio" list.
import * as net from "./net.js";
import { h, card, row, toast } from "./ui.js";

const OUTS = [
  { name: "HDMI 0", sources: ["auto", "linux", "input", "i2s", "tone", "off"] },
  { name: "HDMI 1", sources: ["auto", "linux", "input", "i2s", "tone", "off"] },
  { name: "I2S out", sources: ["auto", "linux", "input", "off"] },
];
const SOURCE_HELP = {
  auto: "Linux audio while something plays on this output, else the HDMI 2 input",
  linux: "only audio played by the board (files, movies)",
  input: "the audio of the HDMI 2 input",
  i2s: "the I2S input (user I/O pins)",
  tone: "the test tone",
  off: "no audio",
};
let timer, files = [], outEls = [], fileSel, outSel, loopBox, recName, recSecs, recState, meters;

function setSource(n, src) {
  net.msg(`/audio/out/${n}/source`, src);
}

async function loadFiles() {
  const r = await net.collect(net.message("/files", "audio"), "/file", "/file/end").catch(() => []);
  files = r.map((a) => a[0]).sort();
  fileSel.replaceChildren(...(files.length ? files.map((f) => h("option", { value: f }, f))
    : [h("option", { value: "" }, "no files in /media/debaz/audio")]));
}

function poll() {
  net.msg("/audio/status");
  net.msg("/audio/rx/peak/l");
  net.msg("/audio/rx/peak/r");
  net.msg("/audio/rx/active");
  net.msg("/audio/rx/clear", 1);
}

function outCard(n) {
  const sel = h("select", { title: "what this output plays",
    onchange: () => setSource(n, sel.value) },
    h("option", { value: "?" }, "(not set)"),
    ...OUTS[n].sources.map((s) => h("option", { value: s, title: SOURCE_HELP[s] }, s)));
  const now = h("span.hint", {}, "");
  const stop = h("button", { onclick: () => net.msg("/audio/stop", n) }, "Stop");
  outEls[n] = { sel, now };
  return card(OUTS[n].name, row("source", sel), row("playing", now, stop),
    h("p.hint", {}, n < 2 ? "Any source but off switches the output to HDMI mode with audio."
                          : "I2S needs the user I/O pins set to bclk/lrclk/dout (Effects → /io)."));
}

function meter() {
  const bar = h("i");
  return { el: h("div.meter", {}, bar), bar };
}

export function init(root) {
  fileSel = h("select");
  outSel = h("select", {}, OUTS.map((o, i) => h("option", { value: i }, o.name)));
  loopBox = h("input", { type: "checkbox" });
  recName = h("input", { type: "text", value: "capture", title: "file name (.wav is added)" });
  recSecs = h("input", { type: "number", min: 0, max: 3600, value: 0, title: "seconds, 0 = until stop" });
  recState = h("span.hint", {}, "");
  meters = { l: meter(), r: meter(), state: h("span.hint", {}, "") };

  root.append(h("div.grid", {},
    outCard(0), outCard(1), outCard(2),
    card("Play a file",
      row("file", fileSel, h("button", { onclick: loadFiles }, "↻")),
      row("output", outSel, h("label", {}, loopBox, " loop")),
      row(null,
        h("button.primary", { onclick: () => {
          if (!fileSel.value) return toast("no file", true);
          net.msg("/audio/play", parseInt(outSel.value), fileSel.value, loopBox.checked ? 1 : 0);
        } }, "Play"),
        h("button", { onclick: () => net.msg("/audio/stop") }, "Stop all")),
      h("p.hint", {}, "Upload files in the Media tab (Audio). ffmpeg plays wav, mp3, flac, ogg, " +
        "and the audio of movie files. Movies can also play their own audio: Media → Movies.")),
    card("Record the HDMI 2 input",
      row("name", recName, h("label", {}, "s"), recSecs),
      row(null,
        h("button.danger", { onclick: () => net.msg("/audio/rec", recName.value, parseFloat(recSecs.value) || 0) }, "● Record"),
        h("button", { onclick: () => net.msg("/audio/rec/stop") }, "Stop"), recState),
      h("p.hint", {}, "48 kHz 16 bit stereo WAV into /media/debaz/audio (11 MB per minute).")),
    card("HDMI 2 input level",
      row("left", meters.l.el), row("right", meters.r.el), row(null, meters.state))));

  net.on("/audio/out", (m) => {
    if (m.path !== "/audio/out") return;
    const [n, file, loop, src] = m.args;
    if (!outEls[n]) return;
    outEls[n].now.textContent = file ? file + (loop ? " (loop)" : "") : "—";
    if (src && document.activeElement !== outEls[n].sel) outEls[n].sel.value = src;
  });
  net.on("/audio/rec", (m) => {
    if (m.path !== "/audio/rec") return;
    const [file, secs] = m.args;
    recState.textContent = file ? `recording ${file}: ${secs.toFixed(0)} s` : "";
  });
  net.on("/value", (m) => {
    const [path, raw] = m.args;
    if (path === "/audio/rx/peak/l") meters.l.bar.style.width = `${(100 * raw) / 32768}%`;
    else if (path === "/audio/rx/peak/r") meters.r.bar.style.width = `${(100 * raw) / 32768}%`;
    else if (path === "/audio/rx/active") meters.state.textContent = raw ? "audio arrives" : "no audio on the input";
  });
  net.on("/ok", (m) => {
    if (m.args[0] === "/audio/play") toast(`playing ${m.args[2]} on ${OUTS[m.args[1]].name}`);
    if (m.args[0] === "/audio/rec") toast(`recording ${m.args[1]}`);
    if (m.args[0] === "/audio/rec/stop") { toast(`saved ${m.args[1]}`); loadFiles(); }
  });
}

export function connected() {
  loadFiles();
}

export function show() {
  loadFiles();
  clearInterval(timer);
  timer = setInterval(() => {
    if (document.getElementById("tab-audio").classList.contains("active")) poll();
    else clearInterval(timer);
  }, 250);
}
