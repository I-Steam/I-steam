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
- **GitHub runtime build:** [run 40424165904](https://github.com/I-Steam/I-steam/actions/runs/40424165904) was running from the synced main commit when this update was recorded. Its dependency-install step was still in progress; the QEMU link fix has not yet been tested by this run.
- **IPA/artifact/device:** no verified runtime artifact or IPA from this change yet; physical iPad boot, display/input, cleanup, and disk persistence remain untested.


## Follow-up: workflow patcher syntax error (2026-10-27)

Runtime run [40424165904](https://github.com/I-Steam/I-steam/actions/runs/40424165904) failed before dependency compilation. The workflow's outer Python patcher used a triple-double-quoted string for the embedded shell/Python patch, and that embedded patch itself contained `link_block = """`; Python ended the outer string early and raised `SyntaxError` at the Meson `check: true` argument. The workflow now uses a triple-single-quoted raw string for the embedded Meson `link_block`, avoiding delimiter collision with the outer triple-double-quoted `qemu_patch` string. This is a syntax-only repair; the compiler-rt link fix remains unverified until a new runtime run passes dependency compilation and QEMU linking.

- **Failing run:** [40424165904](https://github.com/I-Steam/I-steam/actions/runs/40424165904)
- **Failure:** Python `SyntaxError` in `Build UTM dependencies for physical iOS arm64`; QEMU compilation was not reached.
- **Next validation:** confirm the patching script exits successfully, dependencies build, QEMU's actual link command includes `-Wl,-force_load,<libclang_rt.ios.a>`, and the runtime artifact is uploaded.


## Manual release and QEMU artifact ordering (2026-10-27)

The release workflow intentionally ignores workflow-only/runtime-patcher pushes and uses `workflow_run` to publish after the QEMU runtime build succeeds. Previously, manually dispatching a release immediately searched for an artifact on `main`; if no successful runtime artifact existed yet, `dawidd6/action-download-artifact` failed with “no artifact found.” The runtime artifact is produced only by the final upload step after the UTM archive is built and validated.

The release workflow now has a `prepare-runtime` job for manual dispatches. It reuses a queued/in-progress main runtime run when one exists; otherwise it dispatches the QEMU workflow and waits for completion. It fails with the exact runtime run URL if the runtime build fails or completes without `iSteam-qemu-runtime-ios-arm64`. The iOS build downloads the artifact from that exact run ID. Automatic `workflow_run` releases likewise use the completed upstream runtime run ID, avoiding ambiguity about which artifact was selected. Push/scheduled releases continue using the latest successful main-branch runtime artifact.

This workflow change is source-level only until GitLab validation and a GitHub Actions run prove the dispatch permission, wait loop, artifact lookup, and downstream IPA integration. A successful runtime artifact and physical iPad guest boot remain unverified.


## Same-run runtime-before-app build pipeline (2026-10-27)

The release workflow now invokes `.github/workflows/build-qemu-runtime.yml` as a reusable workflow job named `qemu-runtime`. GitHub Actions executes the reusable workflow within the caller's run, so its uploaded QEMU artifact is available to downstream app jobs under that same run ID. This removes cross-run artifact searching and branch/retention ambiguity.

- The app matrix declares `needs: qemu-runtime`; iOS, tvOS, and visionOS builds do not start unless runtime compilation, packaging, verification, and artifact upload all succeed.
- The iOS app downloads `iSteam-qemu-runtime-ios-arm64` with `actions/download-artifact@v4` from the current run. Existing checks still validate the manifest, QEMU library exports, embedded library, and data before producing the IPA.
- `.github/workflows/build-qemu-runtime.yml` now supports `workflow_call` while retaining standalone push/manual triggers for diagnostics.
- Fixed the embedded Python patcher's escaping: the nested `source.find("\\\\n", project_end)` expression must remain escaped inside the outer Python string rather than becoming a literal line break in the inner script.
- This structural fix does not prove upstream UTM/QEMU compiles. The next Actions run must confirm dependency compilation, archive packaging, artifact upload, and IPA integration. Physical-device guest boot remains unverified.
