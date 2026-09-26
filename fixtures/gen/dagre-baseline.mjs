// Phase 0 spike S4 -- reference baseline.
//
// Runs dagre.js at the exact version sqltoerdiagram pins (@dagrejs/dagre
// ^1.1.4) over the same pre-measured graph the Rust candidates get, applying
// the same hub-aware edge weighting and the same "comfortable" spacing preset.
//
// Without this, a Rust engine's numbers have nothing to be good or bad against.
//
// Run: node fixtures/gen/dagre-baseline.mjs
// Requires: npm install @dagrejs/dagre@1.1.4 (see .scratch/dagre-baseline)

import { readFileSync } from "node:fs";
import { createRequire } from "node:module";

const require = createRequire(
  new URL("../../.scratch/dagre-baseline/", import.meta.url),
);
const dagre = require("@dagrejs/dagre");

const NODESEP = 36, RANKSEP = 130, EDGESEP = 24;

function layout(spec) {
  const degree = new Map();
  const bump = (k) => degree.set(k, (degree.get(k) || 0) + 1);
  for (const e of spec.edges) {
    if (e.from !== e.to) { bump(e.from); bump(e.to); }
  }

  const g = new dagre.graphlib.Graph({ multigraph: true });
  g.setGraph({
    rankdir: "LR",
    nodesep: NODESEP,
    ranksep: RANKSEP,
    edgesep: EDGESEP,
    ranker: "network-simplex",
    acyclicer: "greedy",
    marginx: 40,
    marginy: 40,
  });
  g.setDefaultEdgeLabel(() => ({}));

  for (const n of spec.nodes) g.setNode(n.id, { width: n.w, height: n.h });
  let i = 0;
  for (const e of spec.edges) {
    if (e.from === e.to) continue;
    const hubness = Math.max(degree.get(e.from) || 0, degree.get(e.to) || 0);
    g.setEdge(e.from, e.to, { weight: 1 + Math.min(hubness, 12), minlen: 1 }, "e" + i++);
  }

  const t = process.hrtime.bigint();
  dagre.layout(g);
  const ms = Number(process.hrtime.bigint() - t) / 1e6;

  const placed = new Map();
  for (const n of spec.nodes) {
    const node = g.node(n.id);
    if (node && Number.isFinite(node.x)) {
      // dagre returns centres; convert to top-left to match the Rust harness.
      placed.set(n.id, { x: node.x - n.w / 2, y: node.y - n.h / 2, w: n.w, h: n.h });
    }
  }
  return { ms, placed };
}

// Identical metric definitions to spikes/layout-eval/src/main.rs. Any drift
// between the two makes the comparison meaningless, so keep them in step.
function measure(placed, edges) {
  let minX = Infinity, minY = Infinity, maxX = -Infinity, maxY = -Infinity, area = 0;
  for (const p of placed.values()) {
    minX = Math.min(minX, p.x); minY = Math.min(minY, p.y);
    maxX = Math.max(maxX, p.x + p.w); maxY = Math.max(maxY, p.y + p.h);
    area += p.w * p.h;
  }
  const width = maxX - minX, height = maxY - minY;

  const list = [...placed.values()];
  let overlaps = 0;
  for (let i = 0; i < list.length; i++) {
    for (let j = i + 1; j < list.length; j++) {
      const a = list[i], b = list[j];
      const ox = Math.min(a.x + a.w, b.x + b.w) - Math.max(a.x, b.x);
      const oy = Math.min(a.y + a.h, b.y + b.h) - Math.max(a.y, b.y);
      if (ox > 0 && oy > 0) overlaps++;
    }
  }

  let total = 0, counted = 0;
  for (const e of edges) {
    const a = placed.get(e.from), b = placed.get(e.to);
    if (!a || !b) continue;
    const dx = (a.x + a.w / 2) - (b.x + b.w / 2);
    const dy = (a.y + a.h / 2) - (b.y + b.h / 2);
    total += Math.hypot(dx, dy); counted++;
  }

  return {
    width, height,
    aspect: height > 0 ? width / height : 0,
    overlaps,
    density: width * height > 0 ? area / (width * height) : 0,
    meanEdge: counted ? total / counted : 0,
  };
}

for (const fixture of ["synthetic_300", "synthetic_1000"]) {
  const spec = JSON.parse(
    readFileSync(new URL(`../${fixture}.graph.json`, import.meta.url), "utf8"),
  );
  // Warm up the JIT, then best-of-3, matching the Rust harness.
  layout(spec);
  let best = Infinity, result = null;
  for (let i = 0; i < 3; i++) {
    const r = layout(spec);
    if (r.ms < best) best = r.ms;
    result = r;
  }
  const m = measure(result.placed, spec.edges);
  console.log(
    `\n=== ${fixture} (${spec.nodes.length} nodes, ${spec.edges.length} edges) ===\n` +
      `dagre.js 1.1.4   ${best.toFixed(1).padStart(8)}ms  placed ${result.placed.size}/${spec.nodes.length}  ` +
      `bbox ${m.width.toFixed(0)}x${m.height.toFixed(0)} (aspect ${m.aspect.toFixed(2)})  ` +
      `overlaps ${m.overlaps}  density ${m.density.toFixed(3)}  mean edge ${m.meanEdge.toFixed(0)}px`,
  );
}
