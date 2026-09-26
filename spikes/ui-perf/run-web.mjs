// Phase 0 spike S5 -- run the S2/S3 spikes in a real browser and scrape the
// result out of the console.
//
// Native numbers are a lower bound for wasm, so the gates in docs/roadmap.md
// are not met until they have been reproduced here.
//
// Run: node spikes/ui-perf/run-web.mjs
// Requires: trunk build --release in spikes/ui-perf, and playwright installed
//           in .scratch/browser (see docs/measurements.md).

import { createServer } from "node:http";
import { readFile } from "node:fs/promises";
import { extname, join, resolve } from "node:path";
import { createRequire } from "node:module";
import { fileURLToPath } from "node:url";

const HERE = fileURLToPath(new URL(".", import.meta.url));
const DIST = resolve(HERE, "dist");
// Anchored at a file, not a directory: `resolve` drops the trailing separator,
// and createRequire then resolves relative to the parent directory instead.
const require = createRequire(resolve(HERE, "../../.scratch/browser/package.json"));
const { chromium } = require("playwright");

const MIME = {
  ".html": "text/html",
  ".js": "text/javascript",
  ".wasm": "application/wasm",
  ".css": "text/css",
};

// Trunk emits a hashed bundle; serving dist/ verbatim keeps the harness
// independent of those names.
const server = createServer(async (req, res) => {
  const path = decodeURIComponent(req.url.split("?")[0].split("#")[0]);
  const file = join(DIST, path === "/" ? "index.html" : path);
  try {
    const body = await readFile(file);
    res.writeHead(200, { "content-type": MIME[extname(file)] ?? "application/octet-stream" });
    res.end(body);
  } catch {
    res.writeHead(404).end("not found");
  }
});

const port = await new Promise((ok) => {
  server.listen(0, "127.0.0.1", () => ok(server.address().port));
});

const RUNS = [
  ["editor,top,300,106", "editor 106K"],
  ["editor,top,300,212", "editor 212K"],
  ["editor,top,300,396", "editor 396K"],
  ["canvas,300,600", "canvas 300"],
  ["canvas,1000,600", "canvas 1000"],
  ["canvas,3000,600", "canvas 3000"],
];

// Headful, and the system Chrome rather than a bundled build.
//
// Headless Chrome falls back to SwiftShader for WebGL -- software rasterisation
// that is far slower than any real machine. Measuring there would produce a
// pessimistic number that tells us nothing about what a user experiences, so
// the browser gets a real GPU.
let reportedGeometry = false;
const browser = await chromium.launch({ channel: "chrome", headless: false });
console.log(`chrome ${browser.version()} (headful, hardware WebGL)`);

for (const [hash, label] of RUNS) {
  // A fresh context per run so no font atlas, shader or JIT state carries over
  // and flatters the next measurement.
  // deviceScaleFactor must match the physical display, not be left at 1.
  //
  // Chrome's DPR emulation is inconsistent: with deviceScaleFactor 1 on a
  // retina machine, window.devicePixelRatio reports 1 while the ResizeObserver
  // still reports a device-pixel box at the physical 2x. eframe divides the
  // backing store by devicePixelRatio, so egui ended up believing it had a
  // 2800x1800 point viewport -- four times the native run's area, which made
  // every cross-target comparison meaningless.
  const context = await browser.newContext({
    viewport: { width: 1400, height: 900 },
    deviceScaleFactor: 2,
  });
  const page = await context.newPage();

  const done = new Promise((ok, fail) => {
    const timer = setTimeout(() => fail(new Error("timed out waiting for RESULT")), 120_000);
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

  await page.goto(`http://127.0.0.1:${port}/#${hash}`);

  try {
    const line = await done;
    // Probe after the run, once eframe has finished sizing the canvas. A
    // native/web comparison is worthless unless both lay out the same area in
    // the same units, so the geometry is printed rather than assumed.
    if (!reportedGeometry) {
      reportedGeometry = true;
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
    console.log(line);
  } catch (e) {
    console.log(`${label}  FAILED: ${e.message}`);
  }
  await context.close();
}

await browser.close();
server.close();
