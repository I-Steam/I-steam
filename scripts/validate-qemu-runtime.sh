#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 /path/to/manifest-selected-QEMU-library" >&2
  exit 64
fi

library="$1"
[[ -f "$library" ]] || { echo "Missing runtime library: $library" >&2; exit 2; }

for tool in file lipo nm codesign; do
  command -v "$tool" >/dev/null 2>&1 || {
    echo "Required Apple validation tool is unavailable: $tool" >&2
    exit 4
  }
done

echo "== File type =="
file "$library"
if ! file "$library" | grep -q 'Mach-O'; then
  echo "Runtime is not a Mach-O binary." >&2
  exit 3
fi

echo "== Device architecture =="
architectures="$(lipo -archs "$library")"
printf '%s\n' "$architectures"
case " $architectures " in
  *" arm64 "*) ;;
  *)
    echo "Runtime does not contain the physical iOS arm64 architecture: $architectures" >&2
    exit 3
    ;;
esac

echo "== Defined external lifecycle symbols =="
# -U excludes undefined imports. Do not fall back to plain nm -g: that can
# mistake an undefined reference for an exported implementation.
symbols="$(nm -gU "$library")"
for symbol in qemu_init qemu_main_loop qemu_cleanup; do
  if ! grep -Eq "[[:space:]][A-Za-z][[:space:]]_?${symbol}$" <<<"$symbols"; then
    echo "Missing required defined export: $symbol" >&2
    exit 3
  fi
  echo "Found required export: $symbol"
done

if grep -Eq '[[:space:]][A-Za-z][[:space:]]_?qemu_system_shutdown_request$' <<<"$symbols"; then
  echo "Found optional graceful-shutdown export: qemu_system_shutdown_request"
else
  echo "Optional export absent: qemu_system_shutdown_request (graceful stop unavailable)"
fi

echo "== Code signature =="
codesign --verify --strict "$library"

echo "QEMU runtime architecture, required exports, and code signature verified."
echo "This does not prove dependent libraries load or that a guest boots."
