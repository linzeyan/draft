// Phase 8.4 stage a's gate: the browser's diagram is the CLI's diagram.
//
// The DOM front end lets the browser measure its own text; the CLI measures with
// epaint. Everything on top of those widths — the box arithmetic and the layout
// engine — is the same Rust in both. So this compares the one thing that can
// differ: where the boxes ended up, and how big they are.
//
// The reference is the CLI's real SVG output rather than a second code path
// written for the test. If the two disagree by more than a tenth of a point,
// either the browser measures differently from epaint (S5 said 0.02 px, so that
// would be news) or a rule has been duplicated in JavaScript instead of asked
// for. Both are exactly what this stage is for.
//
// Run: make front-check

import { createRequire } from "node:module";
import { execFileSync } from "node:child_process";
import { mkdir, readFile } from "node:fs/promises";
import { resolve } from "node:path";
import { fileURLToPath } from "node:url";

import { serveDist } from "./serve.mjs";

const HERE = fileURLToPath(new URL(".", import.meta.url));
const ROOT = resolve(HERE, "..");
const require = createRequire(resolve(ROOT, ".scratch/browser/package.json"));
const { chromium } = require("playwright");

const out = resolve(ROOT, ".scratch/front-check");
await mkdir(out, { recursive: true });

/// A tenth of a point. Tight enough that a duplicated rule or a different font
/// shows up; loose enough that two float pipelines are allowed to disagree in
/// their last bit.
const TOLERANCE = 0.1;

const failures = [];
function check(ok, what) {
  console.log(`  ${ok ? "ok  " : "FAIL"}  ${what}`);
  if (!ok) failures.push(what);
}

// The CLI, with its defaults: horizontal and comfortable, which is what the
// front end asks `place` for. A different direction here would compare two
// different diagrams and pass or fail for the wrong reason.
const svgPath = resolve(out, "cli.svg");
execFileSync(
  "cargo",
  ["run", "--quiet", "-p", "draft-cli", "--", "render", "crates/app/src/sample.sql", "-o", svgPath],
  { cwd: ROOT, stdio: ["ignore", "inherit", "inherit"] },
);
const svg = await readFile(svgPath, "utf8");

// Every table box is a rect with a stroke; the header bands and the background
// are fills. The document is written shape by shape in table order
// (crates/export/src/lib.rs), so these come out in the schema's order.
const cli = [...svg.matchAll(/<rect x="([-\d.]+)" y="([-\d.]+)" width="([\d.]+)" height="([\d.]+)"[^>]*stroke="/g)].map(
  (m) => ({
    // Undo the one thing the writer adds to a box's own coordinates: the half
    // pixel an inside stroke is inset by, because SVG centres strokes on the
    // path. The margin is not in here — `svg()` applies that with a transform
    // on the group, so these numbers are already the layout engine's.
    x: Number(m[1]) - 0.5,
    y: Number(m[2]) - 0.5,
    w: Number(m[3]) + 1,
    h: Number(m[4]) + 1,
  }),
);
check(cli.length > 0, `the CLI's SVG has boxes in it (${cli.length})`);

// And every relationship curve. `<path>` is written for nothing else in a
// rendered diagram — boxes are rects, marks are lines, labels are text — and
// the shapes are emitted edges-first, in the schema's relation order.
const curves = [...svg.matchAll(/<path d="M ([-\d.]+) ([-\d.]+) C ([-\d.]+) ([-\d.]+), ([-\d.]+) ([-\d.]+), ([-\d.]+) ([-\d.]+)"/g)].map(
  (m) => m.slice(1).map(Number),
);
check(curves.length > 0, `the CLI's SVG has edges in it (${curves.length})`);

const { port, close } = await serveDist({ dir: resolve(ROOT, "web/front/dist") });
const browser = await chromium.launch({ channel: "chrome", headless: true });
const page = await browser.newPage({ viewport: { width: 1400, height: 900 }, deviceScaleFactor: 2 });
const errors = [];
page.on("console", (m) => m.type() === "error" && errors.push(m.text()));
page.on("pageerror", (e) => errors.push(String(e)));
// With the URL: a 404 for a font is a wrong diagram, and a 404 for a favicon is
// a browser being a browser. Telling them apart needs the name.
page.on("response", (r) => r.status() >= 400 && errors.push(`${r.status()} ${r.url()}`));
await page.goto(`http://127.0.0.1:${port}/`);
try {
  await page.waitForSelector("body[data-ready='1']", { timeout: 30_000 });
} catch (e) {
  // A page that never starts has almost always already said why — a module
  // that 404ed, an export that moved. Thirty seconds of silence followed by a
  // timeout hides the one line that matters.
  console.log(`  FAIL  the page never became ready\n        ${errors.join("\n        ") || e.message}`);
  await browser.close();
  close();
  process.exit(1);
}
await page.screenshot({ path: resolve(out, "front.png") });
// Named one by one rather than handed `window.draft` whole: it is a set of
// getters over live state, and the point here is to read the geometry as it was
// at load, before the camera drives below move anything.
const web = await page.evaluate(() => ({
  boxes: window.draft.boxes,
  routes: window.draft.routes,
  tables: window.draft.tables,
  lod: window.draft.lod,
  counts: window.draft.counts,
}));
const status = await page.textContent("#status");

check(errors.length === 0, `the page loaded without errors (${errors.join(" | ") || "none"})`);
check(
  web.boxes.length === cli.length,
  `both draw the same number of tables (${web.boxes.length} and ${cli.length})`,
);
console.log(`  --    the page says: ${status}`);

// The comparison itself, reported as the worst case rather than as a verdict:
// "within 0.1" is only believable next to the number it was within.
let worst = { delta: 0, what: "nothing" };
console.log(
  `  --    ${"table".padEnd(18)}${["Δx", "Δy", "Δw", "Δh"].map((h) => h.padStart(9)).join("")}`,
);
for (const [i, box] of web.boxes.entries()) {
  const reference = cli[i];
  if (!reference) break;
  const deltas = ["x", "y", "w", "h"].map((key) => {
    const delta = box[key] - reference[key];
    if (Math.abs(delta) > worst.delta) {
      worst = {
        delta: Math.abs(delta),
        what: `${web.tables[i]}.${key} (browser ${box[key]}, CLI ${reference[key]})`,
      };
    }
    return delta;
  });
  console.log(
    `  --    ${web.tables[i].padEnd(18)}${deltas.map((d) => d.toFixed(3).padStart(9)).join("")}`,
  );
}
check(
  worst.delta <= TOLERANCE,
  `every box is within ${TOLERANCE} of the CLI's: worst is ${worst.delta.toFixed(4)} at ${worst.what}`,
);

// The edges, the same way. A curve is where two boxes and one routing rule
// meet, so it is the strictest single number in this file: a box can be right
// while an edge leaves from the wrong side of it.
const drawn = web.routes.filter((r) => r.to !== null);
check(
  drawn.length === curves.length,
  `both draw the same number of curves (${drawn.length} and ${curves.length})`,
);
let edge = { delta: 0, what: "nothing" };
for (const [i, route] of drawn.entries()) {
  const reference = curves[i];
  if (!reference) break;
  for (const [j, value] of route.path.entries()) {
    const delta = Math.abs(value - reference[j]);
    if (delta > edge.delta) {
      edge = {
        delta,
        what: `edge ${i} point ${j >> 1}${"xy"[j % 2]} (browser ${value}, CLI ${reference[j]})`,
      };
    }
  }
}
check(
  edge.delta <= TOLERANCE,
  `every edge is within ${TOLERANCE} of the CLI's: worst is ${edge.delta.toFixed(4)} at ${edge.what}`,
);

// ------------------------------------------------- stage b: moving around it
//
// The camera is the one part of the front end with no Rust behind it — D23 puts
// it in the DOM, because the DOM owns the `transform` it becomes. So the
// properties `crates/app/src/camera.rs` has unit tests for are asserted here
// instead, and through real events rather than by calling the methods: a
// correct camera wired to the wrong gesture is still a diagram that fights you.

// Where the diagram is in the page. Since stage c it does not start at the
// origin — the SQL pane has the first 420 px — and a camera coordinate is
// relative to the SVG while a mouse coordinate is relative to the page.
const frame = await page.evaluate(() => {
  const rect = document.getElementById("diagram").getBoundingClientRect();
  return { x: rect.x, y: rect.y, w: rect.width, h: rect.height };
});
const onDiagram = (x, y) => ({ x: frame.x + x, y: frame.y + y });

// The same point twice: where the mouse has to be told to go, and where the
// camera thinks it is. `toWorld` takes a coordinate inside the SVG.
const LOCAL = { x: frame.w / 2, y: frame.h / 2 };
const ANCHOR = onDiagram(LOCAL.x, LOCAL.y);
await page.mouse.move(ANCHOR.x, ANCHOR.y);

// Zooming must leave the diagram under the cursor where it is. Everything else
// feels like the canvas shoving you sideways.
await page.keyboard.down("Control");
const zoomed = await page.evaluate((at) => {
  const before = window.draft.toWorld(at.x, at.y);
  return { before, zoom: window.draft.camera.zoom };
}, LOCAL);
for (let i = 0; i < 5; i += 1) await page.mouse.wheel(0, -100);
const afterZoomIn = await page.evaluate(
  (at) => ({ world: window.draft.toWorld(at.x, at.y), zoom: window.draft.camera.zoom }),
  LOCAL,
);
await page.keyboard.up("Control");
check(afterZoomIn.zoom > zoomed.zoom, `ctrl and the wheel zoom in (${zoomed.zoom} -> ${afterZoomIn.zoom})`);
const drift = Math.hypot(
  afterZoomIn.world.x - zoomed.before.x,
  afterZoomIn.world.y - zoomed.before.y,
);
check(drift < 0.5, `the point under the cursor stayed there while zooming (drifted ${drift.toFixed(3)} pt)`);

// Plain scrolling pans, which is what every other canvas tool does — and the
// two branches must not both fire for one gesture.
const beforePan = await page.evaluate(() => ({ ...window.draft.camera }));
await page.mouse.wheel(0, 240);
const afterPan = await page.evaluate(() => ({ ...window.draft.camera }));
check(afterPan.zoom === beforePan.zoom, `a plain wheel does not zoom (${afterPan.zoom})`);
check(
  afterPan.y > beforePan.y && afterPan.x === beforePan.x,
  `a plain wheel pans along the scroll (y ${beforePan.y.toFixed(1)} -> ${afterPan.y.toFixed(1)})`,
);

// Dragging pans too, and by the distance the pointer moved.
await page.evaluate(() => window.draft.fit());
const dragged = await page.evaluate(() => ({ ...window.draft.camera }));
const from = onDiagram(120, frame.h - 200);
await page.mouse.move(from.x, from.y);
await page.mouse.down();
await page.mouse.move(from.x + 60, from.y, { steps: 4 });
await page.mouse.up();
const afterDrag = await page.evaluate(() => ({ ...window.draft.camera }));
check(
  Math.abs(afterDrag.x - (dragged.x - 60 / dragged.zoom)) < 0.5,
  `a drag moves the diagram with the pointer (${dragged.x.toFixed(1)} -> ${afterDrag.x.toFixed(1)} at zoom ${dragged.zoom.toFixed(3)})`,
);

// Level of detail, at the canvas build's own thresholds, reached through the
// same `geom::Lod`. What matters is not only the name: a block has to actually
// be one element, or "drop detail" dropped nothing.
const detail = await page.evaluate(() => {
  const seen = {};
  // From a known framing, and setting the zoom without moving the origin, so
  // the top-left table stays on screen at every zoom and there is always a
  // group to count.
  window.draft.fit();
  for (const zoom of [1, 0.3, 0.1]) {
    window.draft.camera.zoom = zoom;
    window.draft.render();
    const group = document.querySelector("#tables [data-table]");
    seen[zoom] = { lod: window.draft.lod, children: group?.childElementCount ?? -1 };
  }
  return seen;
});
check(detail[1].lod === "full", `at zoom 1 the tables are drawn in full (${detail[1].lod})`);
check(detail[0.3].lod === "header", `at zoom 0.3 only the header (${detail[0.3].lod})`);
check(detail[0.1].lod === "block", `at zoom 0.1 a plain block (${detail[0.1].lod})`);
check(
  detail[0.1].children === 1 && detail[0.3].children < detail[1].children,
  `dropping detail drops elements (${detail[1].children} -> ${detail[0.3].children} -> ${detail[0.1].children} per table)`,
);

// Culling: what is in the DOM is what is on screen. Zoomed right in, most of
// the sample is off screen and must not be in the document.
const culled = await page.evaluate(() => {
  // Aimed at a table rather than left wherever the previous check finished:
  // a viewport pointing at empty space would hold nothing, and "nothing is in
  // the DOM" is not evidence that culling works.
  const rect = document.getElementById("diagram").getBoundingClientRect();
  const box = window.draft.boxes[0];
  window.draft.camera.zoom = 4;
  window.draft.camera.lookAt(box.x + box.w / 2, box.y + box.h / 2, {
    w: rect.width,
    h: rect.height,
  });
  window.draft.render();
  return { counts: window.draft.counts, inDom: document.querySelectorAll("#tables [data-table]").length };
});
check(
  culled.counts.visible > 0 &&
    culled.counts.visible < web.boxes.length &&
    culled.inDom === culled.counts.visible,
  `zoomed in, only the visible tables are in the DOM (${culled.inDom} of ${web.boxes.length})`,
);

// Focus: a click pins, a click on nothing clears, and hover only counts while
// nothing is pinned.
await page.evaluate(() => window.draft.fit());
const target = await page.evaluate(() => {
  const box = window.draft.boxes[0];
  const at = window.draft.camera.toScreen(box.x + box.w / 2, box.y + 8);
  const rect = document.getElementById("diagram").getBoundingClientRect();
  return { at: { x: at.x + rect.x, y: at.y + rect.y }, name: window.draft.tables[0] };
});
await page.mouse.click(target.at.x, target.at.y);
// Kept as an artefact: the assertions below can tell that the right elements
// are lit, but not that the result is legible.
await page.screenshot({ path: resolve(out, "front-pinned.png") });
const afterClick = await page.evaluate(() => ({
  focused: window.draft.focused,
  pinned: window.draft.pinned,
  lit: document.querySelectorAll("#tables .table.lit").length,
  focusing: document.getElementById("world").classList.contains("focusing"),
  status: document.getElementById("status").textContent,
}));
check(
  afterClick.pinned === target.name && afterClick.focused === 0,
  `a click pins the table it landed on (${afterClick.pinned})`,
);
check(
  afterClick.focusing && afterClick.lit > 1,
  `the pin lights the table and its neighbours (${afterClick.lit} lit)`,
);
// A pin is a decision, so it has to be visible as one somewhere other than in
// the dimming — and you pin the table you are already hovering, which is the
// case where nothing about the focus changed.
check(
  afterClick.status.includes(target.name) && afterClick.status.includes("pinned"),
  `the status line says what is pinned ("${afterClick.status}")`,
);

// A hover elsewhere must not steal the pin: a pin is a decision.
await page.mouse.move(target.at.x + 2, target.at.y + 2);
await page.mouse.move(ANCHOR.x, ANCHOR.y);
const afterHover = await page.evaluate(() => ({
  focused: window.draft.focused,
  pinned: window.draft.pinned,
}));
check(
  afterHover.pinned === target.name && afterHover.focused === 0,
  `hovering elsewhere leaves the pin alone (${afterHover.pinned})`,
);

// And a click on empty space clears it. `fit` leaves a 24 pt margin, so the
// diagram's own top-left corner is outside every box.
const empty = onDiagram(8, 8);
await page.mouse.click(empty.x, empty.y);
const afterClear = await page.evaluate(() => ({
  focused: window.draft.focused,
  pinned: window.draft.pinned,
  focusing: document.getElementById("world").classList.contains("focusing"),
}));
check(
  afterClear.pinned === null && afterClear.focused === null && !afterClear.focusing,
  `a click on nothing clears the pin (${afterClear.pinned}, ${afterClear.focused})`,
);

// ------------------------------------------------------ stage c: the SQL pane
//
// The pane is a `<textarea>` with the colours painted behind it, and the whole
// argument for that (D23) is that selection, copy, IME and the accessibility
// tree arrive from the platform rather than being reimplemented. None of the
// four worked in the canvas build, so each one is asserted here — and asserted
// through the platform, not through our own code: an accessibility tree read
// out of Chrome, a clipboard read back out of the system, a composition
// delivered the way an input method delivers one.

const area = page.locator("#sql");
const document_ = await page.evaluate(() => window.draft.sql);

// The two layers are one text in two colours, so every property that decides
// where a glyph lands has to agree. A tenth of a pixel of padding or one unit
// of line height slides the colours off the characters, further with every
// line — the failure this design is most exposed to, and one that looks like a
// rendering glitch rather than like a bug in a stylesheet.
const layers = await page.evaluate(() => {
  const of = (id) => {
    const s = getComputedStyle(document.getElementById(id));
    return Object.fromEntries(
      [
        "fontFamily",
        "fontSize",
        "fontWeight",
        "lineHeight",
        "letterSpacing",
        "wordSpacing",
        "tabSize",
        "whiteSpace",
        "paddingTop",
        "paddingLeft",
        "borderTopWidth",
        "borderLeftWidth",
      ].map((key) => [key, s[key]]),
    );
  };
  const ink = document.getElementById("ink");
  const sql = document.getElementById("sql");
  return {
    ink: of("ink"),
    sql: of("sql"),
    inkBackground: getComputedStyle(ink).backgroundColor,
    // Which one paints on top. Both are absolutely positioned with `z-index:
    // auto`, so it is document order and nothing else.
    inkOnTop: Boolean(sql.compareDocumentPosition(ink) & Node.DOCUMENT_POSITION_FOLLOWING),
  };
});
const mismatched = Object.keys(layers.ink).filter((key) => layers.ink[key] !== layers.sql[key]);
check(
  mismatched.length === 0,
  `the colours and the characters are laid out identically ` +
    `(${mismatched.join(", ") || "12 properties agree"})`,
);
// The colour layer paints last, so a selection or an IME composition — filled
// rectangles drawn with the textarea — end up behind the text instead of over
// it. The other way round, composing a CJK word is a solid block with nothing
// legible in it.
check(layers.inkOnTop, `the colours paint over the selection and the composition (${layers.inkOnTop})`);
// And it has to be transparent, or it would paint over the caret and the
// selection rather than letting them through.
check(
  layers.inkBackground === "rgba(0, 0, 0, 0)",
  `the colour layer has no background of its own (${layers.inkBackground})`,
);

// A screen reader asks Chrome, so this asks Chrome. The name has to come from
// the label, and `multiline` is what tells a reader to offer line-by-line
// navigation instead of treating 400 KB of SQL as one string.
const cdp = await page.context().newCDPSession(page);
await cdp.send("Accessibility.enable");
const dom = await cdp.send("DOM.getDocument");
const node = await cdp.send("DOM.querySelector", { nodeId: dom.root.nodeId, selector: "#sql" });
const ax = await cdp.send("Accessibility.getPartialAXTree", { nodeId: node.nodeId, fetchRelatives: false });
const box = ax.nodes.find((n) => n.role?.value === "textbox");
const prop = (name) => box?.properties?.find((p) => p.name === name)?.value?.value;
check(
  box?.name?.value === "SQL schema" && box?.role?.value === "textbox",
  `a screen reader finds a named text box (${box?.role?.value} "${box?.name?.value}")`,
);
check(
  prop("multiline") === true && prop("readonly") === false && prop("editable") === "plaintext",
  `and it is a multiline editable one (multiline ${prop("multiline")}, readonly ${prop("readonly")})`,
);
check(
  box?.value?.value?.startsWith(document_.slice(0, 40)),
  `whose value is the schema, not a placeholder (${JSON.stringify(box?.value?.value?.slice(0, 24))}…)`,
);
// The ink layer is a second copy of the same characters, so it must not be in
// the tree at all: a reader that found both would read the schema twice.
const inkNode = await cdp.send("DOM.querySelector", { nodeId: dom.root.nodeId, selector: "#ink" });
const inkAx = await cdp.send("Accessibility.getPartialAXTree", { nodeId: inkNode.nodeId, fetchRelatives: false });
check(
  inkAx.nodes.every((n) => n.ignored === true),
  `the colour layer is ignored by the tree (${inkAx.nodes.length} nodes, ` +
    `${inkAx.nodes.filter((n) => n.ignored).length} ignored)`,
);

// Selection. `Select All` on a text field is the platform's, and it is the one
// that a canvas has no answer to at all.
await area.click();
await page.keyboard.press("ControlOrMeta+a");
const selected = await page.evaluate(() => {
  const el = document.getElementById("sql");
  return { start: el.selectionStart, end: el.selectionEnd, length: el.value.length };
});
check(
  selected.start === 0 && selected.end === selected.length && selected.length > 0,
  `select-all selects the whole script (${selected.start}–${selected.end} of ${selected.length})`,
);

// Copy, verified by reading the system clipboard back rather than by trusting
// that the keystroke went somewhere.
await page.context().grantPermissions(["clipboard-read", "clipboard-write"]);
await page.keyboard.press("ControlOrMeta+c");
const clipboard = await page.evaluate(() => navigator.clipboard.readText());
check(
  clipboard === document_,
  `copy puts the script on the clipboard (${clipboard.length} of ${document_.length} characters)`,
);

// IME. Delivered as Chrome delivers one — a composition that shows in the
// field before it is committed, then a commit — because that is the sequence a
// text field handles for free and a canvas has to reimplement from
// `compositionstart` upwards.
// The caret is put at the end from script rather than with a key, because
// "go to the end of the field" is spelled differently on every platform and
// what is under test here is the composition, not the key binding.
await page.evaluate(() => {
  const el = document.getElementById("sql");
  el.focus();
  el.setSelectionRange(el.value.length, el.value.length);
});
await page.keyboard.type("\n-- ");
await cdp.send("Input.imeSetComposition", { text: "ni hao", selectionStart: 6, selectionEnd: 6 });
const composing = await page.evaluate(() => ({
  value: document.getElementById("sql").value,
  ink: window.draft.ink.text,
}));
// Kept as an artefact because no assertion here can see it: the pre-edit is
// the one thing the transparent-text overlay might swallow.
await page.screenshot({ path: resolve(out, "front-ime.png") });
check(
  composing.value.endsWith("-- ni hao") && composing.ink.endsWith("-- ni hao"),
  `an uncommitted composition shows in the field and in the colours (${JSON.stringify(composing.value.slice(-12))})`,
);
await cdp.send("Input.insertText", { text: "你好" });
const composed = await page.evaluate(() => ({
  value: document.getElementById("sql").value,
  runs: window.draft.ink.runs.slice(-2),
}));
check(
  composed.value.endsWith("-- 你好"),
  `committing replaces the pre-edit with what was composed (${JSON.stringify(composed.value.slice(-8))})`,
);
check(
  composed.runs.some(([cls, text]) => cls === "t-comment" && text.includes("你好")),
  `and the committed text is coloured by the same lexer (${JSON.stringify(composed.runs.at(-1))})`,
);

// Only the visible lines are in the ink layer, which is what makes a keystroke
// cost the same in a 400 KB script as in a 4 KB one — the virtualisation
// Phase 3a's trigger was held in reserve for. The invariant is exact: the ink
// is a verbatim run of the document's characters starting at a line boundary.
const offsetOf = (text, line) =>
  text.split("\n").slice(0, line).reduce((n, l) => n + l.length + 1, 0);
// A scroll event is dispatched during the rendering step, not when the offset
// is assigned, so the repaint it triggers is a frame away. Back to the top
// first: typing at the end above scrolled the field to follow the caret, which
// is a text field doing its job.
const scrollTo = (to) =>
  page.evaluate((offset) => {
    document.getElementById("sql").scrollTop = offset;
    return new Promise((done) => requestAnimationFrame(() => requestAnimationFrame(done)));
  }, to);

await scrollTo(0);
const top = await page.evaluate(() => ({ ink: window.draft.ink, sql: window.draft.sql }));
check(
  top.ink.first === 0 && top.sql.startsWith(top.ink.text) && top.ink.text.length < top.sql.length,
  `at the top the ink is the first ${top.ink.count} lines from line ${top.ink.first} and no more ` +
    `(${top.ink.text.length} of ${top.sql.length} characters)`,
);
await scrollTo(1e6);
const bottom = await page.evaluate(() => ({ ink: window.draft.ink, sql: window.draft.sql }));
check(
  bottom.ink.first > 0 &&
    bottom.sql.slice(offsetOf(bottom.sql, bottom.ink.first)).startsWith(bottom.ink.text),
  `scrolled to the end the window moved with it and still lines up (line ${bottom.ink.first})`,
);
await scrollTo(0);

// And typing re-runs the whole pipeline without throwing the reader out of the
// diagram. The insert goes in at the *top*, so every table is renumbered: a pin
// held as an index would silently land on the wrong table, which is why D12
// holds it as a name.
// Recomputed rather than reused: the composition above was an edit, and an
// edit re-runs the layout.
const repin = await page.evaluate(() => {
  const b = window.draft.boxes[0];
  const at = window.draft.camera.toScreen(b.x + b.w / 2, b.y + 8);
  const rect = document.getElementById("diagram").getBoundingClientRect();
  return { at: { x: at.x + rect.x, y: at.y + rect.y }, name: window.draft.tables[0] };
});
await page.mouse.click(repin.at.x, repin.at.y);
const before = await page.evaluate(() => ({
  camera: { ...window.draft.camera },
  pinned: window.draft.pinned,
  focused: window.draft.focused,
  tables: window.draft.tables.length,
}));
check(before.pinned === repin.name, `re-pinned for the typing check (${before.pinned})`);
await page.evaluate(() => {
  const el = document.getElementById("sql");
  el.focus();
  el.setSelectionRange(0, 0);
});
await page.keyboard.type("CREATE TABLE zzz_probe (id int PRIMARY KEY);\n");
await page.waitForFunction(
  (was) => window.draft.tables.length === was + 1,
  before.tables,
  { timeout: 5_000 },
);
const after = await page.evaluate(() => ({
  camera: { ...window.draft.camera },
  pinned: window.draft.pinned,
  focused: window.draft.focused,
  first: window.draft.tables[0],
  focusedName: window.draft.tables[window.draft.focused],
}));
check(
  after.first === "zzz_probe" && after.focused !== before.focused,
  `typing at the top re-parses and renumbers the tables (table 0 is now ${after.first})`,
);
check(
  after.focusedName === repin.name && after.pinned === repin.name,
  `the pin is still on the table it was put on (${after.focusedName}, index ${before.focused} -> ${after.focused})`,
);
check(
  after.camera.x === before.camera.x &&
    after.camera.y === before.camera.y &&
    after.camera.zoom === before.camera.zoom,
  `and the camera did not move (${after.camera.x.toFixed(1)}, ${after.camera.y.toFixed(1)} at ${after.camera.zoom.toFixed(3)})`,
);

// And the tables did not move either. This is the one that has to be checked
// end to end rather than in the wasm's own tests: the placement lives in the
// `Session`, so it survives an edit only for as long as the front end reuses
// the session instead of constructing a new one, and nothing in Rust can tell
// the difference. Before it did, widening one column moved 8 of 9 tables.
const wider = await page.evaluate(async () => {
  const positions = () =>
    Object.fromEntries(window.draft.tables.map((name, i) => [name, window.draft.boxes[i]]));
  const was = positions();
  const el = document.getElementById("sql");
  el.focus();
  const at = el.value.indexOf("display_name");
  el.setSelectionRange(at, at + "display_name".length);
  document.execCommand("insertText", false, "a_very_much_longer_column_name_indeed");
  await new Promise((done) => setTimeout(done, 600));
  const now = positions();
  let moved = 0;
  let worst = 0;
  for (const [name, box] of Object.entries(was)) {
    if (!now[name]) continue;
    const delta = Math.hypot(now[name].x - box.x, now[name].y - box.y);
    if (delta > 0.01) moved += 1;
    worst = Math.max(worst, delta);
  }
  return { moved, worst, tables: Object.keys(was).length, width: now.customers?.w };
});
check(
  wider.moved === 0,
  `widening a column moves no existing table (${wider.moved} of ${wider.tables}, worst ${wider.worst.toFixed(2)} pt)`,
);

await browser.close();
close();
check(errors.length === 0, `nothing errored while being driven (${errors.join(" | ") || "none"})`);


console.log(
  failures.length === 0
    ? `\nfront geometry: PASSED — ${web.boxes.length} tables and ${drawn.length} edges, ` +
      `worst divergence ${Math.max(worst.delta, edge.delta).toFixed(4)} points`
    : `\nfront geometry: FAILED\n  ${failures.join("\n  ")}`,
);
process.exit(failures.length === 0 ? 0 : 1);
