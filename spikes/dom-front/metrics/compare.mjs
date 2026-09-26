// Spike S5b -- epaint's measured widths against a browser's, same faces.
//
// Runs the Rust side (which prints JSON), measures the same corpus in Chrome
// with the same font files, and reports the divergence. A DOM front end would
// let the browser measure; the CLI cannot, so whatever comes out of here is the
// permanent difference between a CLI-drawn diagram and a browser-drawn one.
//
// Usage: node spikes/dom-front/metrics/compare.mjs

import { createRequire } from "node:module";
import { execFileSync } from "node:child_process";
import { readFile } from "node:fs/promises";
import { resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { homedir } from "node:os";

const HERE = fileURLToPath(new URL(".", import.meta.url));
const ROOT = resolve(HERE, "../../..");
const require = createRequire(resolve(ROOT, ".scratch/browser/package.json"));
const { chromium } = require("playwright");

// The same two files `epaint_default_fonts` hands to epaint, so both sides are
// shaping with identical outlines. Located rather than vendored: a second copy
// could drift from the one the application links.
const REGISTRY = resolve(homedir(), ".cargo/registry/src");
async function findFont(name) {
  const { readdir } = await import("node:fs/promises");
  for (const index of await readdir(REGISTRY)) {
    const candidate = resolve(REGISTRY, index, "epaint_default_fonts-0.36.2/fonts", name);
    try {
      return await readFile(candidate);
    } catch {
      /* try the next registry index */
    }
  }
  throw new Error(`cannot find ${name} in ${REGISTRY}`);
}

const rust = JSON.parse(
  execFileSync("cargo", ["run", "--quiet", "--release"], {
    cwd: HERE,
    encoding: "utf8",
    maxBuffer: 1 << 24,
    env: { ...process.env, CARGO_TARGET_DIR: resolve(ROOT, ".scratch/s5-metrics-target") },
  }),
);

const fonts = {
  ui: (await findFont("Ubuntu-Light.ttf")).toString("base64"),
  mono: (await findFont("Hack-Regular.ttf")).toString("base64"),
};

const browser = await chromium.launch({ channel: "chrome", headless: true });
const page = await browser.newPage();
await page.goto("about:blank");
const measured = await page.evaluate(async ({ faces, corpus }) => {
  const bytes = (b64) => Uint8Array.from(atob(b64), (c) => c.charCodeAt(0)).buffer;
  for (const [family, b64] of Object.entries(faces)) {
    const face = new FontFace(family, bytes(b64));
    await face.load();
    document.fonts.add(face);
  }
  const canvas = document.createElement("canvas").getContext("2d");
  const svg = document.createElementNS("http://www.w3.org/2000/svg", "svg");
  const text = document.createElementNS("http://www.w3.org/2000/svg", "text");
  svg.append(text);
  document.body.append(svg);

  return corpus.map(({ text: string, size, family }) => {
    canvas.font = `${size}px "${family}"`;
    text.setAttribute("font-family", family);
    text.setAttribute("font-size", String(size));
    text.textContent = string;
    return {
      canvas: canvas.measureText(string).width,
      svg: text.getComputedTextLength(),
    };
  });
}, {
  faces: fonts,
  // Only the ppp=1 half: the browser has one answer per (string, size), and
  // asking it twice would just duplicate it.
  corpus: rust.filter((r) => r.ppp === 1),
});
await browser.close();

const ppp1 = rust.filter((r) => r.ppp === 1);
const ppp2 = rust.filter((r) => r.ppp === 2);
const rows = ppp1.map((row, i) => ({
  ...row,
  ppp2: ppp2[i].width,
  canvas: measured[i].canvas,
  svg: measured[i].svg,
}));

const pct = (a, b) => (b === 0 ? 0 : ((a - b) / b) * 100);
console.log(
  ["text", "style", "size", "epaint@1", "epaint@2", "canvas", "svg", "Δ@1 %", "Δ@2 %"]
    .map((h, i) => (i < 2 ? h.padEnd(18) : h.padStart(10)))
    .join(""),
);
for (const row of rows) {
  console.log(
    [
      row.text.padEnd(18),
      row.style.padEnd(18),
      String(row.size).padStart(10),
      row.width.toFixed(2).padStart(10),
      row.ppp2.toFixed(2).padStart(10),
      row.canvas.toFixed(2).padStart(10),
      row.svg.toFixed(2).padStart(10),
      pct(row.width, row.canvas).toFixed(2).padStart(10),
      pct(row.ppp2, row.canvas).toFixed(2).padStart(10),
    ].join(""),
  );
}

const summary = (key) => {
  const deltas = rows.map((r) => Math.abs(pct(r[key], r.canvas)));
  const px = rows.map((r) => Math.abs(r[key] - r.canvas));
  return {
    worst: Math.max(...deltas).toFixed(2) + "%",
    mean: (deltas.reduce((a, b) => a + b, 0) / deltas.length).toFixed(2) + "%",
    worstPx: Math.max(...px).toFixed(2) + "px",
  };
};
console.log("\nepaint@1 vs canvas:", summary("width"));
console.log("epaint@2 vs canvas:", summary("ppp2"));
const svgVsCanvas = Math.max(...rows.map((r) => Math.abs(r.svg - r.canvas)));
console.log("svg vs canvas, worst:", svgVsCanvas.toFixed(3) + "px");
