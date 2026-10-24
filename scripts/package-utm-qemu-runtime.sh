#!/usr/bin/env bash
set -euo pipefail

ARCHIVE="${1:?usage: package-utm-qemu-runtime.sh /path/to/UTM.xcarchive /path/to/output}"
OUT="${2:?usage: package-utm-qemu-runtime.sh /path/to/UTM.xcarchive /path/to/output}"
APP="$ARCHIVE/Products/Applications/UTM.app"
test -d "$APP" || { echo "UTM.app missing from archive: $APP" >&2; exit 1; }

rm -rf "$OUT"
mkdir -p "$OUT/QEMU"
: > "$OUT/runtime-file-inventory.txt"
# UTM names its dynamically loaded emulator libraries qemu-<arch>-softmmu;
# search all dylibs too so harmless filename changes do not break discovery.
find "$APP" -type f \( -name '*.dylib' -o -name 'QEMU' -o -name 'qemu-*softmmu*' \) -print | tee "$OUT/runtime-file-inventory.txt"

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
  echo "No UTM in-process QEMU library exporting qemu_init, qemu_main_loop, and qemu_cleanup was found." >&2
  echo "Inventory of candidate files is saved to runtime-file-inventory.txt; check the UTM archive and target architecture." >&2
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
for root in "$APP"; do
  [ -d "$root" ] || continue
  found="$(find "$root" -type f \( -name 'bios-256k.bin' -o -name 'vgabios-stdvga.bin' -o -name 'edk2-x86_64-code.fd' -o -name 'OVMF_CODE.fd' \) -print -quit 2>/dev/null || true)"
  if [ -n "$found" ]; then data_dir="$(dirname "$found")"; break; fi
done
if [ -z "$data_dir" ]; then
  echo "QEMU lifecycle library was found, but no recognizable QEMU BIOS/firmware data files were found." >&2
  exit 4
fi

# Keep the data directory at the exact location passed to QEMU's -L argument.
cp -R "$data_dir"/. "$OUT/QEMU/"

cat > "$OUT/BUILD-INFO.txt" <<EOF
Source: utmapp/UTM at the revision checked out by the workflow
Target: physical iOS arm64
Library source: $candidate
Architectures: $ARCHS
Lifecycle exports: verified by nm before packaging
Data source: $data_dir
Package layout: QEMU/libqemu-system-x86_64.dylib plus QEMU data files at QEMU/
Important: embed and code-sign the library in i-Steam and boot-test on a physical device before claiming runtime support.
EOF

test -s "$OUT/QEMU/libqemu-system-x86_64.dylib"
find "$OUT/QEMU" -type f -size +0c ! -name 'libqemu-system-x86_64.dylib' -print -quit | grep -q .
