# Building the iOS QEMU runtime

i-Steam uses an in-process QEMU lifecycle bridge. A usable runtime must be a device-arm64 Mach-O library that exports `qemu_init`, `qemu_main_loop`, and `qemu_cleanup`, and it must ship the matching QEMU data files. Merely building the UTM app or downloading its archive is not enough.

## Build

1. Open GitHub Actions in the `I-Steam/I-steam` mirror and run **Build UTM iOS QEMU runtime (manual)**.
2. Leave **Rebuild UTM dependencies** off for a cached build; turn it on only when the upstream dependency inputs changed or the cached sysroot is invalid.
3. Download the `iSteam-qemu-runtime-ios-arm64` artifact from a successful run.

The workflow builds upstream UTM for physical iOS arm64, then runs `scripts/package-utm-qemu-runtime.sh`. That script rejects candidates that do not export the lifecycle ABI or are not arm64, and rejects archives with no discoverable QEMU BIOS/data directory. It packages the library and data under `QEMU/`.

## Current limitation

This is a validated runtime artifact, not yet an automatic IPA integration. It must still be embedded at the paths expected by `QEMURuntimeStatus`, signed as part of the app, and exercised on a physical iPad. The QEMU runtime cannot be considered finished until the workflow succeeds and a guest OS boots on-device. Do not use an upstream UTM executable or a library with different lifecycle exports as a substitute.

## Upstream references

- [UTM iOS development guide](https://github.com/utmapp/UTM/blob/main/Documentation/iOSDevelopment.md)
- [UTM QEMU bootstrap lifecycle](https://github.com/utmapp/UTM/blob/main/QEMULauncher/Bootstrap.c)
- [UTM architecture notes](https://github.com/utmapp/UTM/blob/main/Documentation/Architecture.md)
