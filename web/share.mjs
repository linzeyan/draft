// Phase 6's acceptance gate: a share link round-trips a project with
// annotations and a custom layout, and nothing is ever sent to a server.
//
// The second half is the part that needs a browser to prove. "It is in the
// fragment, and browsers do not transmit fragments" is a true statement about a
// specification; this watches the wire instead. Every request either tab makes
// is recorded, and the payload is looked for in all of them.
//
// Driven by coordinates, like web/shot.mjs: egui owns the whole canvas, so
// there is no DOM node to ask for.
//
// Run: make share   (or: node web/share.mjs)

import { createRequire } from "node:module";
import { createServer } from "node:http";
import { mkdir, writeFile } from "node:fs/promises";
import { resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { inflateRawSync } from "node:zlib";

import { serveDist } from "./serve.mjs";

const HERE = fileURLToPath(new URL(".", import.meta.url));
const require = createRequire(resolve(HERE, "../.scratch/browser/package.json"));
const { chromium } = require("playwright");

const shots = resolve(HERE, "../.scratch/shots");
// Kept rather than thrown away: an export is a file somebody will open in
// something else, and the only way to know it is right is to go and look at it.
const exports_ = resolve(HERE, "../.scratch/exports");
await mkdir(shots, { recursive: true });
await mkdir(exports_, { recursive: true });

// Toolbar and menu positions, in CSS pixels. Read off a screenshot; the toolbar
// is laid out left to right in one row and does not move between runs — but it
// *does* move when a button is added to it, which is why the checks below read
// the project out of the link instead of trusting that a click landed.
const TOOLBAR = { share: 88, note: 634, group: 682, y: 15 };
const MENU = { x: 105, copyLink: 41, saveProject: 62, exportSvg: 91, exportPng: 112 };
// The `customers` box in the sample schema, at the zoom the app opens with.
const TABLE = { x: 525, y: 309 };
const NOTE = "rottnest-island-census";

const { port, close } = await serveDist();
const origin = `http://127.0.0.1:${port}/`;
const browser = await chromium.launch({ channel: "chrome", headless: false });

// Every request any tab makes, from launch to the end of the run.
const requests = [];
function fresh() {
  return browser
    .newContext({
      viewport: { width: 1400, height: 900 },
      deviceScaleFactor: 2,
      permissions: ["clipboard-read", "clipboard-write"],
    })
    .then((ctx) => {
      ctx.on("request", (r) => requests.push({ method: r.method(), url: r.url() }));
      return ctx;
    });
}

const context = await fresh();

const failures = [];
function check(ok, what) {
  console.log(`  ${ok ? "ok  " : "FAIL"}  ${what}`);
  if (!ok) failures.push(what);
}

async function ready(page) {
  await page.waitForFunction(() => !document.getElementById("loading"), null, { timeout: 60_000 });
  await page.waitForTimeout(800);
}

/// Click Share, then an item in the menu it opens.
async function menu(page, item) {
  await page.mouse.click(TOOLBAR.share, TOOLBAR.y);
  await page.waitForTimeout(300);
  await page.mouse.click(MENU.x, item);
  await page.waitForTimeout(600);
}

const page = await context.newPage();
await page.goto(origin);
await ready(page);

// A group box and a sticky note with text on it, both of which have to survive
// the trip. The note is created with a field already open, so the text goes
// straight in.
await page.mouse.click(TOOLBAR.group, TOOLBAR.y);
await page.waitForTimeout(300);
await page.keyboard.type("payments", { delay: 15 });
await page.keyboard.press("Escape");
await page.waitForTimeout(300);
await page.mouse.click(TOOLBAR.note, TOOLBAR.y);
await page.waitForTimeout(300);
await page.keyboard.type(NOTE, { delay: 15 });
await page.keyboard.press("Escape");
await page.waitForTimeout(400);

// A custom layout: drag a table well away from where the engine put it.
await page.mouse.move(TABLE.x, TABLE.y);
await page.mouse.down();
for (const step of [0.33, 0.66, 1]) {
  await page.mouse.move(TABLE.x + 220 * step, TABLE.y + 240 * step);
  await page.waitForTimeout(40);
}
await page.mouse.up();
await page.waitForTimeout(400);
await page.screenshot({ path: resolve(shots, "14-annotated.png") });

await menu(page, MENU.copyLink);
await page.screenshot({ path: resolve(shots, "15-shared.png") });

const link = page.url();
const payload = link.split("#p1=")[1] ?? "";
check(payload.length > 100, `the address bar carries the project (${payload.length} chars)`);

/// The project a link carries. Deflate then base64url, the order `share.rs`
/// documents, so this is the same bytes the application would decode.
function project(from) {
  return JSON.parse(inflateRawSync(Buffer.from(from, "base64url")).toString());
}

// What the link actually contains, rather than what the clicks were aimed at.
// Every step above is driven by coordinates, and a toolbar button added in
// front of Note silently moved these clicks onto Arrange once already — the run
// stayed green because nothing asserted the annotations existed.
const shared = project(payload);
check(
  shared.annotations?.some((a) => a.text === NOTE),
  "the note that was typed is inside the link",
);
check(
  shared.annotations?.length === 2,
  `both annotations travelled (${shared.annotations?.length ?? 0} found)`,
);
check(
  shared.placement?.prev?.some((p) => p.moved),
  "the table that was dragged travelled as hand-placed",
);
check(
  (await page.evaluate(() => navigator.clipboard.readText())) === link,
  "Copy link put that same link on the clipboard",
);

// Follow the link in a fresh browser context — no local storage, no session,
// nothing to fall back on. Whatever arrives came out of the URL or came from
// nowhere.
const visitor = await fresh();
const opened = await visitor.newPage();
await opened.goto(link);
await ready(opened);
await opened.screenshot({ path: resolve(shots, "16-opened.png") });

await menu(opened, MENU.copyLink);
const again = opened.url().split("#p1=")[1] ?? "";
check(
  again === payload,
  "re-sharing what the link opened produces the identical payload — nothing was lost",
);

// Save and export hand over real files, built in the tab and handed to the
// browser through a blob. Checked here rather than in the screenshot run
// because a download is not something a picture can show.
const saved = {};
for (const [item, suffix, magic] of [
  [MENU.saveProject, ".draft.json", "{"],
  [MENU.exportSvg, ".svg", "<svg"],
  [MENU.exportPng, ".png", "\x89PNG"],
]) {
  const [download] = await Promise.all([page.waitForEvent("download"), menu(page, item)]);
  const name = download.suggestedFilename();
  const body = await download.createReadStream().then(async (s) => {
    const chunks = [];
    for await (const chunk of s) chunks.push(chunk);
    return Buffer.concat(chunks);
  });
  saved[suffix] = resolve(exports_, name);
  await writeFile(saved[suffix], body);
  check(name.endsWith(suffix), `${suffix} is offered as ${name}`);
  check(
    body.subarray(0, magic.length).toString("latin1") === magic,
    `${suffix} is a real ${suffix.slice(1)} file (${body.length} bytes)`,
  );
}

// The other half of Save: a saved project has to open again. Opened in the
// visitor's context, which never saw the project — so anything on screen came
// out of the file.
const reopened = await visitor.newPage();
await reopened.goto(origin);
await ready(reopened);
const [chooser] = await Promise.all([
  reopened.waitForEvent("filechooser"),
  reopened.mouse.click(35, TOOLBAR.y),
]);
await chooser.setFiles(saved[".draft.json"]);
await reopened.waitForTimeout(1200);
await reopened.screenshot({ path: resolve(shots, "17-reopened.png") });
await menu(reopened, MENU.copyLink);
check(
  (reopened.url().split("#p1=")[1] ?? "") === payload,
  "a saved project file opens back to the project that was saved",
);

// The gate, first half: up to this point nobody has asked for anything from
// anywhere else, so nothing may have left the origin.
const offOrigin = (from) => requests.slice(from).filter((r) => !r.url.startsWith(origin));
const beforeUrl = requests.length;
check(
  offOrigin(0).length === 0,
  `no request left the origin unasked (${requests.length} seen)`,
);

// `#u=`: the one request this application is allowed to make off-origin, and
// only because a link asked for it. A second local server is a genuinely
// different origin, so this needs no internet.
const SCHEMA = "CREATE TABLE probe_one (id int PRIMARY KEY);\n\
CREATE TABLE probe_two (id int PRIMARY KEY, one_id int REFERENCES probe_one(id));\n";
const elsewhere = createServer((req, res) => {
  // `/open.sql` allows cross-origin reads; `/closed.sql` does not, which is
  // what a repository page looks like to a browser.
  const headers = { "content-type": "text/plain" };
  if (req.url.startsWith("/open.sql")) headers["access-control-allow-origin"] = "*";
  res.writeHead(200, headers).end(SCHEMA);
});
const other = await new Promise((ok) => {
  elsewhere.listen(0, "127.0.0.1", () => ok(`http://127.0.0.1:${elsewhere.address().port}`));
});

const linked = await visitor.newPage();
await linked.goto(`${origin}#u=${encodeURIComponent(`${other}/open.sql`)}`);
await ready(linked);
await linked.waitForTimeout(600);
await linked.screenshot({ path: resolve(shots, "18-from-url.png") });
await menu(linked, MENU.copyLink);
const fromUrl = project(linked.url().split("#p1=")[1] ?? "");
check(fromUrl.sql === SCHEMA, "the schema at the URL is the schema on screen");
check(fromUrl.name === "open.sql", `the document is named after the file (${fromUrl.name})`);

const fetches = requests.slice(beforeUrl).filter((r) => r.url.startsWith(other));
check(fetches.length === 1, `the link made exactly one off-origin request (${fetches.length})`);
check(
  fetches.every((r) => r.method === "GET" && r.url.endsWith("/open.sql")),
  "and it was a GET for the file named in the link, carrying nothing else",
);

// A host that refuses cross-origin reads has to fail visibly. The browser tells
// the page nothing about why, so the application says what to try instead —
// and the screenshot is the evidence that it says anything at all.
const refused = await visitor.newPage();
await refused.goto(`${origin}#u=${encodeURIComponent(`${other}/closed.sql`)}`);
await ready(refused);
await refused.waitForTimeout(800);
await refused.screenshot({ path: resolve(shots, "19-url-refused.png") });

// The gate, second half: across the whole run, the only requests that left the
// origin are the two a link asked for by name.
const foreign = offOrigin(0).filter((r) => !r.url.startsWith(other));
check(
  foreign.length === 0,
  `nothing left the origin that was not asked for (${requests.length} requests seen)`,
);
const marker = payload.slice(0, 24);
const leaked = requests.filter(
  (r) => (marker.length > 0 && r.url.includes(marker)) || r.url.includes(NOTE),
);
check(leaked.length === 0, "no request carried the payload or the note's text");
const posts = requests.filter((r) => r.method !== "GET");
check(posts.length === 0, "nothing was posted anywhere");

await visitor.close();
await context.close();
await browser.close();
close();
elsewhere.close();

console.log(
  failures.length === 0
    ? `\nshare link: PASSED — ${requests.length} requests, ${fetches.length + 1} of them the \
two files a link named and the rest this page's own assets`
    : `\nshare link: FAILED\n  ${failures.join("\n  ")}`,
);
process.exit(failures.length === 0 ? 0 : 1);
