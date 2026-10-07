#!/bin/sh
set -e

ROOT="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
cd "$ROOT"

if ! command -v xcodegen >/dev/null 2>&1; then
  echo "xcodegen is required."
  exit 1
fi

xcodegen generate

echo "Generated iSteam.xcodeproj"
