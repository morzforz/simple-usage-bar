#!/usr/bin/env bash
# build_and_run.sh — Build SimpleUsageBar (Debug) and launch the .app
#
# Usage:
#   ./Scripts/build_and_run.sh
#   ./Scripts/build_and_run.sh --release
#   ./Scripts/build_and_run.sh --no-run          # build only
#   ./Scripts/build_and_run.sh --clean           # clean before build
#
# Requires full Xcode at /Applications/Xcode.app when xcode-select points
# at Command Line Tools only.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

SCHEME="SimpleUsageBar"
PROJECT="SimpleUsageBar.xcodeproj"
CONFIGURATION="Debug"
CLEAN=0
RUN=1
DERIVED_DATA="${ROOT}/.derivedData"

# Prefer full Xcode so builds work even when xcode-select is CLT-only.
if [[ -d /Applications/Xcode.app/Contents/Developer ]]; then
  export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
fi

usage() {
  sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'
  exit "${1:-0}"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --release) CONFIGURATION="Release"; shift ;;
    --debug)   CONFIGURATION="Debug"; shift ;;
    --clean)   CLEAN=1; shift ;;
    --no-run)  RUN=0; shift ;;
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

echo "==> Building ${SCHEME} (${CONFIGURATION})"
echo "    DEVELOPER_DIR=${DEVELOPER_DIR:-"(xcode-select default)"}"
echo "    derivedData=${DERIVED_DATA}"

XCB_ARGS=(
  -project "$PROJECT"
  -scheme "$SCHEME"
  -configuration "$CONFIGURATION"
  -derivedDataPath "$DERIVED_DATA"
  -destination "platform=macOS"
)

if [[ "$CLEAN" -eq 1 ]]; then
  echo "==> Clean"
  xcodebuild "${XCB_ARGS[@]}" clean
fi

xcodebuild "${XCB_ARGS[@]}" build

APP="${DERIVED_DATA}/Build/Products/${CONFIGURATION}/SimpleUsageBar.app"
if [[ ! -d "$APP" ]]; then
  echo "error: expected app not found at ${APP}" >&2
  exit 1
fi

echo "==> Built: ${APP}"

if [[ "$RUN" -eq 0 ]]; then
  echo "==> Skipping launch (--no-run)"
  exit 0
fi

# Restart so a previous instance does not leave a stale menubar item.
if pgrep -x SimpleUsageBar >/dev/null 2>&1; then
  echo "==> Stopping existing SimpleUsageBar"
  pkill -x SimpleUsageBar || true
  # Brief wait for the process to exit
  for _ in 1 2 3 4 5; do
    pgrep -x SimpleUsageBar >/dev/null 2>&1 || break
    sleep 0.2
  done
fi

echo "==> Launching"
open "$APP"

# Confirm it came up (menubar chrome is not scriptable here).
sleep 0.5
if pgrep -x SimpleUsageBar >/dev/null 2>&1; then
  echo "==> Running (pid $(pgrep -x SimpleUsageBar | tr '\n' ' '))"
else
  echo "warning: process not seen yet; check Console if the menubar item is missing" >&2
fi
