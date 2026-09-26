// Numbers to SVG elements. No decisions.
//
// Every rule this file draws by arrives from the wasm: box sizes and positions
// from `place`, badges and index rows from `schema_json`, edge routes from
// `routes_json`, and how much detail to draw from `lod`. What is left here is
// which element to create and which attribute to put the number in, which is
// the one thing the wasm cannot do.
//
// The three detail levels are `table_shapes`' own, branch for branch
// (crates/view/src/lib.rs): a block is one rect in the *header* colour, a
// header adds the band and the name, and full adds the rows. Drawing them
// differently here would mean the diagram changed when the front end replaced
// the canvas, which is not a change anybody asked for.

import { FONTS, elide, width } from "./measure.mjs";

const NS = "http://www.w3.org/2000/svg";

/// The corner radius `Metrics::at(1.0)` uses.
const RADIUS = 6;

export function el(name, attrs, text) {
  const node = document.createElementNS(NS, name);
  for (const key in attrs) {
    node.setAttribute(key, attrs[key]);
  }
  if (text !== undefined) node.textContent = text;
  return node;
}

/// One table box, in world coordinates, at the given level of detail.
export function drawTable(table, box, m, lod, index) {
  const g = el("g", {
    transform: `translate(${box.x} ${box.y})`,
    class: `table ${lod}`,
    // What hover and pin read. The DOM hit-tests for free — the thing a canvas
    // has to do arithmetic for (D19) — so the index travels on the element.
    "data-table": index,
  });

  if (lod === "block") {
    g.append(
      el("rect", {
        class: "block",
        x: 0.5,
        y: 0.5,
        width: box.w - 1,
        height: box.h - 1,
        rx: RADIUS,
      }),
    );
    return g;
  }

  // Inside stroke: epaint's `StrokeKind::Inside`, which SVG spells as a rect
  // inset by half the stroke width. Without it the boxes would be a pixel wider
  // here than in the golden SVG, which is exactly the class of drift the
  // geometry gate exists to catch.
  g.append(
    el("rect", {
      class: "box",
      x: 0.5,
      y: 0.5,
      width: box.w - 1,
      height: box.h - 1,
      rx: RADIUS,
    }),
  );
  // The header is rounded at the top and square where it meets the first row —
  // two shapes, for the same reason the canvas build uses two.
  g.append(el("rect", { class: "header-fill", width: box.w, height: m.headerH, rx: RADIUS }));
  g.append(
    el("rect", {
      class: "header-fill",
      y: m.headerH - RADIUS,
      width: box.w,
      height: RADIUS,
    }),
  );
  g.append(
    el(
      "text",
      {
        class: "header-text",
        x: m.padX,
        y: m.headerH / 2,
        "dominant-baseline": "central",
      },
      elide(table.name, FONTS.header, box.w - m.padX * 2),
    ),
  );

  if (lod === "header") return g;

  table.columns.forEach((column, i) => {
    const mid = m.headerH + m.rowH * i + m.rowH / 2;
    const badgeSpace = column.badge ? m.badgeW : 0;
    const nameMax = box.w - m.padX * 2 - badgeSpace;
    const name = elide(column.name, FONTS.name, nameMax);
    g.append(
      el(
        "text",
        {
          class: column.null ? "name null" : "name",
          x: m.padX,
          y: mid,
          "dominant-baseline": "central",
        },
        name,
      ),
    );

    // The type is dropped rather than squeezed when the name has taken the row:
    // `table_shapes` gives up below twelve points of space, and a type elided to
    // "…" tells the reader nothing while still costing the width.
    const room = box.w - m.padX * 2 - badgeSpace - width(name, FONTS.name) - m.gap;
    if (column.type && room > 12) {
      g.append(
        el(
          "text",
          {
            class: "type",
            x: box.w - m.padX - badgeSpace,
            y: mid,
            "text-anchor": "end",
            "dominant-baseline": "central",
          },
          elide(column.type, FONTS.type, room),
        ),
      );
    }

    if (column.badge) {
      g.append(
        el(
          "text",
          {
            class: "badge",
            x: box.w - m.padX,
            y: mid,
            "text-anchor": "end",
            "dominant-baseline": "central",
          },
          column.badge,
        ),
      );
    }
  });

  if (table.indexes.length > 0) {
    const top = m.headerH + m.rowH * table.columns.length;
    g.append(
      el("line", {
        class: "index-rule",
        x1: m.padX,
        x2: box.w - m.padX,
        y1: top + m.indexSep / 2,
        y2: top + m.indexSep / 2,
      }),
    );
    table.indexes.forEach((index, i) => {
      const mid = top + m.indexSep + m.indexH * i + m.indexH / 2;
      g.append(
        el(
          "text",
          { class: "index-name", x: m.padX, y: mid, "dominant-baseline": "central" },
          elide(index.left, FONTS.type, box.w - m.padX * 2 - m.badgeW),
        ),
      );
      if (index.right) {
        g.append(
          el(
            "text",
            {
              class: "index-name",
              x: box.w - m.padX - m.badgeW,
              y: mid,
              "text-anchor": "end",
              "dominant-baseline": "central",
            },
            index.right,
          ),
        );
      }
      g.append(
        el(
          "text",
          {
            class: "badge",
            x: box.w - m.padX,
            y: mid,
            "text-anchor": "end",
            "dominant-baseline": "central",
          },
          index.unique ? "UQ" : "IX",
        ),
      );
    });
  }
  return g;
}

/// One relationship, from the route the wasm computed.
///
/// No arithmetic here either: which side an edge leaves from, how far it bends
/// and what a crow's foot is made of are decisions, and they are made in
/// `draft_geom` so that this draws the same edge `draft render` draws. The
/// only choice made here is the SVG command — four points is a cubic, two is a
/// straight stub — and whether the cardinality marks are worth drawing at all.
export function drawEdge(route, lod) {
  const p = route.path;
  const cls = route.to === null ? "edge dangling" : "edge";
  const g = el("g", { class: "edge-group" });
  g.append(
    el("path", {
      class: cls,
      d:
        p.length === 8
          ? `M ${p[0]} ${p[1]} C ${p[2]} ${p[3]} ${p[4]} ${p[5]} ${p[6]} ${p[7]}`
          : `M ${p[0]} ${p[1]} L ${p[2]} ${p[3]}`,
    }),
  );
  // A crow's foot is nine points long, so below full detail it is under two
  // pixels of ink: not a cardinality any more, just thicker line ends. Dropping
  // it is the same judgement `Lod` itself is built on — legibility first — and
  // it happens to remove three nodes per edge on exactly the frames that have
  // the most edges on screen.
  if (lod === "full") {
    for (const [x1, y1, x2, y2] of route.marks) {
      g.append(el("line", { class: cls, x1, y1, x2, y2 }));
    }
  }
  return g;
}

/// The bounding box of a routed edge, for culling. The marks sit inside the
/// span of the path's own points, so the points are the whole extent.
export function edgeBounds(route) {
  let minX = Infinity;
  let minY = Infinity;
  let maxX = -Infinity;
  let maxY = -Infinity;
  for (let i = 0; i < route.path.length; i += 2) {
    minX = Math.min(minX, route.path[i]);
    maxX = Math.max(maxX, route.path[i]);
    minY = Math.min(minY, route.path[i + 1]);
    maxY = Math.max(maxY, route.path[i + 1]);
  }
  return { x: minX, y: minY, w: maxX - minX, h: maxY - minY };
}
