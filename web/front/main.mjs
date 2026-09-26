// The DOM front end: measure, place, draw, and let you move around it.
//
// What this file is allowed to know is the point of the exercise. It measures
// text, because only a browser can; it owns the camera, because it owns the
// `transform` the camera becomes (D23); and it turns numbers into SVG
// elements. Every *rule* — how wide a box is, which badge a column has earned,
// where the boxes go, where an edge runs, how much detail is worth drawing at
// this zoom — comes from the wasm, which is the same code the CLI runs
// (docs/architecture.md D19, D23). If a table here is a pixel away from
// `draft render`'s SVG, one of the two is wrong, and web/front-check.mjs is
// what says which.
//
// The scene is incremental on purpose. A thousand tables is tens of thousands
// of SVG nodes, so what is in the DOM is what is on screen: pan and zoom move
// one `transform`, and tables and edges are built as they come into view and
// dropped as they leave. That is D23's "the DOM holds only where the camera is
// pointing", and it is what the 1,000-table gate measures.

import init, { Session } from "./draft_front.js";
import { Camera, overlaps } from "./camera.mjs";
import { drawEdge, drawTable, edgeBounds, el } from "./draw.mjs";
import { editor } from "./editor.mjs";
import { loadFonts, measureAll } from "./measure.mjs";

const svg = document.getElementById("diagram");
const statusLine = document.getElementById("status");

/// How long the text has to stand still before the diagram follows it, in
/// milliseconds. `crates/app/src/editor.rs`'s `DEBOUNCE`, which was picked
/// against the same fixtures this front end is measured on: short enough that a
/// pause between words redraws, long enough that a re-parse never lands on the
/// frame after a keystroke.
const DEBOUNCE = 180;

/// Edges first, so they pass under the boxes rather than over their text. The
/// canvas build stacks them the same way, in `shapes()`.
const world = el("g", { id: "world" });
const edgeLayer = el("g", { id: "edges" });
const tableLayer = el("g", { id: "tables" });
world.append(edgeLayer, tableLayer);
svg.append(world);

const camera = new Camera();

/// The parse and everything derived from it. Replaced wholesale when the script
/// changes, which in this stage happens once at load and once per bench run.
let scene = null;

/// What is in the DOM right now: index -> { el, lod, nodes }. The node count
/// rides along because the bench reports the peak, and counting the document
/// per frame would cost more than the frame.
const liveTables = new Map();
const liveEdges = new Map();
let nodeCount = 0;

/// The table a click pinned, **by name**: a re-parse renumbers every table, and
/// a pin that silently moved to a different table would be worse than one that
/// disappeared. The canvas build holds it the same way, for the same reason.
let pinned = null;
let hovered = null;
/// The focused table and everything one edge away from it. Consulted by the
/// build loop, so a table scrolling into view arrives already lit.
let related = new Set();
let focused = null;

let currentLod = "full";
let pendingFrame = false;

/// The SQL pane, once the fonts are up. The bench types into it.
let pane = null;
/// What the last re-parse cost, for the typing gate to collect. Cleared when
/// read, so a settle is counted once and a run with a broken debounce reports
/// an empty bucket rather than a wrong one — the reason `TypingBench::tick`
/// takes the settle as an `Option` instead of reading it back.
let lastSettle = null;

function viewport() {
  const rect = svg.getBoundingClientRect();
  return { w: rect.width, h: rect.height };
}

/// Ask for a frame. Nothing renders unless something changed — an idle diagram
/// costs nothing here, which is not true of a canvas that repaints to a clock.
function requestRender() {
  if (pendingFrame) return;
  pendingFrame = true;
  requestAnimationFrame(() => {
    pendingFrame = false;
    render();
  });
}

/// Build what is on screen, drop what is not, and move the transform.
function render() {
  if (!scene) return;
  const view = camera.visibleWorld(viewport());
  const lod = scene.session.lod(camera.zoom);
  world.setAttribute("transform", camera.transform());

  let visible = 0;
  for (let i = 0; i < scene.boxes.length; i += 1) {
    if (!overlaps(scene.boxes[i], view)) continue;
    visible += 1;
    const live = liveTables.get(i);
    if (live && live.lod === lod) continue;
    if (live) drop(liveTables, i);
    const node = drawTable(scene.schema.tables[i], scene.boxes[i], scene.metrics, lod, i);
    if (related.has(i)) node.classList.add("lit");
    tableLayer.append(node);
    add(liveTables, i, node, lod);
  }
  for (const [i] of liveTables) {
    if (!overlaps(scene.boxes[i], view)) drop(liveTables, i);
  }

  for (let i = 0; i < scene.routes.length; i += 1) {
    if (!overlaps(scene.bounds[i], view)) continue;
    const live = liveEdges.get(i);
    if (live && live.lod === lod) continue;
    if (live) drop(liveEdges, i);
    const node = drawEdge(scene.routes[i], lod);
    if (litEdge(scene.routes[i])) node.classList.add("lit");
    edgeLayer.append(node);
    add(liveEdges, i, node, lod);
  }
  for (const [i] of liveEdges) {
    if (!overlaps(scene.bounds[i], view)) drop(liveEdges, i);
  }

  currentLod = lod;
  scene.visible = visible;
  scene.peakVisible = Math.max(scene.peakVisible, visible);
  scene.peakNodes = Math.max(scene.peakNodes, nodeCount);
}

function add(live, i, node, lod) {
  const nodes = 1 + node.childElementCount;
  live.set(i, { el: node, lod, nodes });
  nodeCount += nodes;
}

function drop(live, i) {
  const held = live.get(i);
  if (!held) return;
  held.el.remove();
  nodeCount -= held.nodes;
  live.delete(i);
}

/// Dim everything but one table and its neighbours.
///
/// A class rather than a veil drawn over the diagram: the canvas build paints a
/// translucent rectangle and then redraws the neighbourhood on top of it,
/// because a painter has no other way to say "everything except these". The DOM
/// does, and it costs one class per element instead of a second copy of every
/// shape.
function focus(index) {
  if (index === focused) return;
  focused = index;
  related = new Set();
  if (index !== null) {
    related.add(index);
    for (const route of scene.routes) {
      if (route.from === index && route.to !== null) related.add(route.to);
      if (route.to === index) related.add(route.from);
    }
  }
  world.classList.toggle("focusing", index !== null);
  for (const [i, held] of liveTables) {
    held.el.classList.toggle("lit", related.has(i));
  }
  for (const [i, held] of liveEdges) {
    held.el.classList.toggle("lit", litEdge(scene.routes[i]));
  }
}

/// An edge is lit when it *touches* the focused table. Not when it happens to
/// join two of its neighbours: that would draw a triangle around a hub and say
/// something about the schema that is not true.
function litEdge(route) {
  return focused !== null && (route.from === focused || route.to === focused);
}

function showStatus() {
  if (!scene) return;
  const { schema, dialect } = scene;
  const parts = [
    `${schema.tables.length} ${schema.tables.length === 1 ? "table" : "tables"}`,
    `${schema.relations.length} ${schema.relations.length === 1 ? "relation" : "relations"}`,
  ];
  if (dialect) parts.push(dialect);
  if (focused !== null) {
    const name = schema.tables[focused].name;
    parts.push(pinned === null ? name : `${name} — pinned`);
  }
  statusLine.textContent = parts.join(" · ");
}

/// Re-resolve the pin against the schema in front of us, dropping it if the
/// table it named is gone. Index, not name, from here on.
function pinnedIndex() {
  if (pinned === null) return null;
  const at = scene.schema.tables.findIndex((t) => t.name === pinned);
  if (at < 0) pinned = null;
  return at < 0 ? null : at;
}

/// Hover only counts when nothing is pinned: a pin is a decision, and having it
/// evaporate because the pointer drifted over a neighbour is the opposite of
/// what pinning is for.
function refocus() {
  const at = pinnedIndex();
  focus(at !== null ? at : hovered);
  // Outside `focus`, which does nothing when the focused table has not
  // changed — and pinning usually does not change it. You have to hover a
  // table to click it, so the pin lands on the table already in focus, and a
  // status line updated inside `focus` would never have said "pinned".
  showStatus();
}

// ---------------------------------------------------------------- the gestures

/// Which table is under a pointer event, or null. The DOM hit-tests for free —
/// the thing a canvas has to do arithmetic for — so this is a tree walk and not
/// a geometry problem.
function tableUnder(event) {
  const hit = event.target.closest?.("[data-table]");
  return hit === null || hit === undefined ? null : Number(hit.dataset.table);
}

/// Wheel deltas arrive in pixels, lines or pages depending on the device.
const LINE = 16;
const PAGE = 100;
function wheelPixels(event) {
  const scale = event.deltaMode === 1 ? LINE : event.deltaMode === 2 ? PAGE : 1;
  return { x: event.deltaX * scale, y: event.deltaY * scale };
}

svg.addEventListener(
  "wheel",
  (event) => {
    // Chrome delivers a trackpad pinch as a wheel event with `ctrlKey` set,
    // which is also the keyboard modifier for zoom — so the two spellings of
    // "zoom" arrive as one branch, and plain scrolling pans. egui splits the
    // same gesture the same way (`zoom_delta` takes its delta out of the
    // scroll), so the two builds behave alike.
    event.preventDefault();
    const delta = wheelPixels(event);
    const rect = svg.getBoundingClientRect();
    if (event.ctrlKey || event.metaKey) {
      camera.zoomAbout(
        Math.exp(-delta.y * 0.002),
        event.clientX - rect.left,
        event.clientY - rect.top,
      );
    } else {
      camera.pan(-delta.x, -delta.y);
    }
    requestRender();
  },
  { passive: false },
);

/// Pointers currently down, by id. Two of them is a pinch; one is a pan.
const down = new Map();
/// How far the gesture has travelled, so a press that barely moved is a click.
/// egui's own threshold, in CSS pixels.
const CLICK_SLOP = 6;
let travelled = 0;
/// What the press went down on. Settled once, at `pointerdown`, for two
/// reasons: `setPointerCapture` retargets every later event in the gesture to
/// the SVG, so the release has no idea what is under it — and even without
/// that, a quick flick travels far enough that the pointer is outside the box
/// it grabbed by the time the button comes up. The canvas build settles it at
/// the press for the second reason alone.
let pressedTable = null;

function centreOf(points) {
  let x = 0;
  let y = 0;
  for (const p of points) {
    x += p.x;
    y += p.y;
  }
  return { x: x / points.length, y: y / points.length };
}

function spreadOf(points) {
  return Math.hypot(points[0].x - points[1].x, points[0].y - points[1].y);
}

svg.addEventListener("pointerdown", (event) => {
  const rect = svg.getBoundingClientRect();
  down.set(event.pointerId, {
    x: event.clientX - rect.left,
    y: event.clientY - rect.top,
    spread: null,
  });
  if (down.size === 1) {
    travelled = 0;
    pressedTable = tableUnder(event);
  }
  if (down.size === 2) {
    // Entering a pinch: remember the current spread so the first move scales
    // from it rather than from nothing.
    const points = [...down.values()];
    for (const p of down.values()) p.spread = spreadOf(points);
  }
  svg.setPointerCapture(event.pointerId);
  svg.classList.add("dragging");
});

svg.addEventListener("pointermove", (event) => {
  const held = down.get(event.pointerId);
  const rect = svg.getBoundingClientRect();
  const at = { x: event.clientX - rect.left, y: event.clientY - rect.top };

  if (!held) {
    // No button down: this is hover, and hover is a focus decision.
    const under = tableUnder(event);
    if (under !== hovered) {
      hovered = under;
      refocus();
    }
    return;
  }

  const previous = { x: held.x, y: held.y };
  held.x = at.x;
  held.y = at.y;
  travelled += Math.hypot(at.x - previous.x, at.y - previous.y);

  if (down.size >= 2) {
    // A two-finger gesture is a zoom and nothing else. The canvas build had to
    // learn this the hard way (D22): the primary finger of a pinch looks
    // exactly like a one-finger pan, so a pinch that also panned would drag
    // the diagram out from under the fingers doing the zooming.
    const points = [...down.values()];
    const spread = spreadOf(points);
    const was = held.spread ?? spread;
    if (was > 0 && spread > 0) {
      const middle = centreOf(points);
      camera.zoomAbout(spread / was, middle.x, middle.y);
    }
    for (const p of down.values()) p.spread = spread;
    requestRender();
    return;
  }

  camera.pan(at.x - previous.x, at.y - previous.y);
  requestRender();
});

function release(event) {
  if (!down.has(event.pointerId)) return;
  down.delete(event.pointerId);
  if (down.size === 0) {
    svg.classList.remove("dragging");
    // A click, not a drag: pin what was pressed, or clear the pin when the
    // press landed on nothing.
    if (travelled <= CLICK_SLOP) {
      pinned = pressedTable === null ? null : scene.schema.tables[pressedTable].name;
      hovered = pressedTable;
      refocus();
    }
    pressedTable = null;
  } else if (down.size === 1) {
    // One finger left of a pinch. Its stored spread belongs to a gesture that
    // no longer exists, and keeping it would make the next move jump.
    for (const p of down.values()) p.spread = null;
  }
}

svg.addEventListener("pointerup", release);
svg.addEventListener("pointercancel", release);
// Only hover is ended here. A drag that leaves the element is still a drag —
// pointer capture keeps delivering its moves, and `pointerup` ends it.
svg.addEventListener("pointerleave", () => {
  if (down.size === 0 && hovered !== null) {
    hovered = null;
    refocus();
  }
});

// The camera frames the diagram against the viewport, so a resized window is a
// changed camera and not just a changed clip.
new ResizeObserver(() => requestRender()).observe(svg);

// ------------------------------------------------------------------- the scene

/// Everything derived from one script, in the order the derivation runs.
///
/// Timed in the buckets `Cost` uses (`crates/app/src/document.rs`) plus the
/// three this build has and the canvas build does not, so a slow settle says
/// which stage to go and look at rather than only that it was slow. `json` is
/// getting the schema back across the wasm boundary, `routes` is asking for the
/// edge geometry and `draw` is rebuilding the visible elements — all three are
/// things the canvas build does inside the frame that draws them, paying no
/// crossing for any of them.
function build(sql, previous) {
  const t0 = performance.now();
  // The session is reused across edits, and that is not an optimisation: it
  // holds the placement, so a table that already existed keeps its place
  // (D11). A fresh session is a fresh document, which is what `load` means.
  const session = previous ?? new Session(sql);
  if (previous) session.reparse(sql);
  const t1 = performance.now();
  const schema = JSON.parse(session.schema_json());
  const metrics = JSON.parse(session.metrics_json());
  const t2 = performance.now();
  const sizes = measureAll(schema);
  const t3 = performance.now();
  const placed = session.place(sizes, false, 1);
  const boxes = schema.tables.map((_, i) => ({
    x: placed[i * 4],
    y: placed[i * 4 + 1],
    w: placed[i * 4 + 2],
    h: placed[i * 4 + 3],
  }));
  const t4 = performance.now();
  const routes = JSON.parse(session.routes_json(placed));
  const t5 = performance.now();

  // The whole diagram, edges included: a stub off the side of a table reaches
  // further than the table does, and `fit` must not crop the one edge saying
  // "this points somewhere missing".
  const bounds = routes.map(edgeBounds);
  let content = boxes[0] ?? { x: 0, y: 0, w: 0, h: 0 };
  for (const b of [...boxes, ...bounds]) {
    const right = Math.max(content.x + content.w, b.x + b.w);
    const bottom = Math.max(content.y + content.h, b.y + b.h);
    content = {
      x: Math.min(content.x, b.x),
      y: Math.min(content.y, b.y),
      w: right - Math.min(content.x, b.x),
      h: bottom - Math.min(content.y, b.y),
    };
  }

  return {
    session,
    schema,
    metrics,
    boxes,
    routes,
    bounds,
    content,
    dialect: session.dialect(),
    cost: {
      parse: t1 - t0,
      json: t2 - t1,
      measure: t3 - t2,
      layout: t4 - t3,
      routes: t5 - t4,
    },
    visible: 0,
    peakVisible: 0,
    peakNodes: 0,
  };
}

/// Replace the scene. Everything in the DOM goes first: a re-parse re-runs the
/// layout, so table 4 is not where table 4 was and there is nothing to keep.
///
/// The pin survives because it is held as a *name* (D12). Re-resolving it here
/// is the whole payoff: you pin a table, keep typing, and the highlight is
/// still on the table you pinned rather than on whatever ended up in its slot.
function rebuild(sql, previous) {
  liveTables.forEach((_, i) => drop(liveTables, i));
  liveEdges.forEach((_, i) => drop(liveEdges, i));
  scene = build(sql, previous);
  // These are indices into the parse that just went away.
  focused = null;
  hovered = null;
  related = new Set();
  refocus();
}

/// A script arriving from outside — the sample, a file, a share link. The
/// camera frames it and the pin has nothing to do with it.
function load(sql) {
  pinned = null;
  rebuild(sql);
  camera.fit(scene.content, viewport(), 24);
  render();
}

/// The same script, edited. The camera stays exactly where it is: the diagram
/// jumping back to a fit on every pause in the typing would make the pane
/// unusable for editing one corner of a large schema.
function reparse(sql) {
  const started = performance.now();
  rebuild(sql, scene.session);
  const built = performance.now();
  render();
  const finished = performance.now();
  lastSettle = { ...scene.cost, render: finished - built, total: finished - started };
}

// -------------------------------------------------------------------- the gate

/// p50/p95/p99/max over a sample, after dropping the warm-up.
///
/// `Stats::new(frames, 30)` on the Rust side drops the same first thirty
/// frames, and for the same reason: the first frames of a run build every
/// element from nothing, which is a load and not a pan.
const WARMUP = 30;
function stats(samples, warmup = WARMUP) {
  const kept = samples.slice(warmup).sort((a, b) => a - b);
  if (kept.length === 0) return "n=0";
  const at = (q) => kept[Math.min(kept.length - 1, Math.floor(q * kept.length))];
  return (
    `n=${kept.length} p50=${at(0.5).toFixed(2)}ms p95=${at(0.95).toFixed(2)}ms ` +
    `p99=${at(0.99).toFixed(2)}ms max=${kept[kept.length - 1].toFixed(2)}ms`
  );
}

/// The frame-cost gate for stage b, driven the way `CanvasBench` drives the
/// canvas build's: a deterministic sweep from "reading one table" out to "the
/// whole schema framed", so every zoom level and every level-of-detail bucket
/// is visited exactly once and the worst case is reached rather than hoped for.
///
/// Two numbers come back, because they answer different questions. `work` is
/// the time inside the frame callback — culling, building and dropping
/// elements, which is what this code controls and the analogue of the canvas
/// build's `cpu_usage`. `frame` is the interval between frames, which includes
/// the browser's own style, layout and paint of the SVG, and is the number that
/// says whether the page actually kept up.
window.draftBench = async (sql, frames) => {
  load(sql);
  const size = viewport();
  const content = scene.content;
  const work = [];
  const intervals = [];
  let last = null;

  for (let frame = 0; frame < frames; frame += 1) {
    await new Promise((resolve) => requestAnimationFrame(resolve));
    const now = performance.now();
    if (last !== null) intervals.push(now - last);
    last = now;

    const progress = frames <= 1 ? 1 : frame / (frames - 1);
    const fit = Math.min(size.w / Math.max(content.w, 1), size.h / Math.max(content.h, 1)) * 0.98;
    camera.zoom = Math.min(Math.max(1.2 * (1 - progress) + fit * progress, 0.02), 4);
    // Orbit around the middle so the framing stays centred as the zoom pulls
    // back, and so panning is exercised alongside zooming.
    const t = progress * 12;
    camera.lookAt(
      content.x + content.w / 2 + Math.sin(t) * content.w * 0.1,
      content.y + content.h / 2 + Math.cos(t * 0.8) * content.h * 0.1,
      size,
    );

    const started = performance.now();
    render();
    work.push(performance.now() - started);
  }

  return (
    `front ${String(scene.schema.tables.length).padStart(5)} tables  ` +
    `view ${size.w.toFixed(0)}x${size.h.toFixed(0)}  ` +
    `peak visible ${String(scene.peakVisible).padStart(5)}  ` +
    `peak nodes ${String(scene.peakNodes).padStart(6)}  ` +
    `work ${stats(work)}  frame ${stats(intervals)}`
  );
};

/// Keystrokes in one burst, and the pause after it. `TypingBench`'s own
/// `BURST`, and a pause long enough for the thing that hangs off it to land.
///
/// That thing is shorter here: the canvas build's pause has to outlast its text
/// mirror at 500 ms, and this front end has no mirror — the schema is in the
/// page as text already. So the pause is the debounce plus two frames of
/// margin, which means *more* settles per run than the canvas bench gets, not
/// fewer.
const BURST = 30;
const PAUSE = DEBOUNCE + 2 * (1000 / 60);

/// Slicing between the halves of a surrogate pair would leave a lone surrogate
/// in the document. `TypingBench::keystroke` walks back off a byte that is not
/// a char boundary for the same reason; a JS string is indexed in UTF-16, so
/// here the hazard is a pair rather than a multi-byte sequence.
function boundary(text, i) {
  const at = Math.min(i, text.length);
  const code = text.charCodeAt(at);
  return code >= 0xdc00 && code <= 0xdfff ? at - 1 : at;
}

/// The typing gate, driven the way `TypingBench` drives the canvas build's.
///
/// A keystroke on every frame is the worst case for the editor, and the pause
/// after each burst is what lets the debounced re-parse actually happen — a run
/// that only typed would report that typing is cheap while hiding the re-parse
/// completely.
///
/// Three numbers come back, measuring three different things:
///
/// * `typing` is the time inside the `input` handler: one paint of the visible
///   lines. This is the number Phase 3a's trigger is about, and the reason it
///   should not grow with the document.
/// * `settle` is the debounced re-parse, re-measure, re-layout and re-render,
///   broken into its stages. The canvas build's equivalent bucket.
/// * `frame` is the interval between frames, which includes the browser's own
///   style, layout and paint — whether the page kept up while all this ran.
window.draftTypeBench = async (sql, frames) => {
  const area = document.getElementById("sql");
  pane.setText(sql);
  load(sql);
  lastSettle = null;
  // `execCommand` acts on the focused element, and the keystrokes below are
  // meant for this one.
  area.focus();

  const typing = [];
  const settle = [];
  const parse = [];
  const json = [];
  const measure = [];
  const layout = [];
  const routed = [];
  const drawn = [];
  const intervals = [];
  const at = boundary(sql, 200);
  let inserted = false;
  let typed = 0;
  let pausedAt = null;
  let last = null;

  /// Edit near the top of the document: everything after the caret may have to
  /// move, so it is the worst case for the parser and the layout both. The
  /// insert and the remove alternate, so the document's length — and therefore
  /// what it costs to work on — stays constant across a long run.
  ///
  /// `execCommand` rather than assigning `value`, and it is the difference
  /// between measuring a keystroke and measuring a paste: assigning replaces
  /// the whole document, which makes the browser lay out all 396 KB of it and
  /// charges that to the keystroke. This inserts one character at the caret,
  /// which is what a key does — and it dispatches the real `input` event, so
  /// the editor's own handler runs rather than a copy of it that skips the part
  /// that turned out to be slow. Deprecated, and there is no replacement for
  /// "type this, as a user": `beforeinput` is observable but not injectable.
  const keystroke = () => {
    if (inserted) {
      area.setSelectionRange(at, at + 1);
      document.execCommand("delete");
    } else {
      area.setSelectionRange(at, at);
      document.execCommand("insertText", false, "x");
    }
    inserted = !inserted;
  };

  for (let frame = 0; frame < frames; frame += 1) {
    await new Promise((resolve) => requestAnimationFrame(resolve));
    const now = performance.now();
    if (last !== null) intervals.push(now - last);
    last = now;

    // A settle runs off a timer, so it has already happened by the time this
    // frame starts; what is left is to attribute it.
    if (lastSettle !== null) {
      settle.push(lastSettle.total);
      parse.push(lastSettle.parse);
      json.push(lastSettle.json);
      measure.push(lastSettle.measure);
      layout.push(lastSettle.layout);
      // Reported apart from the three stages the canvas build reports, because
      // neither has a counterpart there: it works the edge geometry out inside
      // the frame that draws it, and a repaint of a canvas rebuilds no
      // elements.
      routed.push(lastSettle.routes);
      drawn.push(lastSettle.render);
      lastSettle = null;
    }

    if (pausedAt !== null && now - pausedAt >= PAUSE) {
      pausedAt = null;
      typed = 0;
    }
    if (pausedAt === null) {
      const started = performance.now();
      keystroke();
      typing.push(performance.now() - started);
      typed += 1;
      if (typed >= BURST) pausedAt = now;
    }
  }

  const kb = Math.round(sql.length / 1024);
  const p = (samples, q) => {
    const kept = samples.slice(1).sort((a, b) => a - b);
    if (kept.length === 0) return 0;
    return kept[Math.min(kept.length - 1, Math.floor(q * kept.length))];
  };
  return (
    `editor ${String(kb).padStart(4)} KB  typing ${stats(typing, 20)}  ` +
    `settle n=${Math.max(settle.length - 1, 0)} ` +
    `p50=${p(settle, 0.5).toFixed(2)}ms max=${p(settle, 1).toFixed(2)}ms ` +
    `[parse ${p(parse, 0.5).toFixed(2)} json ${p(json, 0.5).toFixed(2)} ` +
    `measure ${p(measure, 0.5).toFixed(2)} layout ${p(layout, 0.5).toFixed(2)} ` +
    `routes ${p(routed, 0.5).toFixed(2)} draw ${p(drawn, 0.5).toFixed(2)}]  ` +
    `frame ${stats(intervals, 20)}`
  );
};

async function main() {
  await init();
  await loadFonts();

  pane = editor({
    area: document.getElementById("sql"),
    ink: document.getElementById("ink"),
    debounce: DEBOUNCE,
    onSettle: reparse,
  });

  const sql = await fetch("./sample.sql").then((r) => r.text());
  pane.setText(sql);
  load(sql);

  // What web/front-check.mjs reads: the geometry this page decided on, so the
  // gate compares numbers rather than pictures, plus the handles it needs to
  // drive the camera and read back where it ended up.
  window.draft = {
    get boxes() {
      return scene.boxes;
    },
    get routes() {
      return scene.routes;
    },
    get metrics() {
      return scene.metrics;
    },
    get tables() {
      return scene.schema.tables.map((t) => t.name);
    },
    get lod() {
      return currentLod;
    },
    get focused() {
      return focused;
    },
    get pinned() {
      return pinned;
    },
    get counts() {
      return { visible: scene.visible, nodes: nodeCount };
    },
    get sql() {
      return pane.text;
    },
    /// The ink layer, so the gate can check the colours line up with the
    /// characters rather than only that the page did not throw.
    get ink() {
      const layer = document.getElementById("ink");
      return {
        ...pane.window,
        text: layer.textContent,
        runs: [...layer.children].map((span) => [span.className, span.textContent]),
      };
    },
    camera,
    toWorld: (x, y) => camera.toWorld(x, y),
    render: () => render(),
    fit: () => {
      camera.fit(scene.content, viewport(), 24);
      render();
    },
  };
  document.body.dataset.ready = "1";
}

main().catch((error) => {
  // Loudly: a front end that fails quietly leaves an empty diagram that looks
  // like a schema with nothing in it.
  statusLine.textContent = `failed: ${error}`;
  console.error(error);
});
