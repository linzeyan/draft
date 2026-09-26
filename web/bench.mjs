// Run the frame-cost gates in a real browser and scrape the results.
//
// Native numbers are a lower bound for wasm — the same code in a browser is
// typically slower — so a native pass is not the gate. This is.
//
// Run: make web-bench   (or: node web/bench.mjs [canvas,1000,600 ...])
// Requires: trunk build --release in crates/app, and playwright installed in
//           .scratch/browser (see docs/measurements.md).

import { createRequire } from "node:module";
import { resolve } from "node:path";
import { fileURLToPath } from "node:url";

import { serveDist } from "./serve.mjs";

// Anchored at a file, not a directory: `resolve` drops the trailing separator,
// and createRequire then resolves relative to the parent directory instead.
const require = createRequire(
  resolve(fileURLToPath(new URL(".", import.meta.url)), "../.scratch/browser/package.json"),
);
const { chromium } = require("playwright");

const { port, close } = await serveDist();
// The canvas runs are the Phase 2 gate; the typing runs are Phase 3's. 106 KB
// is the Pagila fixture S2 was measured on, 396 KB the Sakila one.
const RUNS = process.argv.slice(2).length
  ? process.argv.slice(2)
  : [
      "canvas,300,600",
      "canvas,1000,600",
      "canvas,3000,600",
      "type,12,600",
      "type,106,600",
      "type,396,600",
    ];

// Headful, and the system Chrome rather than a bundled build.
//
// Headless Chrome falls back to SwiftShader for WebGL — software rasterisation
// far slower than any real machine. Measuring there would produce a pessimistic
// number that says nothing about what a user experiences.
let reportedGeometry = false;
const browser = await chromium.launch({ channel: "chrome", headless: false });
console.log(`chrome ${browser.version()} (headful, hardware WebGL)`);

let failures = 0;
for (const run of RUNS) {
  // A fresh context per run so no font atlas, shader or JIT state carries over
  // and flatters the next measurement. deviceScaleFactor must match a real
  // display: with it left at 1 on a retina machine, Chrome reports dpr 1 while
  // the ResizeObserver still reports a 2x device-pixel box, and eframe ends up
  // believing it has four times the viewport area.
  const context = await browser.newContext({
    viewport: { width: 1400, height: 900 },
    deviceScaleFactor: 2,
  });
  const page = await context.newPage();

  const done = new Promise((ok, fail) => {
    const timer = setTimeout(() => fail(new Error("timed out waiting for RESULT")), 180_000);
    page.on("console", (msg) => {
      const text = msg.text();
      if (text.startsWith("RESULT ")) {
        clearTimeout(timer);
        ok(text.slice("RESULT ".length));
      }
    });
    page.on("pageerror", (e) => {
      clearTimeout(timer);
      fail(e);
    });
  });

  const started = Date.now();
  await page.goto(`http://127.0.0.1:${port}/#bench=${run}`);

  try {
    const line = await done;
    if (!reportedGeometry) {
      reportedGeometry = true;
      // Printed rather than assumed: a native/web comparison is worthless
      // unless both lay out the same area in the same units.
      const g = await page.evaluate(() => {
        const c = document.getElementById("canvas");
        return {
          dpr: window.devicePixelRatio,
          win: [window.innerWidth, window.innerHeight],
          css: [c.clientWidth, c.clientHeight],
          backing: [c.width, c.height],
        };
      });
      console.log(
        `  geometry: dpr=${g.dpr} window=${g.win.join("x")} ` +
          `canvas-css=${g.css.join("x")} canvas-backing=${g.backing.join("x")}`,
      );
    }
    console.log(`${line}   (${((Date.now() - started) / 1000).toFixed(1)}s wall)`);
  } catch (e) {
    failures += 1;
    console.log(`bench ${run}  FAILED: ${e.message}`);
  }
  await context.close();
}

await browser.close();
close();
process.exit(failures ? 1 : 0);
