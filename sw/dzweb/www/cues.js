// cues.js - the Cues tab: shows, scenes, cues and looks of debazd (sw/debazd/cue.c). OSC only:
// the same commands work from any OSC client. A show is a folder on the board
// (/data/shows/<show>/: show.json, baseline.json, looks/*.json) that can be edited by hand;
// "Check" finds what a hand edit broke, "Reload" reads it after an edit.
import * as net from "./net.js";
import { h, card, row, toast, store } from "./ui.js";

let root, showSel, sceneSel, loopBox, statusEl, checkEl, cueBody, lookBody, inspTitle, inspPre, overSecs, overMode;
let scene = store.get("cues.scene", "");
let cues = [];
let timer = 0;

const fmt = (n) => String(Number(Number(n).toFixed(3)));
const sc = () => sceneSel.value;
const send = (path, ...a) => net.msg(path, ...a);
const later = (fn, ms = 250) => setTimeout(fn, ms);

// the override of the transition for go / next / back (empty = the cue's own)
function overrides() {
  const a = [];
  if (overSecs.value !== "") a.push(net.float(Number(overSecs.value)));
  if (overMode.value) a.push(overMode.value);
  return a;
}

async function loadShows() {
  const list = await net.collect(net.message("/show/list"), "/show", "/show/end");
  const keep = showSel.value;
  showSel.replaceChildren(...list.map((a) => h("option", { value: a[0] }, a[0])));
  if (keep) showSel.value = keep;
}

async function loadScenes() {
  const list = await net.collect(net.message("/scene/list"), "/scene", "/scene/end");
  sceneSel.replaceChildren(...list.map((a) => h("option", { value: a[1] }, `${a[1]} (${a[2]})${a[3] ? " ⟳" : ""}`)));
  if (list.some((a) => a[1] === scene)) sceneSel.value = scene;
  scene = sceneSel.value;
  loopBox.checked = !!list.find((a) => a[1] === scene)?.[3];
  loadCues();
}

async function loadCues() {
  if (!sc()) { cueBody.replaceChildren(); cues = []; return; }
  cues = await net.collect(net.message("/cue/list", sc()), "/cue", "/cue/end");
  cueBody.replaceChildren(...cues.map(cueRow));
}

function cueRow([num, name, kind, nset, fade, curve, mode, looks, follow, fend]) {
  const n = net.float(num);
  const nameIn = h("input", { type: "text", value: name, style: "width:9em",
    title: `/cue/name <scene> ${fmt(num)} "<name>"`, onchange: () => send("/cue/name", sc(), n, nameIn.value) });
  const fadeIn = h("input", { type: "number", min: 0, max: 600, step: 0.1, value: fade, style: "width:5em",
    title: "fade seconds" });
  const curveSel = h("select", { title: "curve" }, ["linear", "smooth"].map((c) => h("option", { value: c, selected: c === curve }, c)));
  const modeSel = h("select", { title: "transition" }, ["cut", "fade", "dip"].map((c) => h("option", { value: c, selected: c === mode }, c)));
  const setFade = () => { send("/cue/fade", sc(), n, net.float(Number(fadeIn.value) || 0), curveSel.value, modeSel.value); later(loadCues); };
  fadeIn.onchange = curveSel.onchange = modeSel.onchange = setFade;
  [fadeIn, curveSel, modeSel].forEach((e) => (e.title += `\n/cue/fade <scene> ${fmt(num)} <secs> <curve> <cut|fade|dip>`));
  const folIn = h("input", { type: "text", value: fend ? `end${follow ? "+" + fmt(follow) : ""}` : follow ? fmt(follow) : "",
    placeholder: "manual", style: "width:5.5em",
    title: "auto follow: seconds after this cue's go, the next cue goes by itself; end = when the movie / audio file of " +
      "this cue ends (play once: /movie/<s>/loop 0), end+2 = 2 s after it; empty / 0 = wait for GO\n" +
      `/cue/follow <scene> ${fmt(num)} <secs> | end [secs] | off`,
    onchange: () => {
      const v = folIn.value.trim(), em = /^end(?:\s*\+?\s*(\d+(?:\.\d+)?))?$/.exec(v);
      if (em) send("/cue/follow", sc(), n, "end", net.float(Number(em[1] || 0)));
      else send("/cue/follow", sc(), n, net.float(Number(v) || 0));
      later(loadCues);
    } });
  const lookChips = (looks ? looks.split(",") : []).map((lk) => h("span.chip", { title: `remove: /cue/look <scene> ${fmt(num)} remove ${lk}`,
    style: "cursor:pointer", onclick: () => { send("/cue/look", sc(), n, "remove", lk); later(loadCues); } }, `${lk} ✕`));
  return h("tr", {},
    h("td", {}, h("b", {}, fmt(num))),
    h("td", {}, nameIn),
    h("td", { title: kind === "keyframe" ? "keyframe: baseline + looks + its own targets" : "delta: the cue before + looks + its own targets" }, kind),
    h("td", {}, ...lookChips),
    h("td", { title: "its own targets (the differences it stores)" }, String(nset)),
    h("td", {}, fadeIn, curveSel, modeSel),
    h("td", {}, folIn),
    h("td", {},
      h("button.primary", { title: `/cue/go <scene> ${fmt(num)} [override]`, onclick: () => { send("/cue/go", sc(), n, ...overrides()); later(status); } }, "Go"),
      h("button", { title: `record the state now into this cue (its own targets only; looks stay)\n/cue/record <scene> ${fmt(num)} ${kind}`,
        onclick: () => { if (confirm(`Re-record cue ${fmt(num)} (${kind}) from the state now?`)) { send("/cue/record", sc(), n, kind); later(loadCues); } } }, "Rec"),
      h("button", { title: "its own targets / the resolved state", onclick: () => inspect("/cue/get", `cue ${fmt(num)}: own targets`, "/cue/target", "/cue/end", sc(), n) }, "Own"),
      h("button", { title: "the whole state this cue resolves to", onclick: () => inspect("/cue/resolve", `cue ${fmt(num)}: resolved`, "/cue/target", "/cue/end", sc(), n) }, "All"),
      h("button.danger", { title: `/cue/delete <scene> ${fmt(num)}`, onclick: () => { if (confirm(`Delete cue ${fmt(num)}?`)) { send("/cue/delete", sc(), n); later(loadCues); } } }, "✕")));
}

async function loadLooks() {
  const list = await net.collect(net.message("/look/list"), "/look", "/look/end");
  lookBody.replaceChildren(...list.map(([name, nt, uses]) => h("tr", {},
    h("td", {}, h("b", {}, name)),
    h("td", { title: "targets" }, String(nt)),
    h("td", { title: "cues that use it" }, String(uses)),
    h("td", {},
      h("button", { title: `/look/apply ${name} [override]`, onclick: () => send("/look/apply", name, ...overrides()) }, "Apply"),
      h("button", { title: `its targets take their values now\n/look/update ${name}`, onclick: () => { send("/look/update", name); later(loadLooks); } }, "Update"),
      h("button", { title: `add it to a cue of this scene\n/cue/look <scene> <num> add ${name}`, onclick: () => {
        const v = prompt(`Add look "${name}" to which cue of ${sc()}?`, cues.length ? fmt(cues[0][0]) : "1");
        if (v) { send("/cue/look", sc(), net.float(Number(v)), "add", name); later(() => { loadCues(); loadLooks(); }); }
      } }, "→ cue"),
      h("button", { title: `/look/get ${name}  -> /look/target ... /look/end`, onclick: () => inspect("/look/get", `look ${name}`, "/look/target", "/look/end", name) }, "View"),
      h("button.danger", { title: `/look/delete ${name} [force]`, onclick: () => {
        if (confirm(uses ? `"${name}" is used by ${uses} cue(s). Delete anyway?` : `Delete look "${name}"?`)) {
          send("/look/delete", name, ...(uses ? ["force"] : [])); later(() => { loadLooks(); loadCues(); });
        }
      } }, "✕")))));
}

// a target list in the inspector: one OSC line each (what you could send yourself)
async function inspect(path, title, item, end, ...args) {
  const list = await net.collect(net.message(path, ...args), item, end, 3000);
  inspTitle.textContent = `${title} - ${list.length} targets`;
  inspPre.textContent = list.map(([, addr, ...v]) => [addr, ...v.map((x) => (typeof x === "string" ? JSON.stringify(x) :
    Number.isInteger(x) ? String(x) : fmt(x)))].join(" ")).join("\n");
}

function status() {
  send("/cue/status");
}

async function check() {
  const list = await net.collect(net.message("/show/check"), "/show/issue", "/show/check/end", 4000);
  checkEl.replaceChildren(list.length ? h("ul", {}, list.map(([where, what]) => h("li", {}, h("b", {}, where), ": ", what)))
    : h("span.hint", {}, "no issues"));
}

function refreshAll() {
  loadShows();
  loadScenes();
  loadLooks();
  status();
}

export function init(el) {
  root = el;
  showSel = h("select", { title: "shows on the board (/show/list)" });
  sceneSel = h("select", { title: "scene", onchange: () => { scene = sceneSel.value; store.set("cues.scene", scene); loadScenes(); } });
  loopBox = h("input", { type: "checkbox", title: "repeat: after the last cue the first again (a follow, and GO)\n/scene/loop <scene> 1|0",
    onchange: () => { if (sc()) { send("/scene/loop", sc(), loopBox.checked ? 1 : 0); later(loadScenes); } } });
  statusEl = h("div.cuestat", {}, "–");
  checkEl = h("div", {});
  cueBody = h("tbody");
  lookBody = h("tbody");
  inspTitle = h("h3", {}, "Inspector");
  inspPre = h("pre.insp", {}, "Own / All / View show the targets here: one OSC message per line.");
  overSecs = h("input", { type: "number", min: 0, max: 600, step: 0.1, placeholder: "cue's", style: "width:5em",
    title: "fade seconds for Go / Back / Apply (empty = the cue's own)" });
  overMode = h("select", { title: "transition for Go / Back / Apply" },
    h("option", { value: "" }, "cue's"), ...["cut", "fade", "dip"].map((m) => h("option", { value: m }, m)));
  const newName = h("input", { type: "text", placeholder: "new show", style: "width:9em", title: "/show/new <name>" });
  const recNum = h("input", { type: "number", min: 0.001, step: 0.5, value: 1, style: "width:5em", title: "cue number (1, 2.5, ...)\n/cue/record <scene> <n> keyframe|delta [name]" });
  const recKind = h("select", { title: "/cue/record <scene> <n> keyframe|delta [name]\nkeyframe = all targets, delta = what changed" }, h("option", { value: "keyframe" }, "keyframe"), h("option", { value: "delta" }, "delta"));
  const recName = h("input", { type: "text", placeholder: "name", style: "width:9em", title: "/cue/record <scene> <n> keyframe|delta [name]" });
  const sceneName = h("input", { type: "text", placeholder: "scene name", style: "width:8em", title: "/scene/add <name>, /scene/rename <scene> <name>" });
  const lookName = h("input", { type: "text", placeholder: "look name", style: "width:9em", title: "/look/save <name>" });

  root.append(h("div.grid", {},
    card("Show",
      row(null, showSel,
        h("button", { title: "/show/load <name>", onclick: () => { send("/show/load", showSel.value); later(refreshAll, 400); } }, "Load"),
        h("button", { title: "/show/save (refuses if a file changed on disk since: then Reload, or Save force)",
          onclick: () => { send("/show/save"); later(loadShows); } }, "Save"),
        h("button", { title: "read the files again after a hand edit\n/show/reload", onclick: () => { send("/show/reload"); later(refreshAll, 400); } }, "Reload")),
      row(null, newName, h("button", { title: "/show/new <name> (an empty show; save to make the folder)",
        onclick: () => { if (newName.value) { send("/show/new", newName.value); later(refreshAll, 300); } } }, "New"),
        h("button", { title: "the state now as the baseline: every keyframe = baseline + looks + its own targets\n/show/baseline",
          onclick: () => { if (confirm("Take the state now as the baseline? (keyframes are stored as differences from it)")) send("/show/baseline"); } }, "Baseline"),
        h("button", { title: "/show/check: unknown addresses, argument types, missing files and looks", onclick: check }, "Check"),
        h("button", { title: "Save over files that changed on disk\n/show/save force", onclick: () => {
          if (confirm("Overwrite the files on disk, also hand edits made since loading?")) send("/show/save", "force"); } }, "Save force")),
      checkEl,
      h("p.hint", {}, "Files: /data/shows/<show>/show.json (scenes, cues), baseline.json, looks/*.json - JSON you can " +
        "edit by hand; 1 is an int, 1.0 a float.")),
    card("Playback",
      statusEl,
      row(null,
        h("button", { style: "font-size:1.2em", title: "/cue/back [override]", onclick: () => { send("/cue/back", ...overrides()); later(status); } }, "◀ Back"),
        h("button.primary", { style: "font-size:1.6em;padding:10px 28px", title: "the next cue: only what it changes\n/cue/next [override]",
          onclick: () => { send("/cue/next", ...overrides()); later(status); } }, "GO ▶"),
        h("button.danger", { title: "stop every running fade where it is\n/cue/stop", onclick: () => send("/cue/stop") }, "Stop")),
      row("override", overSecs, h("label", {}, "s"), overMode),
      h("p.hint", {}, "LFOs run free: a cue sets them up or switches them; one left on may compete with a fade.")),
    card("Looks",
      row(null, lookName, h("button.primary", { title: "a new look from what differs from the current cue\n/look/save <name>",
        onclick: () => { if (lookName.value) { send("/look/save", lookName.value); lookName.value = ""; later(loadLooks); } } }, "Save as look")),
      h("table.mixer", {}, h("thead", {}, h("tr", {}, ...["look", "targets", "uses", ""].map((t) => h("th", {}, t)))), lookBody),
      h("p.hint", {}, "A look is a named part-state used by reference: the same look in several cues. Record never " +
        "changes a look; Update does (every cue that uses it).")),
    h("div.card", { style: "grid-column:1/-1" },
      h("h2", {}, "Cues"),
      row("scene", sceneSel, sceneName,
        h("button", { title: "/scene/add <name>", onclick: () => { if (sceneName.value) { scene = sceneName.value; send("/scene/add", sceneName.value); later(loadScenes); } } }, "Add"),
        h("button", { title: "/scene/rename <scene> <name>", onclick: () => { if (sceneName.value && sc()) { send("/scene/rename", sc(), sceneName.value); scene = sceneName.value; later(loadScenes); } } }, "Rename"),
        h("label", {}, loopBox, " repeat"),
        h("button.danger", { title: "/scene/delete <scene>", onclick: () => { if (sc() && confirm(`Delete scene ${sc()} and its cues?`)) { send("/scene/delete", sc()); later(loadScenes); } } }, "Delete")),
      row("record", recNum, recKind, recName,
        h("button.primary", { title: "the state now as cue <num>: its own targets = the differences from baseline + looks " +
          "(keyframe) or from the cue before + looks (delta)\n/cue/record <scene> <num> keyframe|delta [name]",
        onclick: () => {
          const s = sc() || sceneName.value || "main";
          send("/cue/record", s, net.float(Number(recNum.value)), recKind.value, ...(recName.value ? [recName.value] : []));
          scene = s; recNum.value = Number(recNum.value) + 1; recKind.value = "delta"; recName.value = "";
          later(loadScenes, 300);
        } }, "Record")),
      h("div", { style: "overflow-x:auto" }, h("table.mixer", {},
        h("thead", {}, h("tr", {}, ...["#", "name", "kind", "looks", "own", "transition", "follow s", ""].map((t) => h("th", {}, t)))), cueBody)),
      h("p.hint", {}, "Cue numbers may have decimals: record 2.5 to put a cue between 2 and 3. The first cue of a " +
        "scene must be a keyframe.")),
    h("div.card", { style: "grid-column:1/-1" }, inspTitle, inspPre)));

  net.on("/cue/status", (m) => {
    const [show, scn, num, name, kind, nsc, ncue, , left, loop] = m.args;
    statusEl.replaceChildren(h("b", {}, show), ` · scene ${scn || "–"}${loop ? " ⟳" : ""} · cue `,
      h("b", { style: "font-size:1.3em" }, num ? fmt(num) : "–"), ` ${name || ""} `, h("span.hint", {}, kind || ""),
      left >= 0 ? h("span.chip", { title: "auto follow: the next cue goes in" }, `next in ${left.toFixed(1)} s`) :
        left === -2 ? h("span.chip", { title: "auto follow: the next cue goes when this cue's movie / audio ends" }, "next at the end") : null,
      h("span.hint", {}, ` · ${nsc} scene(s), ${ncue} cue(s)`));
    if (scn && scn !== sceneSel.value && [...sceneSel.options].some((o) => o.value === scn)) { sceneSel.value = scn; scene = scn; loadCues(); }
    if (num) cueBody.querySelectorAll("tr").forEach((tr, i) => tr.classList.toggle("on", cues[i] && Number(cues[i][0]).toFixed(3) === Number(num).toFixed(3)));
  });
  net.on("/cue/record", () => later(loadCues));
}

export function connected() {
  refreshAll();
}

export function show() {
  refreshAll();
  clearInterval(timer);
  timer = setInterval(() => { if (!document.hidden && root.classList.contains("active")) status(); }, 500);
}
