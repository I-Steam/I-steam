#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 3 ]; then
  echo "Usage: $0 <archive.ipa> <expected-app.app> <expected-bundle-id>" >&2
  exit 2
fi

archive="$1"
app_name="$2"
expected_bundle="$3"

test -s "$archive"
listing="$(unzip -Z1 "$archive")"
printf '%s\n' "$listing" | grep -Fx "Payload/$app_name/Info.plist" >/dev/null || {
  echo "Invalid Apple package: Payload/$app_name/Info.plist is missing." >&2
  printf '%s\n' "$listing" | sed -n '1,40p' >&2
  exit 1
}

plist="$(mktemp)"
trap 'rm -f "$plist"' EXIT
unzip -p "$archive" "Payload/$app_name/Info.plist" > "$plist"
actual_bundle="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$plist")"
if [ "$actual_bundle" != "$expected_bundle" ]; then
  echo "Bundle ID mismatch: expected $expected_bundle, found $actual_bundle" >&2
  exit 1
fi

printf 'Package OK: %s (%s)\n' "$app_name" "$actual_bundle"
