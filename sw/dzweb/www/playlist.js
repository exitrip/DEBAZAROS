// playlist.js - a cue-list generator on the Media tab (2026-11-04). The files
// picked in the lists (in click order) become a sheet of text, one line per
// cue; edit it (order, holds, gaps), then "Save as scene" builds a scene on the
// board without recording: /cue/put + /cue/add (every cue sets all its media
// targets, so keyframe and delta both work), /cue/follow <hold> (auto follow),
// /scene/loop, /show/save. Then edit the scene in the Cues tab (cards over
// the gaps, looks, fades). Durations: /media/info (ffprobe on the board).
//
// Sheet lines:  scene <name>      display 0|1|both   slot <n>    loop
//               movieaudio <n>    (bits 1 HDMI 0, 2 HDMI 1, 4 I2S)
//               audioout <n>      (0 HDMI 0, 1 HDMI 1, 2 I2S)
//               kinds keyframe|delta   (delta: the first is a keyframe anyway)
//               <kind> <hold> [file]   kind = movie | image | audio | black;
//               hold = seconds, or "end" (the movie plays once, the next cue
//               goes at its real end: /movie/<s>/loop 0 + /cue/follow end),
//               "end+2" = 2 s after the end; 0 = no follow (wait for Go /
//               Next); # = a comment
import * as net from "./net.js";
import { h, card, row, store, toast } from "./ui.js";

const st = { scene: "playlist", disp: "0", slot: 6, pause: 2, hold: 5, loop: true, kinds: "delta", untilEnd: true, ...store.get("playlist", {}) };
const keep = () => store.set("playlist", st);
let text, info;

// the sheet from the picked files
async function generate(picked, movieAudio, audioOut) {
  if (!picked.length) return toast("pick files first (the boxes in the lists; shift: a range)", true);
  info.textContent = "reading durations…";
  const lines = [
    `scene ${st.scene}`, `display ${st.disp}`, `slot ${st.slot}`, `movieaudio ${movieAudio}`,
    `audioout ${audioOut}`, `kinds ${st.kinds}`, ...(st.loop ? ["loop"] : []),
    "# kind  hold  file   (kind: movie image audio black; hold: seconds, end, end+2; 0 = wait for Go)"];
  let total = 0;
  for (const [i, p] of picked.entries()) {
    let hold = st.hold;
    if (p.kind !== "img") {
      const r = await net.ask(net.message("/media/info", p.kind, p.name), (m) => m.path === "/media/info" && m.args[1] === p.name, 3000);
      hold = r && r.args[2] > 0 ? Math.floor(r.args[2] * 10) / 10 : 0;
      if (!hold) toast(`${p.name}: no duration (hold 0 = manual)`, true);
    }
    const end = p.kind !== "img" && st.untilEnd;
    lines.push(`${p.kind === "img" ? "image" : p.kind === "movies" ? "movie" : "audio"}  ${end ? "end " : hold.toFixed(1)}  ${p.name}` +
      (end && hold ? `   # ${fmtTime(hold)}` : ""));
    total += hold;
    if (st.pause > 0 && (i < picked.length - 1 || st.loop)) {
      lines.push(`black  ${Number(st.pause).toFixed(1)}`);
      total += Number(st.pause);
    }
  }
  text.value = lines.join("\n") + "\n";
  info.textContent = `${picked.length} files, run time ${fmtTime(total)}${st.loop ? ", then again" : ""}`;
}

const fmtTime = (s) => `${Math.floor(s / 60)}:${String(Math.round(s % 60)).padStart(2, "0")}`;

// the sheet -> { scene, displays, slot, ma, ao, loop, kinds, cues: [{ kind, hold, file }] } or an error text
function parse(src) {
  const o = { scene: "", disp: [0], slot: 6, ma: 0, ao: 0, loop: false, kinds: "delta", cues: [] };
  for (const [ln, raw] of src.split("\n").entries()) {
    const line = raw.replace(/#.*/, "").trim();
    if (!line) continue;
    const [k, v, ...rest] = line.split(/\s+/);
    const where = `line ${ln + 1}`;
    if (k === "scene") o.scene = v || "";
    else if (k === "display") o.disp = v === "both" ? [0, 1] : [Number(v) === 1 ? 1 : 0];
    else if (k === "slot") o.slot = Number(v);
    else if (k === "movieaudio") o.ma = Number(v) & 7;
    else if (k === "audioout") o.ao = Number(v);
    else if (k === "loop") o.loop = true;
    else if (k === "kinds") o.kinds = v === "keyframe" ? "keyframe" : "delta";
    else if (["movie", "image", "audio", "black"].includes(k)) {
      const em = /^end(?:\+(\d+(?:\.\d+)?))?$/.exec(v || "");
      const hold = em ? Number(em[1] || 0) : Number(v);
      if (!(hold >= 0)) return `${where}: hold = seconds, end or end+<s>; got "${v}"`;
      if (em && (k === "image" || k === "black")) return `${where}: ${k} has no end: give seconds`;
      const file = rest.join(" ");
      if (k !== "black" && !file) return `${where}: ${k} needs a file`;
      if (/[^A-Za-z0-9._-]/.test(file)) return `${where}: file names are A-Z a-z 0-9 . _ - only`;
      o.cues.push({ kind: k, hold, end: !!em, file });
    } else return `${where}: unknown "${k}"`;
  }
  if (!/^[A-Za-z0-9._-]{1,40}$/.test(o.scene)) return "scene <name>: A-Z a-z 0-9 . _ - (up to 40)";
  if (!(o.slot >= 0 && o.slot < 12) || o.slot === 4) return "slot 0-11, not 4 (the live input)";
  if (!(o.ao >= 0 && o.ao <= 2)) return "audioout 0, 1 or 2";
  if (!o.cues.length) return "no cue lines";
  return o;
}

// one cue's targets: all media of the slot, the output and the displays, so
// a delta cue never leaves the one before playing
function targets(o, c) {
  const S = o.slot, f = net.float(0);
  const t = [
    // movie cues only: a loop change restarts a playing movie (a gap would restart it just before its stop)
    ...(c.kind === "movie" ? [[`/movie/${S}/loop`, c.end ? 0 : 1]] : []), // 0: plays once, the follow waits for its end
    [`/movie/${S}/file`, c.kind === "movie" ? c.file : "", f, c.kind === "movie" ? o.ma : 0],
    [`/img/${S}/file`, c.kind === "image" ? c.file : ""],
    [`/audio/out/${o.ao}/file`, c.kind === "audio" ? c.file : "", 0],
  ];
  for (const d of o.disp) {
    t.push([`/disp/${d}/source`, "show", S]);
    t.push([`/disp/${d}/blank`, c.kind === "black" || c.kind === "audio" ? 1 : 0]);
  }
  return t;
}

async function save() {
  const o = parse(text.value);
  if (typeof o === "string") return toast(o, true);
  const scenes = await net.collect(net.message("/scene/list"), "/scene", "/scene/end");
  if (scenes.some((a) => a[1] === o.scene)) {
    if (!confirm(`Scene "${o.scene}" exists: replace it (its cues go)?`)) return;
    net.msg("/scene/delete", o.scene);
  }
  o.cues.forEach((c, i) => {
    const n = i + 1, kind = i === 0 || o.kinds === "keyframe" ? "keyframe" : "delta";
    net.msg("/cue/put", o.scene, n, kind, c.file ? `${c.kind} ${c.file}`.slice(0, 47) : c.kind);
    for (const [addr, ...args] of targets(o, c)) net.msg("/cue/add", o.scene, n, addr, ...args);
    if (c.end) net.msg("/cue/follow", o.scene, n, "end", net.float(c.hold));
    else if (c.hold > 0) net.msg("/cue/follow", o.scene, n, net.float(c.hold));
  });
  net.msg("/scene/loop", o.scene, o.loop ? 1 : 0);
  const list = await net.collect(net.message("/cue/list", o.scene), "/cue", "/cue/end", 3000);
  if (list.length !== o.cues.length) return toast(`only ${list.length} of ${o.cues.length} cues arrived: Save again`, true);
  const r = await net.ask(net.message("/show/save"), (m) => m.path === "/show/save" || m.path === "/error", 3000);
  if (r && r.path === "/error") toast(`scene made, show not saved: ${r.args[0]}`, true);
  else toast(`scene "${o.scene}": ${list.length} cues${o.loop ? ", loops" : ""}; show saved. Edit it in the Cues tab.`);
}

export function playlistCard(getPicked, clearPicked, getMovieAudio, getAudioOut) {
  const field = (key, attrs, title) => {
    const el = h("input", { ...attrs, value: st[key], title, onchange: () => { st[key] = attrs.type === "number" ? Number(el.value) : el.value; keep(); } });
    return el;
  };
  const disp = h("select", { title: "the display(s) that show the slot: /disp/<d>/source show <slot>", onchange: () => { st.disp = disp.value; keep(); } },
    [["0", "display 0"], ["1", "display 1"], ["both", "both"]].map(([v, t]) => h("option", { value: v, selected: v === st.disp }, t)));
  const kinds = h("select", { title: "delta: the cues keep the live look (effects); keyframe: each cue = the show baseline + its media", onchange: () => { st.kinds = kinds.value; keep(); } },
    [["delta", "keep the look (delta)"], ["keyframe", "baseline look (keyframes)"]].map(([v, t]) => h("option", { value: v, selected: v === st.kinds }, t)));
  const loop = h("input", { type: "checkbox", checked: st.loop, title: "/scene/loop <scene> 1: after the last cue the first again, for ever", onchange: () => { st.loop = loop.checked; keep(); } });
  text = h("textarea", { rows: 12, spellcheck: false, style: "width:100%;font-family:monospace;font-size:12px",
    placeholder: "Pick files in the lists (the boxes, in play order; shift: a range), then Generate." });
  info = h("span.hint", {}, "");
  const count = h("span.hint", {}, "");
  const upd = () => { const p = getPicked(); count.textContent = p.length ? `${p.length} picked: ${p.map((x) => x.name).join(", ").slice(0, 120)}` : "nothing picked"; };
  setInterval(upd, 500);
  return card("Playlist → scene",
    row("picked", count, h("button", { onclick: () => { clearPicked(); upd(); }, title: "clear the boxes" }, "Clear")),
    row("scene", field("scene", { type: "text", style: "width:10em" }, "the scene name (A-Z a-z 0-9 . _ -)"), h("label", {}, loop, " repeat forever")),
    row("show on", disp, h("span.hint", {}, "slot"), field("slot", { type: "number", min: 0, max: 11, style: "width:4em" }, "the slot the media plays into (not 4)")),
    row("pause", field("pause", { type: "number", min: 0, step: 0.1, style: "width:5em" }, "a black cue of this many seconds between items (0 = none)"),
      h("span.hint", {}, "s · image hold"), field("hold", { type: "number", min: 0, step: 0.1, style: "width:5em" }, "seconds an image stays"), h("span.hint", {}, "s")),
    row("cues", kinds),
    row("movies", h("label", { title: "end: a movie or audio file plays once and the next cue goes at its real end (a slow decode " +
      "plays longer than the file says); off: the hold = the file duration (the movie loops if it runs longer)" },
      (() => { const b = h("input", { type: "checkbox", checked: st.untilEnd, onchange: () => { st.untilEnd = b.checked; keep(); } }); return b; })(),
      " until their real end")),
    row(null, h("button.primary", { onclick: () => generate(getPicked(), getMovieAudio(), getAudioOut()) }, "Generate"), info),
    text,
    row(null, h("button.primary", { title: "/cue/put + /cue/add + /cue/follow per line, /scene/loop, /show/save", onclick: save }, "Save as scene"),
      h("button", { title: "/cue/go <scene> 1", onclick: () => { const o = parse(text.value); if (typeof o !== "string") net.msg("/cue/go", o.scene, 1); else toast(o, true); } }, "Go"),
      h("button", { title: "/cue/stop: the follow stops (the media keeps playing)", onclick: () => net.msg("/cue/stop") }, "Stop follow")),
    h("p.hint", {}, "Hold \"end\": the movie / audio file plays once and the next cue goes at its real end (two movies " +
      "at once decode slower than real time: the picture runs longer than the file; its sound plays in real time). " +
      "Seconds: the next cue goes after that time (the durations come from ffprobe). Each line becomes a cue " +
      "(/cue/follow); hold 0 = wait for Go / Next. Edit the order and the holds here, or later in the Cues tab: " +
      "record a card over a black cue, add looks, fades."));
}
