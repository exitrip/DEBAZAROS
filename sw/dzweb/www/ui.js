// ui.js - tiny DOM helpers shared by the tab modules.

// h("button.primary", { onclick }, "Text", child...)
export function h(spec, props = {}, ...kids) {
  const [tag, ...cls] = spec.split(".");
  const el = document.createElement(tag || "div");
  if (cls.length) el.className = cls.join(" ");
  for (const [k, v] of Object.entries(props || {})) {
    if (k.startsWith("on")) el.addEventListener(k.slice(2), v);
    else if (k === "style") el.style.cssText = v;
    else if (k in el && k !== "list") el[k] = v;
    else el.setAttribute(k, v);
  }
  for (const k of kids.flat()) {
    if (k === null || k === undefined || k === false) continue;
    el.append(k instanceof Node ? k : document.createTextNode(String(k)));
  }
  return el;
}

export function card(title, ...kids) {
  return h("div.card", {}, h("h2", {}, ...[].concat(title)), ...kids);
}

export function row(label, ...kids) {
  return h("div.row", {}, label ? h("label", {}, label) : null, ...kids);
}

let toastTimer;
export function toast(text, isError = false) {
  const t = document.getElementById("toast");
  t.textContent = text;
  t.className = "show" + (isError ? " err" : "");
  clearTimeout(toastTimer);
  toastTimer = setTimeout(() => (t.className = ""), isError ? 4000 : 2000);
}

// localStorage that never throws (private mode, blocked storage)
export const store = {
  get(k, d) {
    try {
      const v = localStorage.getItem("dz." + k);
      return v === null ? d : JSON.parse(v);
    } catch {
      return d;
    }
  },
  set(k, v) {
    try {
      localStorage.setItem("dz." + k, JSON.stringify(v));
    } catch {
      /* ignore */
    }
  },
};

export function hexToRgb(hex) {
  const n = parseInt(hex.slice(1), 16);
  return [(n >> 16) & 255, (n >> 8) & 255, n & 255];
}

export function rgbToHex(r, g, b) {
  return "#" + [r, g, b].map((v) => v.toString(16).padStart(2, "0")).join("");
}
