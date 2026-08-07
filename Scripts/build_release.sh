#!/usr/bin/env bash
# build_release.sh — Build a Release SimpleUsageBar.app and stage it under dist/
#
# Usage:
#   ./Scripts/build_release.sh
#   ./Scripts/build_release.sh --clean          # clean before build
#   ./Scripts/build_release.sh --zip            # also write dist/SimpleUsageBar-<version>.zip
#   ./Scripts/build_release.sh --open           # open the staged .app after build
#   ./Scripts/build_release.sh --out DIR        # stage under DIR (default: <repo>/dist)
#
# Notes:
#   - Uses the project Release configuration (optimized, not Debug).
#   - Signing stays as configured in the Xcode project (currently ad-hoc "-").
#   - Notarization / Developer ID are out of scope; stage the .app for local use
#     or further packaging.
#
# Requires full Xcode at /Applications/Xcode.app when xcode-select points
# at Command Line Tools only.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

SCHEME="SimpleUsageBar"
PROJECT="SimpleUsageBar.xcodeproj"
CONFIGURATION="Release"
PRODUCT_NAME="SimpleUsageBar"
CLEAN=0
ZIP=0
OPEN_APP=0
OUT_DIR="${ROOT}/dist"
DERIVED_DATA="${ROOT}/.derivedData-release"

# Prefer full Xcode so builds work even when xcode-select is CLT-only.
if [[ -d /Applications/Xcode.app/Contents/Developer ]]; then
  export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
fi

usage() {
  sed -n '2,16p' "$0" | sed 's/^# \{0,1\}//'
  exit "${1:-0}"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --clean)  CLEAN=1; shift ;;
    --zip)    ZIP=1; shift ;;
    --open)   OPEN_APP=1; shift ;;
    --out)
      if [[ $# -lt 2 ]]; then
        echo "error: --out requires a directory path" >&2
        usage 1
      fi
      OUT_DIR="$(cd "$(dirname "$2")" && pwd)/$(basename "$2")"
      shift 2
      ;;
    -h|--help) usage 0 ;;
    *)
      echo "Unknown option: $1" >&2
      usage 1
      ;;
  esac
done

if ! command -v xcodebuild >/dev/null 2>&1; then
  echo "error: xcodebuild not found" >&2
  exit 1
fi

echo "==> Release build: ${SCHEME}"
echo "    DEVELOPER_DIR=${DEVELOPER_DIR:-"(xcode-select default)"}"
echo "    configuration=${CONFIGURATION}"
echo "    derivedData=${DERIVED_DATA}"
echo "    output=${OUT_DIR}"

XCB_ARGS=(
  -project "$PROJECT"
  -scheme "$SCHEME"
  -configuration "$CONFIGURATION"
  -derivedDataPath "$DERIVED_DATA"
  -destination "platform=macOS"
  ONLY_ACTIVE_ARCH=NO
)

if [[ "$CLEAN" -eq 1 ]]; then
  echo "==> Clean"
  xcodebuild "${XCB_ARGS[@]}" clean
fi

echo "==> xcodebuild build (${CONFIGURATION})"
xcodebuild "${XCB_ARGS[@]}" build

BUILT_APP="${DERIVED_DATA}/Build/Products/${CONFIGURATION}/${PRODUCT_NAME}.app"
if [[ ! -d "$BUILT_APP" ]]; then
  echo "error: expected app not found at ${BUILT_APP}" >&2
  exit 1
fi

# Marketing version from the built Info.plist (falls back to "unknown").
VERSION="$(
  /usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' \
    "${BUILT_APP}/Contents/Info.plist" 2>/dev/null \
    || echo "unknown"
)"
BUILD_NUM="$(
  /usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' \
    "${BUILT_APP}/Contents/Info.plist" 2>/dev/null \
    || echo "0"
)"

mkdir -p "$OUT_DIR"
STAGED_APP="${OUT_DIR}/${PRODUCT_NAME}.app"

echo "==> Staging ${STAGED_APP} (v${VERSION} build ${BUILD_NUM})"
rm -rf "$STAGED_APP"
# ditto preserves code signatures and resource forks better than cp -R.
ditto "$BUILT_APP" "$STAGED_APP"

# Light sanity checks
if [[ ! -x "${STAGED_APP}/Contents/MacOS/${PRODUCT_NAME}" ]]; then
  echo "error: staged app binary missing or not executable" >&2
  exit 1
fi

echo "==> codesign (verify)"
codesign -dv --verbose=2 "$STAGED_APP" 2>&1 | sed 's/^/    /' || true
if codesign --verify --verbose=2 "$STAGED_APP" 2>/dev/null; then
  echo "    signature: OK"
else
  echo "    signature: verify reported issues (ad-hoc local builds are often fine)"
fi

if [[ "$ZIP" -eq 1 ]]; then
  ZIP_PATH="${OUT_DIR}/${PRODUCT_NAME}-${VERSION}.zip"
  echo "==> Zipping ${ZIP_PATH}"
  rm -f "$ZIP_PATH"
  # -y store symlinks as symlinks; cd so the archive root is the .app name only.
  (
    cd "$OUT_DIR"
    ditto -c -k --sequesterRsrc --keepParent "${PRODUCT_NAME}.app" \
      "$(basename "$ZIP_PATH")"
  )
  echo "    zip: ${ZIP_PATH}"
fi

echo ""
echo "==> Release ready"
echo "    app:     ${STAGED_APP}"
echo "    version: ${VERSION} (${BUILD_NUM})"
if [[ "$ZIP" -eq 1 ]]; then
  echo "    zip:     ${OUT_DIR}/${PRODUCT_NAME}-${VERSION}.zip"
fi
echo ""
echo "    Install locally: open \"${STAGED_APP}\""
echo "    Or drag ${PRODUCT_NAME}.app into /Applications"

if [[ "$OPEN_APP" -eq 1 ]]; then
  if pgrep -x SimpleUsageBar >/dev/null 2>&1; then
    echo "==> Stopping existing SimpleUsageBar"
    pkill -x SimpleUsageBar || true
    for _ in 1 2 3 4 5; do
      pgrep -x SimpleUsageBar >/dev/null 2>&1 || break
      sleep 0.2
    done
  fi
  echo "==> Launching staged Release app"
  open "$STAGED_APP"
fi
