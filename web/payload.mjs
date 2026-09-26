// Report the shipped web payload, brotli-compressed, against the budget.
//
// Brotli because that is what a CDN serves; raw wasm size is not a number any
// user waits for. The budget lives in docs/spec.md and is enforced here so a
// regression has a name and a number rather than being noticed a release later.
//
// Run: make payload   (or: node web/payload.mjs [--budget 2097152])

import { readdir, readFile } from "node:fs/promises";
import { join, resolve, extname } from "node:path";
import { fileURLToPath } from "node:url";
import { brotliCompress, constants } from "node:zlib";
import { promisify } from "node:util";

const compress = promisify(brotliCompress);
const DIST = resolve(fileURLToPath(new URL(".", import.meta.url)), "../crates/app/dist");

const budgetArg = process.argv.indexOf("--budget");
const BUDGET = budgetArg > -1 ? Number(process.argv[budgetArg + 1]) : 2 * 1024 * 1024;

let files;
try {
  files = await readdir(DIST);
} catch {
  console.error(`no bundle at ${DIST} — run \`make web-build\` first`);
  process.exit(2);
}

// What a visitor waits for before the app is usable. Anything else in `dist/`
// is fetched later or not at all — the CJK face is 16 MB and is requested only
// by a schema that needs it — and counting it here would report a cost nobody
// pays and hide the one everybody does.
const COUNTED = new Set([".wasm", ".js", ".html", ".css", ".svg"]);
let total = 0;
const rows = [];
const lazy = [];
for (const name of files.sort()) {
  const raw = await readFile(join(DIST, name));
  if (!COUNTED.has(extname(name))) {
    lazy.push([name, raw.length]);
    continue;
  }
  const squeezed = await compress(raw, {
    params: { [constants.BROTLI_PARAM_QUALITY]: 11, [constants.BROTLI_PARAM_SIZE_HINT]: raw.length },
  });
  total += squeezed.length;
  rows.push([name, raw.length, squeezed.length]);
}

const kb = (n) => `${(n / 1024).toFixed(0)} K`;
for (const [name, raw, squeezed] of rows) {
  console.log(`  ${name.padEnd(44)} ${kb(raw).padStart(9)} raw  ${kb(squeezed).padStart(9)} brotli`);
}
const verdict = total <= BUDGET ? "within" : "OVER";
console.log(`  ${"total".padEnd(44)} ${"".padStart(9)}      ${kb(total).padStart(9)} brotli`);
for (const [name, raw] of lazy) {
  console.log(`  ${name.padEnd(44)} ${kb(raw).padStart(9)} raw   on demand, not counted`);
}
console.log(`\n  ${verdict} budget: ${kb(total)} of ${kb(BUDGET)} (${((total / BUDGET) * 100).toFixed(0)}%)`);
process.exit(total <= BUDGET ? 0 : 1);
