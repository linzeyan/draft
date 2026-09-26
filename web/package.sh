#!/usr/bin/env bash
# Package the desktop application and the CLI for the platform this runs on.
#
# One script for all three platforms rather than three, because the only real
# difference is the container: macOS wants a .app bundle so the thing can be
# double-clicked, and the other two want a directory with the binaries in it.
#
# Deliberately not `set -e`: a failed step should say which one it was.
#
# Run: make desktop   (expects `cargo build --release` to have run already)

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root" || exit 1

version="$(sed -n 's/^version = "\(.*\)"/\1/p' Cargo.toml | head -1)"
[ -n "$version" ] || { echo "no version in Cargo.toml"; exit 1; }

case "$(uname -s)" in
  Darwin) os=macos ;;
  Linux)  os=linux ;;
  MINGW*|MSYS*|CYGWIN*) os=windows ;;
  *) echo "unknown platform $(uname -s)"; exit 1 ;;
esac
arch="$(uname -m)"
[ "$arch" = "amd64" ] && arch=x86_64

exe=""
[ "$os" = windows ] && exe=".exe"
app="target/release/draft-app$exe"
cli="target/release/draft$exe"
for binary in "$app" "$cli"; do
  [ -f "$binary" ] || { echo "missing $binary — run: cargo build --release"; exit 1; }
done

name="draft-$version-$os-$arch"
out="dist/$name"
rm -rf "$out" "dist/$name.zip" "dist/$name.tar.gz"
mkdir -p "$out"
cp README.md LICENSE NOTICE "$out/"
cp "$cli" "$out/"

status=0
if [ "$os" = macos ]; then
  # A bare Mach-O executable cannot be double-clicked and gets no Dock icon or
  # menu bar. The bundle is the minimum that makes it behave like an
  # application; nothing here needs a build system of its own.
  bundle="$out/draft.app"
  mkdir -p "$bundle/Contents/MacOS" "$bundle/Contents/Resources"
  cp "$app" "$bundle/Contents/MacOS/draft"
  cat >"$bundle/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key>              <string>draft</string>
  <key>CFBundleDisplayName</key>       <string>draft</string>
  <key>CFBundleIdentifier</key>        <string>dev.draft.app</string>
  <key>CFBundleVersion</key>           <string>$version</string>
  <key>CFBundleShortVersionString</key><string>$version</string>
  <key>CFBundleExecutable</key>        <string>draft</string>
  <key>CFBundlePackageType</key>       <string>APPL</string>
  <key>LSMinimumSystemVersion</key>    <string>11.0</string>
  <key>NSHighResolutionCapable</key>   <true/>
  <key>CFBundleDocumentTypes</key>
  <array>
    <dict>
      <key>CFBundleTypeName</key>      <string>SQL schema</string>
      <key>CFBundleTypeRole</key>      <string>Viewer</string>
      <key>LSItemContentTypes</key>    <array><string>public.plain-text</string></array>
    </dict>
  </array>
</dict>
</plist>
PLIST
  # The build is unsigned, so Gatekeeper quarantines it on first open. Saying so
  # in the download beats a user concluding the application is broken.
  cat >"$out/FIRST RUN.txt" <<'TXT'
This build is not signed or notarised, so macOS will refuse to open it the
first time with "draft cannot be opened because the developer cannot be
verified".

To open it anyway: right-click draft.app, choose Open, then Open again.
You only have to do this once.

Or, from a terminal:  xattr -dr com.apple.quarantine draft.app

If you would rather not run an unsigned binary, the web version needs no
install at all, and `cargo install --path crates/app` builds it yourself.
TXT
  (cd dist && zip -qr "$name.zip" "$name") || status=$?
  artifact="dist/$name.zip"
elif [ "$os" = windows ]; then
  cp "$app" "$out/"
  (cd dist && zip -qr "$name.zip" "$name") || status=$?
  artifact="dist/$name.zip"
else
  cp "$app" "$out/"
  tar -czf "dist/$name.tar.gz" -C dist "$name" || status=$?
  artifact="dist/$name.tar.gz"
fi

if [ "$status" -ne 0 ]; then
  echo "packaging failed with status $status"
  exit "$status"
fi

size="$(du -h "$artifact" | cut -f1 | tr -d ' ')"
echo "  $artifact  ($size)"
echo "  contents:"
find "$out" -maxdepth 2 -mindepth 1 | sed 's|^|    |'
