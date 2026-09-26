#!/usr/bin/env bash
# Build the deployable site on a Cloudflare Pages builder.
#
# The Pages build-command field is a single line, so the `&&`-chain that used to
# live there lost its line continuations and passed a bare space to rustup. A
# script in the repository is version-controlled, runs locally, and shows up in
# a diff. Set the Pages build command to `bash web/pages-build.sh` and the
# output directory to `web/dist`.
#
# Unlike web/front.sh this does use -e: every step here is a precondition for
# the next, and a half-built site must not reach the deploy.

set -euo pipefail

cd "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# The build image may or may not ship a Rust toolchain, and rustup-init refuses
# to run over an existing one. Adding the target to what is already there is
# both faster and the only thing that works in that case.
if command -v rustup > /dev/null; then
  rustup target add wasm32-unknown-unknown
else
  curl -sSf https://sh.rustup.rs | sh -s -- -y --profile minimal -t wasm32-unknown-unknown
  # shellcheck source=/dev/null
  . "$HOME/.cargo/env"
fi
export PATH="$HOME/.cargo/bin:$PATH"

# The release tarball, not `cargo install trunk`: building it from source costs
# minutes this builder does not have, and nothing here needs a pinned version —
# trunk only drives wasm-bindgen and wasm-opt, both of which it fetches itself.
if ! command -v trunk > /dev/null; then
  curl -sSfL https://github.com/trunk-rs/trunk/releases/latest/download/trunk-x86_64-unknown-linux-gnu.tar.gz \
    | tar -xz -C "$HOME/.cargo/bin"
fi

# Canonical URLs and the sitemap have to be absolute. CF_PAGES_URL is the
# deployment's own address, which is right for a preview branch; production
# wants the custom domain, so an explicit SITE_URL wins.
export SITE_URL="${SITE_URL:-${CF_PAGES_URL:-}}"
if [ -z "$SITE_URL" ]; then
  echo "no SITE_URL and no CF_PAGES_URL: canonical URLs would point at localhost" >&2
  exit 1
fi

rustc --version
trunk --version
node --version
echo "SITE_URL=$SITE_URL"

make site
