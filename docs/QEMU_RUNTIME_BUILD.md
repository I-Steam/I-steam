# Building the iOS QEMU runtime

i-Steam's native bridge expects an in-process, device-arm64 QEMU library exporting `qemu_init`, `qemu_main_loop`, and `qemu_cleanup`, plus the matching QEMU data files. UTM uses dynamically loaded `qemu-<arch>-softmmu` libraries; the packaging workflow searches the built app's dynamic libraries and refuses to label an executable or incompatible library as a runtime.

## Build

1. Open GitHub Actions in the `I-Steam/I-steam` mirror and run **Build UTM iOS QEMU runtime (manual)**.
2. Leave **Rebuild UTM dependencies** off for normal builds. The dependency cache key includes the checked-out upstream UTM commit SHA plus the runtime workflow and packaging script. Upstream UTM changes therefore cannot reuse a dependency tree built from a different UTM revision, and workflow-only Meson patch changes also invalidate the cache.
3. Enable **Rebuild UTM dependencies** if the cache is invalid or upstream dependency inputs change.
4. Download the `iSteam-qemu-runtime-ios-arm64` artifact from a successful run.

The workflow uses UTM's iOS build command, whose `-o UTMBuild` output is `UTMBuild.xcarchive`. It caches both UTM's `build-iOS-arm64` success marker and `sysroot-iOS-arm64`.

## Latest failure follow-up (2026-10-26)

The subsequent run [40325684693](https://github.com/I-Steam/I-steam/actions/runs/40325684693) passed the earlier `posix_memalign` compile stage but failed while linking QEMU's `libqemu-x86_64-softmmu.dylib` with undefined symbol `__isPlatformVersionAtLeast` from `tcg/region.c`. The workflow found Apple's `libclang_rt.ios.a`, but passing it via `--extra-ldflags` only affected configure-time flags; the actual Meson target link command did not contain the archive. The updated workflow now patches QEMU's `meson.build` before configuration and adds the runtime archive using `add_project_link_arguments`, which applies to the generated C target link commands. It removes the ineffective force-load flag from QEMU's configure arguments. The workflow change invalidates the dependency cache automatically through `hashFiles`.

This is a diagnosis-driven fix, not yet a verified successful build. Confirm that the next log's actual `libqemu-x86_64-softmmu.dylib` link command includes `libclang_rt.ios.a`, that the link succeeds, and that the artifact `iSteam-qemu-runtime-ios-arm64` is uploaded before treating the release workflow as unblocked.
 
## Latest failure and fix (2026-10-26)

The latest observed UTM runtime run, [40240044522](https://github.com/I-Steam/I-steam/actions/runs/40240044522), failed compiling QEMU 10.0.12 at `util/memalign.c:65` with `No function to allocate aligned memory available`. The dependent iOS release run, [40266823488](https://github.com/I-Steam/I-steam/actions/runs/40266823488), consequently failed while downloading the required runtime artifact; the IPA build step was skipped.

The workflow now keys the dependency cache by the actual checked-out UTM commit SHA and hashes the workflow/package script, so workflow patch changes invalidate stale configured build trees. Concurrency is scoped by Git ref: new runs cancel stale runs on the same branch but do not cancel a runtime build on another branch.

The first post-cache-fix build still failed. Its log showed Autoconf detecting `posix_memalign` successfully, while QEMU's own Meson configure step used `config-meson.cross` (not UTM's `meson-auto.cross`) and reported the same function as unavailable. This mismatch left `CONFIG_POSIX_MEMALIGN` unset and caused `util/memalign.c:65` to fail. The workflow now patches QEMU's `meson.build` at the exact feature probe, setting `CONFIG_POSIX_MEMALIGN` for this iOS-only build after confirming the expected upstream line is present. If upstream changes that line, the workflow fails with a clear diagnostic rather than silently building an incompatible runtime.

The cache remains fingerprinted by the workflow/package script, so this patch triggers a fresh dependency build. This is a targeted source-build fix, not yet a verified successful runtime build. The next run must compile past `util/memalign.c`, finish dependency compilation, produce the UTM archive, and upload the verified artifact before the release can succeed.

### Release/runtime ordering fix

The 2026-10-26 push exposed a second workflow bug: the iOS release job started at the same time as the first runtime build and failed with `no matching workflow run found with any artifacts`. The release workflow now ignores pushes that change the runtime workflow or packaging script and listens for completion of **Build UTM iOS QEMU runtime (manual)** instead. Its build matrix runs for that event only when the runtime workflow concludes successfully. Normal app-source pushes can still start a release using the most recent completed runtime artifact; scheduled and manually dispatched releases remain available. This removes the known first-build race without allowing a missing runtime to be silently ignored.

## Important limitations

The artifact build is not IPA integration. It must be copied into the app bundle at the path expected by `QEMURuntimeStatus`, all nested code must be correctly signed, and the bridge must be tested on a physical iPad. A build that fails to find a matching QEMU library or firmware is a real blocker, not a success to bypass. A guest boot must be verified before claiming the runtime is complete.

## Upstream references

- [UTM iOS development guide](https://github.com/utmapp/UTM/blob/main/Documentation/iOSDevelopment.md)
- [UTM QEMU lifecycle](https://github.com/utmapp/UTM/blob/main/Services/UTMQemuSystem.m)
- [UTM QEMU bootstrap](https://github.com/utmapp/UTM/blob/main/QEMULauncher/Bootstrap.c)
- [UTM dependency build script](https://github.com/utmapp/UTM/blob/main/scripts/build_dependencies.sh)


## Follow-up: force-load Apple compiler runtime (2026-10-27)

The link failure in runtime run [40325684693](https://github.com/I-Steam/I-steam/actions/runs/40325684693) occurred after QEMU compiled past the `util/memalign.c` failure. The final link command for `libqemu-x86_64-softmmu.dylib` did not include Apple's `libclang_rt.ios.a`, leaving `__isPlatformVersionAtLeast` undefined in `tcg/region.c`.

Commit [1a5311a8](https://gitlab.com/chantinlongxthrx/I-steam/-/commit/1a5311a807fbfa40e4e97f0962a54a6894f4b5e4) updates the QEMU Meson injection in `.github/workflows/build-qemu-runtime.yml` to add `-Wl,-force_load,<path-to-libclang_rt.ios.a>` directly to C target link arguments. This is intended to force the linker to load the archive member providing the missing platform-availability symbol, and it also updates the patch marker so repeated workflow runs do not insert duplicate Meson blocks. The existing workflow hash in the dependency cache key causes this workflow edit to use a fresh cache entry.

- **GitLab commit:** [1a5311a8](https://gitlab.com/chantinlongxthrx/I-steam/-/commit/1a5311a807fbfa40e4e97f0962a54a6894f4b5e4)
- **GitLab validation pipeline:** [#359](https://gitlab.com/chantinlongxthrx/I-steam/-/pipelines/2992191300) was running when this note was written.
- **GitHub runtime build:** not yet verified for this commit. Confirm the actual Ninja/clang link command contains the force-load argument and that QEMU links before marking the fix successful.
- **IPA/artifact/device:** no verified runtime artifact or IPA from this change yet; physical iPad boot, display/input, cleanup, and disk persistence remain untested.
