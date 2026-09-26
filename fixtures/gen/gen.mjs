// Deterministic fixture generator.
//
// Produces the SQL schemas used by parser golden tests and by the Phase 0
// performance spikes, plus a pre-measured graph JSON so that Rust and
// JavaScript layout engines can be benchmarked on byte-identical input.
//
// Everything is driven by a seeded PRNG: regenerating must never produce a
// different file, or golden tests become noise.

import { writeFileSync, mkdirSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const OUT = join(dirname(fileURLToPath(import.meta.url)), "..");

// mulberry32 -- small, fast, and identical across runs and platforms.
function rng(seed) {
  return function () {
    seed |= 0;
    seed = (seed + 0x6d2b79f5) | 0;
    let t = Math.imul(seed ^ (seed >>> 15), 1 | seed);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

const DOMAINS = [
  "account", "order", "invoice", "shipment", "product", "customer", "payment",
  "subscription", "ticket", "campaign", "inventory", "warehouse", "vendor",
  "contract", "employee", "department", "project", "task", "document", "asset",
  "policy", "claim", "route", "vehicle", "booking", "session", "audit",
  "notification", "template", "channel", "message", "attachment", "tag",
  "category", "discount", "refund", "review", "shipment_leg", "carrier",
];
const QUALIFIERS = [
  "", "", "", "legacy_", "staging_", "v2_", "archived_", "external_",
];
const SUFFIXES = [
  "", "", "", "_item", "_line", "_history", "_audit", "_meta", "_link",
  "_detail", "_snapshot", "_config",
];

const TYPES = {
  postgres: [
    "bigint", "integer", "smallint", "text", "varchar(255)", "varchar(64)",
    "boolean", "timestamptz", "timestamp", "date", "numeric(12,2)", "jsonb",
    "uuid", "bytea", "double precision", "char(2)", "inet",
  ],
};

const COLUMN_WORDS = [
  "name", "code", "status", "kind", "label", "slug", "title", "body", "note",
  "amount", "total", "quantity", "price", "currency", "rate", "weight",
  "created_at", "updated_at", "deleted_at", "expires_at", "starts_at",
  "is_active", "is_default", "is_locked", "external_ref", "metadata",
  "position", "version", "checksum", "locale", "timezone", "email", "phone",
];

// Mirrors the Node fallback in sqltoerdiagram's renderer.js measureTable(), so
// the graph JSON carries the same node dimensions the real renderer would
// compute. Layout quality depends on node size, so benchmarking with made-up
// dimensions would measure the wrong thing.
const PAD_X = 12, GAP = 14, BADGE_W = 30, MIN_W = 140, MAX_W = 360;
const ROW_H = 26, HEADER_H = 34;

function measureTable(table) {
  let w = table.name.length * 8.5 + PAD_X * 2 + 24;
  for (const c of table.columns) {
    const total =
      BADGE_W + c.name.length * 7.8 + GAP + c.type.length * 7.2 + PAD_X * 2;
    if (total > w) w = total;
  }
  w = Math.max(MIN_W, Math.min(MAX_W, Math.ceil(w)));
  return { w, h: HEADER_H + table.columns.length * ROW_H };
}

function buildSchema({ tableCount, avgColumns, seed }) {
  const rand = rng(seed);
  const pick = (arr) => arr[Math.floor(rand() * arr.length)];
  const int = (lo, hi) => lo + Math.floor(rand() * (hi - lo + 1));

  // Unique table names. Collisions are retried rather than suffixed with a
  // counter, so names stay plausible instead of drifting into table_217.
  const names = new Set();
  while (names.size < tableCount) {
    const n = `${pick(QUALIFIERS)}${pick(DOMAINS)}${pick(SUFFIXES)}`;
    if (n.length > 3) names.add(n);
    if (names.size < tableCount && rand() < 0.02) {
      names.add(`${pick(DOMAINS)}_${pick(DOMAINS)}`); // join tables
    }
  }
  const tableNames = [...names].slice(0, tableCount);

  // Real schemas are not uniformly connected: a handful of tables (users,
  // accounts, tenants) absorb most foreign keys. Layout quality lives or dies
  // on how those hubs are handled, so the fixture has to contain them.
  const hubCount = Math.max(3, Math.round(tableCount * 0.02));
  const hubs = tableNames.slice(0, hubCount);

  const tables = tableNames.map((name, idx) => {
    const columnCount = Math.max(2, Math.round(avgColumns + (rand() - 0.5) * 8));
    const columns = [
      { name: "id", type: "bigint", pk: true, fk: false, nn: true },
    ];
    const used = new Set(["id"]);
    for (let i = 1; i < columnCount; i++) {
      let cn = pick(COLUMN_WORDS);
      if (used.has(cn)) cn = `${cn}_${i}`;
      used.add(cn);
      columns.push({
        name: cn,
        type: pick(TYPES.postgres),
        pk: false,
        fk: false,
        nn: rand() < 0.4,
      });
    }
    return { name, columns, idx, isHub: idx < hubCount };
  });

  const byName = new Map(tables.map((t) => [t.name, t]));

  // Foreign keys. Hubs are referenced far more often than anything else, and a
  // slice of edges is emitted as ALTER TABLE instead of inline so the parser
  // fixture exercises both paths.
  const relations = [];
  const seen = new Set();
  const targetEdges = Math.round(tableCount * 2);
  let guard = targetEdges * 20;
  while (relations.length < targetEdges && guard-- > 0) {
    const from = tables[int(0, tables.length - 1)];
    const to = rand() < 0.55 ? byName.get(pick(hubs)) : tables[int(0, tables.length - 1)];
    if (!to || from.name === to.name) continue;
    const colName = `${to.name}_id`;
    const key = `${from.name}->${to.name}`;
    if (seen.has(key)) continue;
    seen.add(key);
    if (from.columns.some((c) => c.name === colName)) continue;

    const viaAlter = rand() < 0.18;
    from.columns.splice(1, 0, {
      name: colName,
      type: "bigint",
      pk: false,
      fk: true,
      nn: rand() < 0.6,
      references: viaAlter ? null : to.name,
    });
    relations.push({ from: from.name, to: to.name, column: colName, viaAlter });
  }

  return { tables, relations };
}

function emitSQL({ tables, relations }, { seed }) {
  const rand = rng(seed ^ 0x5f3759df);
  const out = [];
  out.push("-- Generated fixture. Do not edit by hand; see fixtures/gen/gen.mjs.");
  out.push("-- Comments here are deliberate: the parser must blank them to");
  out.push("-- equal-length whitespace so byte offsets stay valid.");
  out.push("");

  for (const t of tables) {
    if (rand() < 0.25) out.push(`-- ${t.name}: ${t.columns.length} columns`);
    // Mixed quoting styles, because real dumps are not consistent and the
    // parser has to strip matched delimiter pairs without mangling TEXT[].
    const r = rand();
    const decl =
      r < 0.08 ? `"public"."${t.name}"` :
      r < 0.14 ? `public.${t.name}` :
      r < 0.18 ? `"${t.name}"` : t.name;

    out.push(`CREATE TABLE ${decl} (`);
    const lines = t.columns.map((c) => {
      let line = `  ${c.name} ${c.type}`;
      if (c.pk) line += " PRIMARY KEY";
      if (c.nn && !c.pk) line += " NOT NULL";
      if (c.references) line += ` REFERENCES ${c.references}(id)`;
      return line;
    });
    // A share of tables use a table-level PRIMARY KEY / UNIQUE clause, which is
    // a separate code path in the parser and in rename propagation.
    if (rand() < 0.2 && t.columns.length > 2) {
      const u = t.columns[1 + Math.floor(rand() * (t.columns.length - 1))];
      lines.push(`  UNIQUE (${u.name})`);
    }
    out.push(lines.join(",\n"));
    out.push(");");
    if (rand() < 0.12) out.push("/* trailing block comment */");
    out.push("");
  }

  for (const rel of relations.filter((r) => r.viaAlter)) {
    // pg_dump emits ALTER TABLE ONLY; the parser must tolerate the ONLY.
    out.push(
      `ALTER TABLE ONLY public.${rel.from} ADD CONSTRAINT ${rel.from}_${rel.column}_fkey ` +
        `FOREIGN KEY (${rel.column}) REFERENCES public.${rel.to}(id);`,
    );
  }
  out.push("");
  return out.join("\n");
}

function emitGraph({ tables, relations }) {
  return {
    // Node dimensions are pre-measured so a Rust and a JS layout engine receive
    // byte-identical input and their timings are actually comparable.
    nodes: tables.map((t) => {
      const { w, h } = measureTable(t);
      return { id: t.name, w, h };
    }),
    edges: relations.map((r) => ({ from: r.from, to: r.to })),
  };
}

function write(name, tableCount, avgColumns, seed, { graph = false } = {}) {
  const schema = buildSchema({ tableCount, avgColumns, seed });
  const sql = emitSQL(schema, { seed });
  mkdirSync(OUT, { recursive: true });
  writeFileSync(join(OUT, `${name}.sql`), sql);

  const bytes = Buffer.byteLength(sql);
  const columns = schema.tables.reduce((n, t) => n + t.columns.length, 0);
  let extra = "";
  if (graph) {
    const g = emitGraph(schema);
    writeFileSync(join(OUT, `${name}.graph.json`), JSON.stringify(g, null, 1));
    extra = `, graph: ${g.nodes.length} nodes / ${g.edges.length} edges`;
  }
  console.log(
    `${name}.sql  ${(bytes / 1024).toFixed(1)} KB  ` +
      `${schema.tables.length} tables, ${columns} columns, ` +
      `${schema.relations.length} FKs${extra}`,
  );
}

// Golden-test fixture: small enough to eyeball a full AST diff.
write("small_20", 20, 6, 1);
// The headline performance fixture, sized to match the reference tool's
// published "45 KB / 300 tables" benchmark so the numbers are comparable.
write("synthetic_300", 300, 5, 42, { graph: true });
// Canvas scale ceiling from docs/spec.md.
write("synthetic_1000", 1000, 7, 7, { graph: true });
