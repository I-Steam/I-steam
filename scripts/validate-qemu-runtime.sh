#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 /path/to/libqemu-system-aarch64.dylib" >&2
  exit 64
fi

library="$1"
[[ -f "$library" ]] || { echo "Missing runtime: $library" >&2; exit 2; }
command -v file >/dev/null
command -v nm >/dev/null

echo "== File type =="
file "$library"

echo "== Architecture =="
if command -v lipo >/dev/null 2>&1; then
  lipo -info "$library"
fi

symbols="$(nm -gU "$library" 2>/dev/null || nm -g "$library" 2>/dev/null || true)"
for symbol in qemu_init qemu_main_loop qemu_cleanup qemu_system_shutdown_request; do
  if ! grep -Eq "[[:space:]_]${symbol}$" <<<"$symbols"; then
    echo "Missing required exported symbol: $symbol" >&2
    exit 3
  fi
done

if command -v codesign >/dev/null 2>&1; then
  codesign --verify --strict "$library"
fi

echo "QEMU lifecycle symbols and code signature verified."
echo "Note: this checks packaging and exports only; it does not prove that a guest boots."
