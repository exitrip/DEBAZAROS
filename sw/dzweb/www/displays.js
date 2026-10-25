// displays.js - what each display shows: slots, blank, live input, sequences.
import * as net from "./net.js";
import { h, card, row, toast } from "./ui.js";

const SLOTS = 12;
const NAMES = { 0: "fb0", 2: "disp1", 4: "input", 11: "black" };
const state = [
  { slot: -1, blank: 0, seq: 0, el: null },
  { slot: -1, blank: 0, seq: 0, el: null },
];
let usable = SLOTS;

function render(d) {
  const s = state[d];
  const e = s.el;
  e.chip.textContent = s.seq ? "sequence" : s.blank ? "black" : s.slot >= 0 ? `slot ${s.slot}` : "–";
  e.chip.className = "chip " + (s.seq ? "warn" : s.blank ? "" : "ok");
  e.blank.textContent = s.blank ? "Unblank" : "Blank";
  e.blank.classList.toggle("on", !!s.blank);
  e.slots.forEach((b, i) => {
    b.classList.toggle("cur", i === s.slot && !s.blank && !s.seq);
    b.disabled = i >= usable;
  });
}

function parseSeq(text) {
  return text
    .split(/[\s,]+/)
    .filter(Boolean)
    .map((t) => (t === "b" || t === "black" ? -1 : parseInt(t)))
    .filter((n) => Number.isInteger(n) && n >= -1 && n < SLOTS);
}

function displayCard(d) {
  const s = state[d];
  const chip = h("span.chip", {}, "–");
  const slots = [...Array(SLOTS).keys()].map((i) =>
    h("button", { onclick: () => net.msg(`/disp/${d}/show`, i), title: `show slot ${i}` },
      String(i), h("small", {}, NAMES[i] || "")),
  );
  const blank = h("button", { onclick: () => net.msg(`/disp/${d}/blank`) }, "Blank");
  const seqIn = h("input", { type: "text", value: d ? "6 7 8 9 10" : "0 b", size: 16,
    title: "slots; b or -1 = black" });
  const rate = h("input", { type: "number", min: 1, max: 600, value: 6, title: "frames per step" });
  s.el = { chip, slots, blank };
  return card([`Display ${d}`, chip],
    h("div.slots", {}, slots),
    row(null,
      h("button", { onclick: () => net.msg(`/disp/${d}/home`) }, "Home"),
      h("button", { onclick: () => net.msg(`/disp/${d}/capture`) }, "Live input"),
      blank),
    h("h3", {}, "Sequence"),
    row("slots", seqIn),
    row("frames/step", rate,
      h("button.primary", {
        onclick: () => {
          const seq = parseSeq(seqIn.value);
          const r = Math.max(1, parseInt(rate.value) || 1);
          if (!seq.length) return toast("no valid slots", true);
          if (seq.includes(-1) && r <= 4 &&
              !confirm(`Strobe: black every ${r} frame(s) flashes at ${(60 / r / 2).toFixed(1)} Hz. ` +
                       "Fast flashing can trigger seizures. Start?")) return;
          net.send(net.bundle(net.message(`/disp/${d}/seq/rate`, r), net.message(`/disp/${d}/seq`, ...seq)));
        },
      }, "Start"),
      h("button", { onclick: () => net.msg(`/disp/${d}/seq/stop`) }, "Stop")),
    h("p.hint", {}, "One step per n frames at 60 Hz. b or -1 = black."),
  );
}

export function init(root) {
  root.append(h("div.grid", {}, displayCard(0), displayCard(1),
    card("Both displays",
      row(null,
        h("button", { onclick: () => [0, 1].forEach((d) => net.msg(`/disp/${d}/blank`, 1)) }, "Blank both"),
        h("button", { onclick: () => [0, 1].forEach((d) => net.msg(`/disp/${d}/blank`, 0)) }, "Unblank both"),
        h("button", { onclick: () => [0, 1].forEach((d) => net.msg(`/disp/${d}/seq/stop`)) }, "Stop sequences")),
      h("p.hint", {}, "Slots 0–11 are frame buffers. Slot 0 is /dev/fb0 (ffmpeg), 4 is the HDMI input, " +
        "11 is always black. Draw into a slot (Paint, Media), then show it."))));
  for (const d of [0, 1]) {
    net.on(`/disp/${d}`, (m) => {
      if (m.path !== `/disp/${d}`) return;
      [state[d].slot, state[d].blank, state[d].seq] = m.args;
      render(d);
    });
  }
  net.on("/info", (m) => {
    usable = m.args[3] ?? SLOTS;
    render(0);
    render(1);
  });
}

export function connected() {
  net.msg("/info");
  net.msg("/disp/0");
  net.msg("/disp/1");
}

export function show() {
  connected();
}
