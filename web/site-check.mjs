// Phase 7's acceptance gate: the deployed tree actually works.
//
// Three things can be wrong here and cannot be seen by reading the generator:
// a link that goes nowhere, a page that loads something from off-origin, and
// the application failing to start when it is mounted at /app/ instead of the
// root — the bundle's asset paths are relative precisely so that both work, and
// "precisely so that" is not evidence.
//
// Every page in the sitemap is visited, every internal link is resolved against
// what was actually written to disk, and the app is driven until it paints.
//
// Run: make site-check   (or: node web/site-check.mjs)

import { createRequire } from "node:module";
import { mkdir, readFile } from "node:fs/promises";
import { resolve } from "node:path";
import { fileURLToPath } from "node:url";

import { serveSite } from "./site-serve.mjs";

const HERE = fileURLToPath(new URL(".", import.meta.url));
const DIST = resolve(HERE, "dist");
const shots = resolve(HERE, "../.scratch/shots/site");
await mkdir(shots, { recursive: true });

const require = createRequire(resolve(HERE, "../.scratch/browser/package.json"));
const { chromium } = require("playwright");

const failures = [];
function check(ok, what) {
  console.log(`  ${ok ? "ok  " : "FAIL"}  ${what}`);
  if (!ok) failures.push(what);
}

const sitemap = await readFile(resolve(DIST, "sitemap.xml"), "utf8");
const slugs = [...sitemap.matchAll(/<loc>([^<]+)<\/loc>/g)].map((m) => new URL(m[1]).pathname);
check(slugs.length >= 8, `the sitemap lists every page (${slugs.length})`);

const { port, close } = await serveSite(0);
const origin = `http://127.0.0.1:${port}`;
const browser = await chromium.launch({ channel: "chrome", headless: true });
const context = await browser.newContext({ viewport: { width: 1280, height: 900 } });

const requests = [];
context.on("request", (r) => requests.push(r.url()));

const page = await context.newPage();
const problems = [];
page.on("console", (m) => m.type() === "error" && problems.push(m.text()));
page.on("pageerror", (e) => problems.push(String(e)));

// Every internal link any page offers, so a dead one is found here rather than
// by the first person who clicks it.
const links = new Set();

for (const slug of slugs) {
  const response = await page.goto(origin + slug);
  const name = slug === "/" ? "home" : slug.replace(/\//g, "");
  check(response.status() === 200, `${slug} serves`);

  const meta = await page.evaluate(() => ({
    title: document.title,
    description: document.querySelector('meta[name="description"]')?.content ?? "",
    canonical: document.querySelector('link[rel="canonical"]')?.href ?? "",
    h1: document.querySelector("h1")?.textContent?.trim() ?? "",
    scripts: document.querySelectorAll("script").length,
    text: document.body.innerText.length,
    hrefs: [...document.querySelectorAll("a[href]")].map((a) => a.getAttribute("href")),
  }));

  for (const href of meta.hrefs) if (href.startsWith("/")) links.add(href);

  check(
    meta.title.length > 10 && meta.description.length > 50 && meta.canonical !== "",
    `${slug} has a title, a description and a canonical URL`,
  );
  check(meta.h1 !== "", `${slug} has an h1`);
  // The whole point of these pages: indexable text, and no wasm anywhere near
  // them. A script tag here would mean the generator grew one by accident.
  check(meta.scripts === 0, `${slug} runs no script at all`);
  check(meta.text > 500, `${slug} carries real text for a crawler (${meta.text} chars)`);

  await page.screenshot({ path: resolve(shots, `${name}.png`), fullPage: true });
}

for (const href of [...links].sort()) {
  if (href === "/app/") continue; // checked properly below
  const response = await page.goto(origin + href);
  check(response.status() === 200, `link ${href} resolves`);
}

// The application, mounted where the site puts it rather than at the root.
await page.goto(`${origin}/app/`);
await page.waitForFunction(() => !document.getElementById("loading"), null, { timeout: 60_000 });
await page.waitForTimeout(1500);
await page.screenshot({ path: resolve(shots, "app.png") });
const canvas = await page.evaluate(() => {
  const c = document.getElementById("canvas");
  return c ? { w: c.width, h: c.height } : null;
});
check(canvas !== null && canvas.w > 0 && canvas.h > 0, `the app starts at /app/ (${canvas?.w}x${canvas?.h})`);
check(problems.length === 0, `nothing threw (${problems.slice(0, 2).join(" | ") || "clean"})`);

const foreign = requests.filter((u) => !u.startsWith(origin));
check(foreign.length === 0, `nothing is loaded from off-origin (${foreign.slice(0, 3).join(", ") || "none"})`);

await context.close();
await browser.close();
close();

console.log(
  failures.length === 0
    ? `\nsite: PASSED — ${slugs.length} pages, ${links.size} internal links, app starts at /app/`
    : `\nsite: FAILED\n  ${failures.join("\n  ")}`,
);
process.exit(failures.length === 0 ? 0 : 1);
