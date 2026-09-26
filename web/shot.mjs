// Screenshot the web application, for looking at.
//
// A frame-cost number says the canvas is fast; it says nothing about whether
// the fonts registered, the theme reads, or the diagram is where it should be.
// This is the cheapest way to see that, and it runs the shipped bundle rather
// than a debug build.
//
// Run: make shots   (or: node web/shot.mjs [out-dir])

import { createRequire } from "node:module";
import { mkdir } from "node:fs/promises";
import { resolve } from "node:path";
import { fileURLToPath } from "node:url";

import { serveDist } from "./serve.mjs";

const HERE = fileURLToPath(new URL(".", import.meta.url));
const require = createRequire(resolve(HERE, "../.scratch/browser/package.json"));
const { chromium } = require("playwright");

const outDir = resolve(process.cwd(), process.argv[2] ?? ".scratch/shots");
await mkdir(outDir, { recursive: true });

const { port, close } = await serveDist();
const browser = await chromium.launch({ channel: "chrome", headless: false });
const context = await browser.newContext({
  viewport: { width: 1400, height: 900 },
  deviceScaleFactor: 2,
});
const page = await context.newPage();
await page.goto(`http://127.0.0.1:${port}/`);
await page.waitForFunction(() => !document.getElementById("loading"), null, { timeout: 60_000 });
// Two frames' grace so the fit-to-view has run and the first layout is drawn.
await page.waitForTimeout(600);

async function shot(name) {
  const file = resolve(outDir, `${name}.png`);
  await page.screenshot({ path: file });
  console.log(`  ${file}`);
}

await shot("01-dark-fit");

// Typing into the editor: the highlighting, the debounced re-parse, and the
// half-typed statement that must not blank the diagram. Driven with real input
// because egui owns the whole canvas — there is no DOM to query for a button.
await page.mouse.click(200, 400);
await page.keyboard.press("Control+End");
await page.keyboard.type("\nCREATE TABLE shipments (\n  id bigint PRIMARY KEY,\n", {
  delay: 25,
});
await page.waitForTimeout(500);
await shot("05-editor-mid-statement");
await page.keyboard.type("  order_id bigint REFERENCES orders(id)\n);\n", { delay: 25 });
await page.waitForTimeout(700);
await shot("06-editor-complete");

// Hover a table: its relationships should stand out and everything unrelated
// should fade. Then click to pin it, so the focus survives the pointer moving.
// The `products` box, which has four relationships and so shows the most.
// Hard-coded because egui owns the canvas: there is no DOM node to locate.
const table = { x: 874, y: 566 };
await page.mouse.move(table.x, table.y);
await page.waitForTimeout(300);
await shot("07-hover-focus");
await page.mouse.click(table.x, table.y);
await page.mouse.move(1700, 820);
await page.waitForTimeout(300);
await shot("08-pinned-focus");
await page.keyboard.press("Escape");
await page.waitForTimeout(200);

// Drag that table somewhere else. Its edges must follow it, and the tables it
// is not connected to must not move at all.
const moved = { x: table.x + 260, y: table.y + 300 };
await page.mouse.move(table.x, table.y);
await page.mouse.down();
for (const step of [0.25, 0.5, 0.75, 1]) {
  await page.mouse.move(table.x + 260 * step, table.y + 300 * step);
  await page.waitForTimeout(40);
}
await page.mouse.up();
await page.waitForTimeout(300);
await shot("09-dragged");

// Drag it back rather than pressing Arrange. Everything below addresses the
// diagram by screen position, and a re-arrange is entitled to move the other
// nine tables as well.
await page.waitForTimeout(400);
await page.mouse.down();
for (const step of [0.5, 1]) {
  await page.mouse.move(moved.x - 260 * step, moved.y - 300 * step);
  await page.waitForTimeout(40);
}
await page.mouse.up();
await page.waitForTimeout(400);

// Editing the schema through the diagram. Zoom in on the header first: below
// the detail threshold there is no text on screen to point at, and the field
// would open too small to read. Zooming is anchored at the pointer, so the
// header stays under it.
const header = { x: table.x, y: table.y - 52 };
await page.keyboard.press("Escape");
await page.mouse.move(header.x, header.y);
for (let i = 0; i < 2; i += 1) {
  await page.keyboard.down("Control");
  await page.mouse.wheel(0, -120);
  await page.keyboard.up("Control");
  await page.waitForTimeout(80);
}
await page.waitForTimeout(300);
await shot("10-before-inline");

// Double-click the header to rename the table, and watch the SQL change.
await page.mouse.dblclick(header.x, header.y);
await page.waitForTimeout(300);
await shot("11-inline-open");
await page.keyboard.press("Control+A");
await page.keyboard.type("catalogue_items", { delay: 20 });
await page.keyboard.press("Enter");
await page.waitForTimeout(600);
await shot("12-inline-committed");

// Right-click for the menu that adds a column.
await page.mouse.click(header.x, header.y, { button: "right" });
await page.waitForTimeout(300);
await shot("13-context-menu");
await page.keyboard.press("Escape");
await page.waitForTimeout(200);

// Back to a known state for the theme and sharpness shots.
await page.keyboard.press("Escape");
await page.keyboard.press("f");
await page.waitForTimeout(400);

// Zoom in on the middle of the diagram, which is where text sharpness shows.
await page.mouse.move(900, 500);
for (let i = 0; i < 8; i += 1) {
  await page.keyboard.down("Control");
  await page.mouse.wheel(0, -120);
  await page.keyboard.up("Control");
  await page.waitForTimeout(60);
}
await page.waitForTimeout(300);
await shot("02-dark-zoomed");

// The toolbar's rightmost button is the theme toggle.
await page.mouse.click(1328, 16);
await page.waitForTimeout(400);
await shot("03-light-zoomed");

await page.keyboard.press("f");
await page.waitForTimeout(500);
await shot("04-light-fit");

await context.close();
await browser.close();
close();
