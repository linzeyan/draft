# draft

**Read a SQL schema as an ER diagram.** Paste a `CREATE TABLE` script — a
migration, a `pg_dump`, a file from a codebase you did not write — and get a
diagram you can pan, zoom and edit. It runs entirely in your browser. Nothing is
uploaded.

---

## The one idea

Most diagram tools import your schema into a model of their own, and from then
on there are two copies that drift. draft keeps one. **The SQL text is the
document**; the diagram is a projection of it.

That has a concrete consequence. Rename a table on the canvas and draft
rewrites the exact bytes of your script — propagating the rename into every
`REFERENCES` and key clause — while every comment, blank line and vendor clause
the parser never understood stays precisely where it was. The invariant is
tested rather than hoped for: renaming every table and every column in a 106 KB
commented schema and renaming them back is the byte-for-byte identity, and every
byte outside the spliced ranges is asserted unchanged.

## What it does

- Automatic layout, tuned so a wide schema folds into something a screen can
  hold rather than an unreadable ribbon.
- Pan, zoom and level of detail; hover a table to fade everything it is not
  connected to.
- Types and PK/FK/UQ badges, named indexes in their own block, nullable columns
  drawn quieter, and each column's full definition — `DEFAULT`, `CHECK`, an
  inline comment — on hover, or in the row's menu where there is no hover to be
  had. Edges carry cardinality, crow's foot to bar.
- Drag tables where you want them; they stay put.
- Find a table by name, or by a column it holds, with Ctrl/Cmd+F — the key the
  browser's own find bar cannot usefully answer over a canvas.
- A syntax-highlighted SQL pane beside the diagram, redrawing as you type.
- Two-way editing: double-click a table name, a column name or a type. Ctrl/Cmd+Z
  undoes any of it — text, splices, drags, notes, Arrange.
- Sticky notes and group boxes, for what the schema does not say.
- Save a project as one JSON file, or copy a link that carries the whole thing.
- Export SVG, PNG or WebP.


## Install

**Desktop** — download a build for macOS, Linux or Windows from
[Releases](https://github.com/linzeyan/draft/releases). The macOS build is not
signed or notarised; the archive explains how to open it anyway.

**From source** — needs a [Rust](https://rustup.rs) toolchain:

```sh
cargo install --git https://github.com/linzeyan/draft draft-cli   # the CLI
cargo install --git https://github.com/linzeyan/draft draft-app   # the desktop app
```

## Command line

The same parser, layout engine and renderer build as a native binary with no
window at all — useful in a build, a pre-commit hook or a PR comment.

```sh
draft render schema.sql -o schema.svg
draft render schema.sql --png -o schema.png      # 2x raster
draft render schema.sql --json | jq '.relations | length'

draft render schema.sql --dir vertical --spacing compact --theme dark -o s.svg
```

`--json` emits the parsed schema, byte spans included, so you can assert things
about a schema in CI without linking anything.

## Development

```sh
make            # list every target
make test       # the whole suite
make app        # run the desktop application
make web-serve  # the web application, rebuilding on change
make site       # the landing pages and the app into web/dist
make budgets    # payload, parse time and layout time, as CI runs them
make share      # drive a real browser and prove nothing leaves the origin unasked
```

Requires Rust, [trunk](https://trunkrs.dev) and the `wasm32-unknown-unknown`
target for the web build, and Node for the browser measurements.

## Licence and attribution

MIT — see [LICENSE](LICENSE).

The span-preserving scanning strategy, the hub-aware edge weighting and the
table box metrics are ported from
[sqltoerdiagram](https://github.com/royalbhati/sql-to-er-diagram) (MIT), with
attribution in [NOTICE](NOTICE), which also covers the bundled fonts and the
test fixtures.
