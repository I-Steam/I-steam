# Building the iOS QEMU runtime

i-Steam's native bridge expects an in-process, device-arm64 QEMU library exporting `qemu_init`, `qemu_main_loop`, and `qemu_cleanup`, plus the matching QEMU data files. UTM uses dynamically loaded `qemu-<arch>-softmmu` libraries; the packaging workflow searches the built app's dynamic libraries and refuses to label an executable or incompatible library as a runtime.

## Build

1. Open GitHub Actions in the `I-Steam/I-steam` mirror and run **Build UTM iOS QEMU runtime (manual)**.
2. Leave **Rebuild UTM dependencies** off to reuse the cached dependency build; enable it when upstream dependency inputs change or the cache is invalid.
3. Download the `iSteam-qemu-runtime-ios-arm64` artifact from a successful run.

The workflow uses UTM's documented iOS build command, whose `-o UTMBuild` output is `UTMBuild.xcarchive`. It caches both UTM's `build-iOS-arm64` success marker and `sysroot-iOS-arm64`.

## Latest build failure and targeted fix (2026-10-25)

The most recent recorded GitHub Actions runtime build (#8) failed compiling QEMU 10.0.12 at `util/memalign.c:65` with `No function to allocate aligned memory available`. Adding `-DCONFIG_POSIX_MEMALIGN` as a compiler flag did not work because QEMU generates `config-host.h` from Meson's feature checks, which can override command-line defines.

The workflow now patches UTM's generated Meson cross-file function override to set `has_function_posix_memalign = true`, so the generated QEMU host configuration should select `posix_memalign()` for the iOS target. The ineffective direct `CONFIG_POSIX_MEMALIGN` compiler define was removed. This is a targeted fix inferred from the observed compiler error and Meson/QEMU configuration behavior; it is **not yet verified** until a new runtime build gets past this source file.

## Important limitations

The artifact build is not IPA integration. It must be copied into the app bundle at the path expected by `QEMURuntimeStatus`, all nested code must be correctly signed, and the bridge must be tested on a physical iPad. A build that fails to find a matching QEMU library or firmware is a real blocker, not a success to bypass. A guest boot must be verified before claiming the runtime is complete.

## Upstream references

- [UTM iOS development guide](https://github.com/utmapp/UTM/blob/main/Documentation/iOSDevelopment.md)
- [UTM QEMU lifecycle](https://github.com/utmapp/UTM/blob/main/Services/UTMQemuSystem.m)
- [UTM QEMU bootstrap](https://github.com/utmapp/UTM/blob/main/QEMULauncher/Bootstrap.c)
- [UTM dependency build script](https://github.com/utmapp/UTM/blob/main/scripts/build_dependencies.sh)
