#!/usr/bin/env bash
# Build the DOM front end into web/front/dist, and report what it weighs.
#
# Phase 8.4 stage a. Not trunk, because there is no egui here to bundle: the
# artefacts are a wasm module, its generated glue, three static files, the
# sample schema and the two typefaces the browser has to measure with. Keeping
# the build in a script means the payload can be read off the same run that
# produced it.
#
# Usage: web/front.sh   (or: make front-build)

set -uo pipefail   # deliberately no -e: a failing stage is a result to report,
                   # not a reason to stop reporting the earlier ones.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="$ROOT/web/front"
DIST="$SRC/dist"
# Its own target dir, like the spike this grew out of: the canvas build runs
# `trunk build` over the same workspace, and two invocations selecting different
# packages for the same target would rebuild each other's dependencies.
TARGET="$ROOT/.scratch/front-target"
LOG="$DIST/build.log"
# docs/roadmap.md §8.4: 400 K brotli, the whole front end. Printed *and*
# enforced — a budget that only gets printed is a budget that gets exceeded.
GATE=400

# rustc emits memory.fill and friends for wasm32-unknown-unknown, which binaryen
# refuses to validate unless the matching proposals are named explicitly.
WASM_OPT_FEATURES=(
  --enable-bulk-memory
  --enable-bulk-memory-opt
  --enable-nontrapping-float-to-int
  --enable-sign-ext
  --enable-mutable-globals
  --enable-multivalue
  --enable-reference-types
)

# The CLI has to match the crate version, and trunk already downloaded exactly
# the one the shipped bundle is built with.
find_bindgen() {
  if [ -n "${WASM_BINDGEN:-}" ]; then echo "$WASM_BINDGEN"; return; fi
  if command -v wasm-bindgen > /dev/null; then command -v wasm-bindgen; return; fi
  fd -t x -u '^wasm-bindgen$' \
    "$HOME/Library/Caches/dev.trunkrs.trunk" "$HOME/.cache/trunk" 2>/dev/null | head -1
}

# The same two files `epaint_default_fonts` hands to epaint, so the browser
# shapes text with the outlines the CLI measured. Located rather than vendored:
# a second copy could drift from the one the application links, and the whole
# point of 8.4 stage a is that the two agree.
#
# --color=never because rg's SGR codes end up inside the path otherwise, and
# pyftsubset then reports a file it cannot open.
find_font() {
  fd --color=never -u "^$1$" "$HOME/.cargo/registry/src" 2>/dev/null \
    | rg --color=never 'epaint_default_fonts-0\.36\.2/fonts/' | head -1
}

# Latin, punctuation and currency. Measured: the two faces are 260 K brotli
# whole and 121 K over this range, which is the difference between missing the
# 400 K budget and having 129 K left for the editor.
#
# The range, not just ASCII (39 K), because the browser's advance widths decide
# where every box goes: a glyph the subset dropped but epaint still has would be
# drawn by a substitute face here and by Ubuntu there, and the same schema would
# lay out differently in the front end and in `draft render`. This range
# covers the identifiers epaint's own defaults are good for. Beyond it — Greek,
# Cyrillic, CJK — the two already disagree, because epaint's default fonts have
# no CJK either.
FONT_UNICODES='U+0020-007E,U+00A0-024F,U+02B0-02FF,U+2000-206F,U+20A0-20BF,U+2122'

mkdir -p "$DIST"
: > "$LOG"

BINDGEN="$(find_bindgen)"
if [ -z "$BINDGEN" ]; then
  echo "no wasm-bindgen: set WASM_BINDGEN, or run 'make web-build' once to let trunk fetch it" >&2
  exit 1
fi

step() { printf '%-22s %s\n' "$1" "$2"; }

CARGO_TARGET_DIR="$TARGET" cargo build --release --target wasm32-unknown-unknown \
  -p draft-front >> "$LOG" 2>&1
code=$?
if [ $code -ne 0 ]; then
  echo "cargo build failed ($code); see $LOG" >&2
  exit $code
fi

RAW="$TARGET/wasm32-unknown-unknown/release/draft_front.wasm"
"$BINDGEN" --target web --no-typescript --out-dir "$DIST" "$RAW" >> "$LOG" 2>&1 || exit 1
wasm-opt -Oz "${WASM_OPT_FEATURES[@]}" \
  -o "$DIST/draft_front_bg.wasm" "$DIST/draft_front_bg.wasm" >> "$LOG" 2>&1 || exit 1

# Every module, not a list of them: there is no bundler here (D23), so each
# `import` is a file the browser fetches, and one left behind is a page that
# does not start.
cp "$SRC/index.html" "$SRC/style.css" "$SRC"/*.mjs "$DIST/"
# The same mark the landing pages and the canvas build use.
cp "$ROOT/web/favicon.svg" "$DIST/favicon.svg"
# The same sample the canvas build compiles in, so the two draw the same schema.
cp "$ROOT/crates/app/src/sample.sql" "$DIST/sample.sql"
if ! command -v pyftsubset > /dev/null; then
  echo "no pyftsubset: pip install fonttools (the fonts are two thirds of this bundle)" >&2
  exit 1
fi
for face in Ubuntu-Light.ttf Hack-Regular.ttf; do
  found="$(find_font "$face")"
  if [ -z "$found" ]; then
    echo "cannot find $face in the cargo registry; run a native build once" >&2
    exit 1
  fi
  # Default flags on purpose: hinting and metrics are kept, so a retained
  # glyph's advance width is bit-identical to the one epaint measured.
  # `make front-check` is what proves that, and it does.
  pyftsubset "$found" --unicodes="$FONT_UNICODES" \
    --output-file="$DIST/$face" >> "$LOG" 2>&1
  code=$?
  if [ $code -ne 0 ]; then
    echo "subsetting $face failed ($code); see $LOG" >&2
    exit $code
  fi
done

# Brotli, because that is what a static host serves and what the budget in
# docs/spec.md is written in.
kb() { echo "$(( ($(brotli -q 11 -c "$1" | wc -c | tr -d ' ') + 512) / 1024 ))"; }
PAYLOAD=(draft_front_bg.wasm draft_front.js index.html style.css)
for module in "$SRC"/*.mjs; do PAYLOAD+=("$(basename "$module")"); done
PAYLOAD+=(Ubuntu-Light.ttf Hack-Regular.ttf)

total=0
printf '\n%-26s %10s\n' 'FILE' 'BROTLI'
printf '%.0s-' {1..38}; echo
for f in "${PAYLOAD[@]}"; do
  size="$(kb "$DIST/$f")"
  total=$(( total + size ))
  printf '%-26s %8s K\n' "$f" "$size"
done
printf '%-26s %8s K\n' 'total' "$total"
# sample.sql is not in the payload: it is the demo schema, fetched only because
# this stage has no editor to paste one into.
echo
step 'gate (docs/roadmap.md)' "$GATE K"
step 'canvas build, for scale' '1273 K'
echo
if [ "$total" -gt "$GATE" ]; then
  echo "over budget by $(( total - GATE )) K" >&2
  exit 1
fi
echo "serve it: node web/serve-front.mjs"
