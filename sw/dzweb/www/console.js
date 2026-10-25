// console.js - live log of everything the unit sends, and a raw OSC command line.
import * as net from "./net.js";
import * as osc from "./osc.js";
import { h, store } from "./ui.js";

const MAX = 400;
let log, input, history = [], hpos = -1, paused = false;

function fmt(v) {
  return typeof v === "number" && !Number.isInteger(v) ? v.toFixed(4) : JSON.stringify(v);
}

function line(text, cls) {
  if (paused) return;
  log.append(h("div", { className: cls || "" }, text));
  while (log.childNodes.length > MAX) log.firstChild.remove();
  log.scrollTop = log.scrollHeight;
}

function run(text) {
  const m = osc.parseLine(text.trim());
  if (!m) return line(`? ${text}  (start with /address)`, "err");
  net.send(osc.message(m.path, ...m.args));
  line(`> ${text}`, "out");
  history = [text, ...history.filter((x) => x !== text)].slice(0, 50);
  store.set("history", history);
  hpos = -1;
}

export function init(root) {
  history = store.get("history", []);
  log = h("div.log", { role: "log" });
  input = h("input", { type: "text", placeholder: '/disp/1/show 5   /draw/6/text 255 255 255 10 10 "hi" 2',
    onkeydown: (e) => {
      if (e.key === "Enter") { run(input.value); input.value = ""; }
      else if (e.key === "ArrowUp" && history.length) { hpos = Math.min(hpos + 1, history.length - 1); input.value = history[hpos]; e.preventDefault(); }
      else if (e.key === "ArrowDown") { hpos = Math.max(hpos - 1, -1); input.value = hpos < 0 ? "" : history[hpos]; e.preventDefault(); }
    } });
  const pause = h("button", { onclick: () => { paused = !paused; pause.textContent = paused ? "Resume" : "Pause"; } }, "Pause");
  const quick = ["/info", "/vsync", "/capture/status", "/disp/0", "/disp/1", "/list"];
  root.append(
    h("div.row", {}, ...quick.map((q) => h("button", { onclick: () => run(q) }, q)), pause,
      h("button", { onclick: () => log.replaceChildren() }, "Clear")),
    log,
    h("div.cmd", {}, input, h("button.primary", { onclick: () => { run(input.value); input.value = ""; } }, "Send")),
    h("p.hint", {}, "Numbers with a point are floats, others ints; \"quoted text\" is one string. " +
      "Up/Down: history. /vsync and /lfo polls are hidden."));
  net.onAny((m) => {
    if (m.path === "/vsync" || m.path === "/value" || m.path === "/field" || m.path === "/file" ||
        /^\/lfo\/\d+$/.test(m.path)) return; // busy polls
    const cls = m.path === "/error" ? "err" : m.path.startsWith("/event") ? "ev" : "";
    line(`${m.path} ${m.args.map(fmt).join(" ")}`, cls);
  });
}
