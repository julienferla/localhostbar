#!/usr/bin/env bash
# Build Release .app and package a UDZO DMG (local or CI).
# Usage: ./scripts/make-dmg.sh [version]
#   version: e.g. 1.0.2 or v1.0.2 (defaults: GITHUB_REF_NAME, then MARKETING_VERSION in project.yml)
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

resolve_version() {
  local v="${GITHUB_REF_NAME:-}"
  v="${v#refs/tags/}"
  v="${v#v}"
  if [[ -n "${1:-}" ]]; then
    v="${1#v}"
  fi
  if [[ -z "$v" ]]; then
    v=$(grep 'MARKETING_VERSION:' project.yml | head -1 | sed 's/.*"\([^"]*\)".*/\1/')
  fi
  echo "$v"
}

VERSION="$(resolve_version "${1:-}")"

if ! command -v xcodegen &>/dev/null; then
  echo "Install xcodegen: brew install xcodegen" >&2
  exit 1
fi

if ! command -v create-dmg &>/dev/null; then
  echo "Install create-dmg: brew install create-dmg" >&2
  exit 1
fi

echo "==> XcodeGen"
xcodegen generate

DERIVED="$ROOT/build/DerivedData"
rm -rf "$DERIVED"
mkdir -p "$ROOT/dist"

echo "==> xcodebuild Release (generic macOS)"
xcodebuild \
  -project LocalHostBar.xcodeproj \
  -scheme LocalHostBar \
  -configuration Release \
  -derivedDataPath "$DERIVED" \
  -destination "generic/platform=macOS" \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=YES \
  build

APP="$DERIVED/Build/Products/Release/LocalHostBar.app"
if [[ ! -d "$APP" ]]; then
  echo "Build failed: $APP not found" >&2
  exit 1
fi

STAGE="$ROOT/build/dmg_stage"
rm -rf "$STAGE"
mkdir -p "$STAGE"
ditto "$APP" "$STAGE/LocalHostBar.app"

DMG="$ROOT/dist/LocalHostBar-${VERSION}.dmg"
rm -f "$DMG"
echo "==> create-dmg -> $DMG"

# Drag-to-install layout: app icon on the left, Applications symlink on the right.
# Window size 540x360 chosen to fit both icons (100px) with comfortable spacing.
create-dmg \
  --volname "LocalHostBar ${VERSION}" \
  --window-pos 200 120 \
  --window-size 540 360 \
  --icon-size 100 \
  --icon "LocalHostBar.app" 140 180 \
  --app-drop-link 400 180 \
  --no-internet-enable \
  --hdiutil-quiet \
  "$DMG" \
  "$STAGE"

echo "Created: $DMG"
ls -la "$DMG"
