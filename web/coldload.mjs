// Cold load to first paint, over a throttled connection.
//
// "First paint" is taken as the moment the `#loading` placeholder disappears,
// which the wasm entry point removes only after eframe has started and the
// first frame is on its way. A `load` event would fire far earlier and measure
// nothing a user cares about.
//
// Every run gets a fresh browser context with no HTTP cache and no compiled
// wasm cache, because the number that matters is the first visit.
//
// Run: make coldload   (or: node web/coldload.mjs [runs])

import { createRequire } from "node:module";
import { resolve } from "node:path";
import { fileURLToPath } from "node:url";

import { serveDist } from "./serve.mjs";

const require = createRequire(
  resolve(fileURLToPath(new URL(".", import.meta.url)), "../.scratch/browser/package.json"),
);
const { chromium } = require("playwright");

/// "A fast connection" from docs/spec.md, pinned to numbers. 20 Mbit/s with a
/// 20 ms round trip is ordinary domestic broadband — not a datacentre link, and
/// not a bad mobile one.
const THROTTLE = {
  offline: false,
  latency: 20,
  downloadThroughput: (20 * 1024 * 1024) / 8,
  uploadThroughput: (5 * 1024 * 1024) / 8,
};
const BUDGET_MS = 2000;

const { port, close } = await serveDist();
const runs = Number(process.argv[2] ?? 5);
const browser = await chromium.launch({ channel: "chrome", headless: false });
console.log(
  `chrome ${browser.version()} · ${THROTTLE.downloadThroughput * 8 / 1024 / 1024} Mbit/s, ${THROTTLE.latency} ms RTT`,
);

const samples = [];
for (let i = 0; i < runs; i += 1) {
  const context = await browser.newContext({ viewport: { width: 1400, height: 900 }, deviceScaleFactor: 2 });
  const page = await context.newPage();
  const cdp = await context.newCDPSession(page);
  await cdp.send("Network.enable");
  await cdp.send("Network.emulateNetworkConditions", THROTTLE);

  const started = Date.now();
  await page.goto(`http://127.0.0.1:${port}/`, { waitUntil: "commit" });
  await page.waitForFunction(() => !document.getElementById("loading"), null, { timeout: 60_000 });
  const elapsed = Date.now() - started;
  samples.push(elapsed);

  // Reported per run, not just in aggregate: an outlier is only useful if you
  // can tell whether the network, the compile or the machine caused it.
  const wasm = await page.evaluate(() => {
    const e = performance.getEntriesByType("resource").find((r) => r.name.endsWith(".wasm"));
    return e
      ? {
          transferred: e.transferSize,
          decoded: e.decodedBodySize,
          duration: Math.round(e.duration),
          start: Math.round(e.startTime),
        }
      : null;
  });
  console.log(
    `  run ${i + 1}: ${elapsed}ms` +
      (wasm
        ? `  wasm ${(wasm.transferred / 1024).toFixed(0)}K on the wire` +
          ` (${(wasm.decoded / 1024).toFixed(0)}K decoded)` +
          `, fetched at +${wasm.start}ms over ${wasm.duration}ms`
        : "  (no wasm resource entry)"),
  );
  await context.close();
}

await browser.close();
close();

samples.sort((a, b) => a - b);
const median = samples[Math.floor(samples.length / 2)];
const worst = samples[samples.length - 1];
console.log(`  runs: ${samples.map((s) => `${s}ms`).join(" ")}`);
console.log(`  median ${median}ms · worst ${worst}ms · budget ${BUDGET_MS}ms`);
process.exit(median <= BUDGET_MS ? 0 : 1);
