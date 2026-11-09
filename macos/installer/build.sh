#!/bin/bash
# Builds the WorldTimeScreensaver.saver bundle (Release) and wraps it in an
# unsigned .pkg installer that copies it into the current user's
# ~/Library/Screen Savers. Unsigned, per the project's current signing
# status (see README) — installing it needs a one-time Gatekeeper override,
# same as double-clicking the .saver directly, which is still the simpler
# native install path for anyone building from source themselves.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
XCODE_PROJECT_DIR="$ROOT_DIR/macos/WorldTimeScreensaver"
INSTALLER_DIR="$ROOT_DIR/macos/installer"
BUILD_DIR="$INSTALLER_DIR/build"
SCRIPTS_DIR="$BUILD_DIR/scripts"
OUT_PKG="$BUILD_DIR/WorldTimeScreensaver.pkg"

rm -rf "$BUILD_DIR"
mkdir -p "$SCRIPTS_DIR"

echo "==> Building WorldTimeScreensaver.saver (Release)"
xcodebuild \
  -project "$XCODE_PROJECT_DIR/WorldTimeScreensaver.xcodeproj" \
  -target WorldTimeScreensaver \
  -configuration Release \
  CODE_SIGNING_ALLOWED=NO \
  SYMROOT="$BUILD_DIR/xcodebuild" \
  build

SAVER_BUNDLE="$BUILD_DIR/xcodebuild/Release/WorldTimeScreensaver.saver"
if [ ! -d "$SAVER_BUNDLE" ]; then
  echo "error: expected build output not found at $SAVER_BUNDLE" >&2
  exit 1
fi

cp -R "$SAVER_BUNDLE" "$SCRIPTS_DIR/"
cp "$INSTALLER_DIR/postinstall" "$SCRIPTS_DIR/postinstall"
chmod +x "$SCRIPTS_DIR/postinstall"

echo "==> Building $OUT_PKG"
pkgbuild \
  --nopayload \
  --scripts "$SCRIPTS_DIR" \
  --identifier com.worldtime.screensaver.installer \
  --version 1.0 \
  "$OUT_PKG"

echo "==> Done: $OUT_PKG"
