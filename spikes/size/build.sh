#!/usr/bin/env bash
# Phase 0 spike S1 -- payload floor.
#
# Builds an empty eframe app in four configurations and reports the wasm size at
# each stage of the pipeline. The point is to learn the floor our real app builds
# on top of, before any feature code exists to blame.
#
# Each configuration gets its own CARGO_TARGET_DIR. Sharing one would make cargo
# rebuild most of the tree every time the eframe feature set flips, and could
# leave a previous configuration's artifacts in place.
#
# Usage: spikes/size/build.sh

set -uo pipefail   # deliberately no -e: a failing configuration is a result,
                   # not a reason to abandon the other three.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OUT="$ROOT/.scratch/s1-size"
mkdir -p "$OUT"

# rustc emits memory.fill and friends for wasm32-unknown-unknown, which binaryen
# refuses to validate unless the matching proposals are enabled explicitly.
# Without these, wasm-opt dies with "error validating input" after a clean build.
WASM_OPT_FEATURES=(
  --enable-bulk-memory
  --enable-bulk-memory-opt
  --enable-nontrapping-float-to-int
  --enable-sign-ext
  --enable-mutable-globals
  --enable-multivalue
  --enable-reference-types
)

# name | eframe features (comma separated) | direct wgpu features ("" = none)
#
# Note on naming: eframe's `wgpu` feature pulls in `egui-wgpu/default`, which
# itself enables `wgpu/webgl`. So the plain `wgpu` configuration is NOT
# WebGPU-only, and an earlier version of this spike that assumed otherwise
# measured the same thing twice (1196K vs 1195K -- noise). Getting a real
# WebGPU-only build means going through `wgpu_no_default_features` and choosing
# the backends by hand.
CONFIGS=(
  "glow|glow|"
  "glow-default-fonts|glow,default_fonts|"
  "wgpu-default|wgpu|"
  "wgpu-webgpu-only|wgpu_no_default_features|webgpu,wgsl,std"
)

emit_crate() {
  local dir="$1" name="$2" features="$3"
  mkdir -p "$dir/src"

  # "glow,default_fonts" -> "glow", "default_fonts". Emitting the raw string
  # asks cargo for one feature literally named "glow,default_fonts".
  local feature_array
  feature_array=$(printf '"%s", ' ${features//,/ })
  feature_array="[${feature_array%, }]"

  cat > "$dir/Cargo.toml" <<EOF
[package]
name = "size-$name"
version = "0.0.0"
edition = "2024"
publish = false

# Detached from the parent workspace on purpose: cargo unifies features across
# workspace members, which would silently merge the glow and wgpu feature sets
# and make every number here wrong.
[workspace]

[dependencies]
eframe = { version = "0.36.2", default-features = false, features = $feature_array }
wasm-bindgen-futures = "0.4"
web-sys = { version = "0.3", features = ["Window", "Document", "Element", "HtmlCanvasElement"] }

[profile.release]
opt-level = "z"
lto = "fat"
codegen-units = 1
panic = "abort"
strip = true
EOF

  cat > "$dir/src/main.rs" <<'EOF'
// The smallest app that still exercises a window, a frame loop and text
// rendering. Measuring a truly empty binary would flatter the result, because
// the font atlas and the tessellator are what a real app pays for.
use eframe::egui;

#[derive(Default)]
struct App;

impl eframe::App for App {
    // egui 0.36 replaced `update(&Context, ..)` with `ui(&mut Ui, ..)`; the Ui
    // handed over has no margin or background of its own.
    fn ui(&mut self, ui: &mut egui::Ui, _frame: &mut eframe::Frame) {
        ui.heading("size probe");
        ui.label("one label, one button");
        let _ = ui.button("click");
    }
}

fn main() {
    use eframe::wasm_bindgen::JsCast as _;
    let options = eframe::WebOptions::default();
    wasm_bindgen_futures::spawn_local(async {
        let canvas = web_sys::window()
            .unwrap()
            .document()
            .unwrap()
            .get_element_by_id("canvas")
            .unwrap()
            .dyn_into::<web_sys::HtmlCanvasElement>()
            .unwrap();
        eframe::WebRunner::new()
            .start(canvas, options, Box::new(|_cc| Ok(Box::new(App))))
            .await
            .expect("failed to start eframe");
    });
}
EOF

  # wasm-opt is disabled here and run by hand below, because trunk gives no way
  # to pass the binaryen feature flags this toolchain needs.
  cat > "$dir/index.html" <<EOF
<!doctype html>
<html>
  <head><meta charset="utf-8"><title>size-$name</title></head>
  <body style="margin:0">
    <canvas id="canvas"></canvas>
    <link data-trunk rel="rust" data-wasm-opt="0" />
  </body>
</html>
EOF
}

printf '%-22s %10s %10s %10s %8s\n' CONFIG BINDGEN WASM-OPT BROTLI STATUS | tee "$OUT/summary.txt"
printf '%.0s-' {1..66} | tee -a "$OUT/summary.txt"; echo | tee -a "$OUT/summary.txt"

kb() { echo "$(( ($1 + 512) / 1024 ))K"; }

for cfg in "${CONFIGS[@]}"; do
  IFS='|' read -r name features wgpu_features <<< "$cfg"
  dir="$ROOT/spikes/size/$name"
  emit_crate "$dir" "$name" "$features"

  log="$OUT/$name.log"
  : > "$log"

  # Choosing wgpu backends by hand means depending on the exact wgpu version
  # egui-wgpu already resolved to. Guessing the version would pull a second copy
  # of wgpu into the graph, where the features have no effect and the
  # measurement silently becomes meaningless.
  if [ -n "$wgpu_features" ]; then
    ( cd "$dir" && cargo generate-lockfile ) >> "$log" 2>&1
    wgpu_ver=$(rg -N -A1 '^name = "wgpu"$' "$dir/Cargo.lock" \
                 | rg -N -o '^version = "([^"]+)"' -r '$1' | head -1)
    if [ -z "$wgpu_ver" ]; then
      printf '%-22s %10s %10s %10s %8s\n' "$name" - - - NOWGPU | tee -a "$OUT/summary.txt"
      continue
    fi
    echo "resolved wgpu $wgpu_ver, features $wgpu_features" >> "$log"
    ( cd "$dir" && cargo add "wgpu@=$wgpu_ver" \
        --no-default-features --features "$wgpu_features" ) >> "$log" 2>&1

    # Prove exactly one wgpu ended up in the graph. Two copies would mean the
    # feature selection applied to a crate nothing links against.
    copies=$(rg -Nc '^name = "wgpu"$' "$dir/Cargo.lock")
    echo "wgpu copies in lockfile: $copies" >> "$log"
    if [ "$copies" != "1" ]; then
      printf '%-22s %10s %10s %10s %8s\n' "$name" - - - "DUPWGPU" | tee -a "$OUT/summary.txt"
      continue
    fi
  fi

  ( cd "$dir" && CARGO_TARGET_DIR="$ROOT/.scratch/s1-target/$name" \
      trunk build --release ) >> "$log" 2>&1
  code=$?
  if [ $code -ne 0 ]; then
    printf '%-22s %10s %10s %10s %8s\n' "$name" - - - "FAIL($code)" | tee -a "$OUT/summary.txt"
    continue
  fi

  wasm=$(find "$dir/dist" -name '*.wasm' | head -1)
  if [ -z "$wasm" ]; then
    printf '%-22s %10s %10s %10s %8s\n' "$name" - - - NOWASM | tee -a "$OUT/summary.txt"
    continue
  fi
  bindgen=$(wc -c < "$wasm" | tr -d ' ')

  opt="$OUT/$name.opt.wasm"
  if ! wasm-opt -Oz "${WASM_OPT_FEATURES[@]}" -o "$opt" "$wasm" >> "$log" 2>&1; then
    printf '%-22s %10s %10s %10s %8s\n' "$name" "$(kb "$bindgen")" - - OPTFAIL \
      | tee -a "$OUT/summary.txt"
    continue
  fi
  optimised=$(wc -c < "$opt" | tr -d ' ')

  brotli -q 11 -f -o "$OUT/$name.wasm.br" "$opt"
  br=$(wc -c < "$OUT/$name.wasm.br" | tr -d ' ')

  printf '%-22s %10s %10s %10s %8s\n' \
    "$name" "$(kb "$bindgen")" "$(kb "$optimised")" "$(kb "$br")" OK \
    | tee -a "$OUT/summary.txt"
done

echo
echo "logs in $OUT"
