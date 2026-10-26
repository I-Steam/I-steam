# Building the iOS QEMU runtime

i-Steam's native bridge expects an in-process, device-arm64 QEMU library exporting `qemu_init`, `qemu_main_loop`, and `qemu_cleanup`, plus the matching QEMU data files. UTM uses dynamically loaded `qemu-<arch>-softmmu` libraries; the packaging workflow searches the built app's dynamic libraries and refuses to label an executable or incompatible library as a runtime.

## Build

1. Open GitHub Actions in the `I-Steam/I-steam` mirror and run **Build UTM iOS QEMU runtime (manual)**.
2. Leave **Rebuild UTM dependencies** off for normal builds. The dependency cache is now versioned against the runtime workflow and packaging script as well as UTM's dependency inputs. A change to Meson cross-file patching therefore invalidates a potentially stale configured QEMU build tree.
3. Enable **Rebuild UTM dependencies** if the cache is invalid or upstream dependency inputs change.
4. Download the `iSteam-qemu-runtime-ios-arm64` artifact from a successful run.

The workflow uses UTM's iOS build command, whose `-o UTMBuild` output is `UTMBuild.xcarchive`. It caches both UTM's `build-iOS-arm64` success marker and `sysroot-iOS-arm64`.

## Latest failure and fix (2026-10-26)

The latest observed UTM runtime run, [40240044522](https://github.com/I-Steam/I-steam/actions/runs/40240044522), failed compiling QEMU 10.0.12 at `util/memalign.c:65` with `No function to allocate aligned memory available`. The dependent iOS release run, [40266823488](https://github.com/I-Steam/I-steam/actions/runs/40266823488), consequently failed while downloading the required runtime artifact; the IPA build step was skipped.

The workflow already patches UTM's Meson cross-file generator to add `has_function_posix_memalign = true`. However, its old cache key hashed UTM dependency inputs only, not the workflow that injects this patch. A cached QEMU build tree could therefore be restored with Meson configuration generated before the override. The repair bumps the cache namespace to `v4`, includes the runtime workflow and packaging script in `hashFiles`, adds a clear assertion that the patch is installed, and runs the runtime build workflow on `fix/**` branches so the change can be tested before merging.

This is a root-cause hypothesis supported by the cache-key omission and the compile error, not yet a verified successful build. The next run must get past `util/memalign.c`, finish dependency compilation, produce the UTM archive, and upload the verified artifact before the release can succeed.

## Important limitations

The artifact build is not IPA integration. It must be copied into the app bundle at the path expected by `QEMURuntimeStatus`, all nested code must be correctly signed, and the bridge must be tested on a physical iPad. A build that fails to find a matching QEMU library or firmware is a real blocker, not a success to bypass. A guest boot must be verified before claiming the runtime is complete.

## Upstream references

- [UTM iOS development guide](https://github.com/utmapp/UTM/blob/main/Documentation/iOSDevelopment.md)
- [UTM QEMU lifecycle](https://github.com/utmapp/UTM/blob/main/Services/UTMQemuSystem.m)
- [UTM QEMU bootstrap](https://github.com/utmapp/UTM/blob/main/QEMULauncher/Bootstrap.c)
- [UTM dependency build script](https://github.com/utmapp/UTM/blob/main/scripts/build_dependencies.sh)
