#!/usr/bin/env bash
set -euo pipefail

ARCHIVE="${1:?usage: package-utm-qemu-runtime.sh /path/to/UTM.xcarchive /path/to/output}"
OUT="${2:?usage: package-utm-qemu-runtime.sh /path/to/UTM.xcarchive /path/to/output}"
APP="$ARCHIVE/Products/Applications/UTM.app"
test -d "$APP" || { echo "UTM.app missing from archive: $APP" >&2; exit 1; }

rm -rf "$OUT"
mkdir -p "$OUT/QEMU"
: > "$OUT/runtime-file-inventory.txt"
find "$APP" -type f \( -name 'QEMU' -o -name 'libqemu-system-x86_64.dylib' -o -name 'qemu-system-x86_64' \) -print | tee "$OUT/runtime-file-inventory.txt"

candidate=""
while IFS= read -r file; do
  [ -n "$file" ] || continue
  if file "$file" | grep -q 'Mach-O'; then
    exports="$(nm -gU "$file" 2>/dev/null || true)"
    if printf '%s\n' "$exports" | grep -qE ' _?qemu_init$' &&
       printf '%s\n' "$exports" | grep -qE ' _?qemu_main_loop$' &&
       printf '%s\n' "$exports" | grep -qE ' _?qemu_cleanup$'; then
      candidate="$file"
      break
    fi
  fi
done < "$OUT/runtime-file-inventory.txt"

if [ -z "$candidate" ]; then
  echo "No in-process QEMU binary exporting qemu_init, qemu_main_loop, and qemu_cleanup was found in UTM.app." >&2
  echo "Do not rename an executable or ship an ABI-incompatible library as the i-Steam runtime." >&2
  exit 2
fi

ARCHS="$(lipo -archs "$candidate")"
case " $ARCHS " in
  *" arm64 "*) ;;
  *) echo "QEMU candidate is not device arm64: $candidate ($ARCHS)" >&2; exit 3 ;;
esac

cp "$candidate" "$OUT/QEMU/libqemu-system-x86_64.dylib"
chmod 755 "$OUT/QEMU/libqemu-system-x86_64.dylib"
printf '%s\n' "$exports" | grep -E ' _?qemu_(init|main_loop|cleanup)$| _?qemu_system_shutdown_request$' > "$OUT/exports.txt" || true

data_dir=""
for root in "$APP" "$(dirname "$ARCHIVE")"; do
  [ -d "$root" ] || continue
  found="$(find "$root" -type f \( -name 'bios-256k.bin' -o -name 'vgabios-stdvga.bin' \) -print -quit 2>/dev/null || true)"
  if [ -n "$found" ]; then data_dir="$(dirname "$found")"; break; fi
done
if [ -z "$data_dir" ]; then
  echo "QEMU lifecycle library was found, but no QEMU BIOS/data directory was found. Runtime cannot boot guests without data files." >&2
  exit 4
fi
mkdir -p "$OUT/QEMU/share"
cp -R "$data_dir"/. "$OUT/QEMU/share/"

cat > "$OUT/BUILD-INFO.txt" <<EOF
Source: utmapp/UTM at the revision checked out by the workflow
Target: physical iOS arm64
Library source: $candidate
Architectures: $ARCHS
Lifecycle exports: verified by nm before packaging
Data source: $data_dir
Package layout: QEMU/libqemu-system-x86_64.dylib and QEMU/share/
Important: this artifact still must be embedded and code-signed in i-Steam, and guest boot must be tested on a physical device.
EOF

test -s "$OUT/QEMU/libqemu-system-x86_64.dylib"
find "$OUT/QEMU/share" -type f -size +0c -print -quit | grep -q .
