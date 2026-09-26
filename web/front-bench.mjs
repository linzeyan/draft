// Phase 8.4's gate for stages b and c: is the DOM front end interactive at
// 1,000 tables, and what does typing into it cost?
//
// The same two questions `make web-bench` asks of the canvas build, asked the
// same way. A `sweep` run drives a deterministic camera path from "reading one
// table" out to "the whole schema framed", so every zoom level and every
// level-of-detail bucket is visited once and the worst case is reached rather
// than hoped for. A `type` run types a burst of 30 keystrokes and then pauses
// long enough for the debounce to fire, so the re-parse is exercised and not
// just the keystroke. Both runs live in the page, because that is where the
// frames are; this drives them and prints what came back.
//
// What the numbers mean:
//
//   work    time inside the frame callback — culling, building and dropping
//           SVG elements. What this code controls, and the analogue of the
//           canvas build's `cpu_usage`.
//   typing  time inside the `input` handler: one paint of the visible lines.
//   settle  the debounced re-parse, re-measure, re-layout and re-render.
//   frame   the interval between frames, which includes the browser's own
//           style, layout and paint. The number that says whether the page
//           kept up.
//
// Run: make front-bench   (or: node web/front-bench.mjs [type,396,600 ...])

import { createRequire } from "node:module";
import { readFile } from "node:fs/promises";
import { resolve } from "node:path";
import { fileURLToPath } from "node:url";

import { serveDist } from "./serve.mjs";

const HERE = fileURLToPath(new URL(".", import.meta.url));
const ROOT = resolve(HERE, "..");
const require = createRequire(resolve(ROOT, ".scratch/browser/package.json"));
const { chromium } = require("playwright");

/// A 16.7 ms frame is 60 Hz. The gate is on the *interval*, because "still
/// interactive" is a statement about whether frames arrived on time and not
/// about how little of each one we spent. A little over one frame is allowed
/// for the occasional composite; two frames in a row is a stutter.
const FRAME_BUDGET = 20;

/// A settle is one event per pause in the typing, not one per keystroke, so it
/// is allowed to cost more than a frame — the canvas build's own is 36 ms at
/// 396 KB. What it is not allowed to do is read as lag: past about a tenth of a
/// second a redraw stops feeling like a response to having stopped typing.
const SETTLE_BUDGET = 100;

const RUNS = process.argv.slice(2).length
  ? process.argv.slice(2)
  : ["sweep,300,600", "sweep,1000,600", "type,9,600", "type,106,600", "type,396,600"];

// The committed fixtures, so this measures the same schemas every other
// benchmark in this repository measures. The canvas build's typing rows are
// documents from `bench::synthetic_sql_of_size`, generated in the app rather
// than read from disk — the same sizes at 106 and 396 KB but not the same
// bytes, and 8.6 KB here against its 12 KB.
const FIXTURES = {
  sweep: {
    300: "fixtures/synthetic_300.sql",
    1000: "fixtures/synthetic_1000.sql",
  },
  type: {
    9: "fixtures/small_20.sql",
    106: "fixtures/synthetic_300.sql",
    396: "fixtures/synthetic_1000.sql",
  },
};

const { port, close } = await serveDist({ dir: resolve(ROOT, "web/front/dist") });
// Headful and the system Chrome, for the same reason web/bench.mjs is: a
// headless browser's rasterisation says nothing about what a user experiences.
const browser = await chromium.launch({ channel: "chrome", headless: false });
console.log(`chrome ${browser.version()} (headful)`);

let failures = 0;
for (const run of RUNS) {
  const [kind, size, frames] = run.split(",");
  const fixture = FIXTURES[kind]?.[size];
  if (!fixture) {
    console.log(`bench ${run}  FAILED: no ${kind} fixture for ${size}`);
    failures += 1;
    continue;
  }
  const sql = await readFile(resolve(ROOT, fixture), "utf8");

  // A fresh context per run so no font, JIT or layout state carries over and
  // flatters the next measurement.
  const context = await browser.newContext({
    viewport: { width: 1400, height: 900 },
    deviceScaleFactor: 2,
  });
  const page = await context.newPage();
  const errors = [];
  page.on("pageerror", (e) => errors.push(String(e)));
  page.on("console", (m) => m.type() === "error" && errors.push(m.text()));

  const started = Date.now();
  await page.goto(`http://127.0.0.1:${port}/`);
  await page.waitForSelector("body[data-ready='1']", { timeout: 30_000 });

  try {
    const line = await page.evaluate(
      ([mode, script, count]) =>
        mode === "type" ? window.draftTypeBench(script, count) : window.draftBench(script, count),
      [kind, sql, Number(frames)],
    );
    console.log(`${line}   (${((Date.now() - started) / 1000).toFixed(1)}s wall)`);
    if (errors.length > 0) {
      failures += 1;
      console.log(`  FAILED: the page reported ${errors.length}: ${errors.join(" | ")}`);
    }
    // Parsed back out of the report rather than returned separately, so the
    // numbers the gate judges are the numbers a reader sees.
    const at = (pattern) => Number(pattern.exec(line)?.[1]);
    const judged = [["frame", at(/frame .*p95=([\d.]+)ms/), FRAME_BUDGET]];
    if (kind === "type") {
      judged.push(
        ["typing", at(/typing .*?p95=([\d.]+)ms/), FRAME_BUDGET],
        ["settle", at(/settle .*?max=([\d.]+)ms/), SETTLE_BUDGET],
      );
    }
    for (const [what, value, budget] of judged) {
      if (!(value <= budget)) {
        failures += 1;
        console.log(`  FAILED: ${what} ${value} ms is over the ${budget} ms budget`);
      }
    }
  } catch (e) {
    failures += 1;
    console.log(`bench ${run}  FAILED: ${e.message}`);
  }
  await context.close();
}

await browser.close();
close();
console.log(
  failures === 0
    ? `\nfront interaction: PASSED — every run inside ${FRAME_BUDGET} ms at the 95th ` +
      `percentile, every settle inside ${SETTLE_BUDGET} ms`
    : `\nfront interaction: FAILED — ${failures}`,
);
process.exit(failures ? 1 : 0);
