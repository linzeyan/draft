#!/usr/bin/env bash
# Spike S5a -- the payload floor of a DOM front end.
#
# Builds the bridge in core/ for wasm32 and reports its size at every stage, so
# "abandon egui" can be argued with a number instead of an intuition. Compare
# against the shipped bundle (web/payload.mjs) and against the empty-eframe
# floor in S1.
#
# Usage: spikes/dom-front/build.sh

set -uo pipefail   # deliberately no -e: a failing stage is a result to report,
                   # not a reason to stop reporting the earlier ones.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OUT="$ROOT/.scratch/s5-dom-front"
CORE="$ROOT/spikes/dom-front/core"
mkdir -p "$OUT"

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
# the one the shipped bundle is built with. Preferring its copy is what makes
# this number comparable rather than merely plausible.
find_bindgen() {
  if [ -n "${WASM_BINDGEN:-}" ]; then echo "$WASM_BINDGEN"; return; fi
  if command -v wasm-bindgen > /dev/null; then command -v wasm-bindgen; return; fi
  fd -t x -u '^wasm-bindgen$' \
    "$HOME/Library/Caches/dev.trunkrs.trunk" "$HOME/.cache/trunk" 2>/dev/null | head -1
}

BINDGEN="$(find_bindgen)"
if [ -z "$BINDGEN" ]; then
  echo "no wasm-bindgen: set WASM_BINDGEN, or run 'make web-build' once to let trunk fetch it" >&2
  exit 1
fi
echo "wasm-bindgen: $BINDGEN ($("$BINDGEN" --version))"

log="$OUT/build.log"
: > "$log"

# Its own target dir: sharing the workspace's would make cargo rebuild the tree
# every time this spike is run with a different feature resolution.
( cd "$CORE" && CARGO_TARGET_DIR="$ROOT/.scratch/s5-target" \
    cargo build --release --target wasm32-unknown-unknown ) >> "$log" 2>&1
code=$?
if [ $code -ne 0 ]; then
  echo "cargo build failed ($code); see $log" >&2
  exit $code
fi

raw="$ROOT/.scratch/s5-target/wasm32-unknown-unknown/release/dom_front_core.wasm"
"$BINDGEN" --target web --no-typescript --out-dir "$OUT/dist" "$raw" >> "$log" 2>&1 || exit 1
bindgen_wasm="$OUT/dist/dom_front_core_bg.wasm"
wasm-opt -Oz "${WASM_OPT_FEATURES[@]}" -o "$OUT/opt.wasm" "$bindgen_wasm" >> "$log" 2>&1 || exit 1
brotli -q 11 -f -o "$OUT/opt.wasm.br" "$OUT/opt.wasm"
brotli -q 11 -f -o "$OUT/glue.js.br" "$OUT/dist/dom_front_core.js"

kb() { echo "$(( ($(wc -c < "$1" | tr -d ' ') + 512) / 1024 ))K"; }

{
  printf '%-28s %10s\n' 'STAGE' 'SIZE'
  printf '%.0s-' {1..39}; echo
  printf '%-28s %10s\n' 'cargo, raw wasm'      "$(kb "$raw")"
  printf '%-28s %10s\n' 'after wasm-bindgen'   "$(kb "$bindgen_wasm")"
  printf '%-28s %10s\n' 'after wasm-opt -Oz'   "$(kb "$OUT/opt.wasm")"
  printf '%-28s %10s\n' 'wasm, brotli -q 11'   "$(kb "$OUT/opt.wasm.br")"
  printf '%-28s %10s\n' 'JS glue, brotli'      "$(kb "$OUT/glue.js.br")"
} | tee "$OUT/summary.txt"

echo
echo "logs and artefacts in $OUT"
