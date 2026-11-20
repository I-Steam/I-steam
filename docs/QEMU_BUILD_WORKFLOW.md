# QEMU iOS runtime build workflow

This note documents the iOS device-arm64 QEMU runtime build in `.github/workflows/build-qemu-runtime.yml` and the patch/verification scripts it invokes.

## Build flow

1. Check out UTM and its submodules on macOS 15 with Xcode and the iOS device SDK.
2. Locate Apple's `libclang_rt.ios.a` from the selected Xcode toolchain and expose it as `IOS_COMPILER_RT`.
3. Restore the UTM dependency/sysroot cache only when its key matches the UTM commit, selected Xcode/iOS SDK versions, and the workflow plus all QEMU patch scripts. The cache namespace is bumped when build behavior changes.
4. Run `scripts/patch_utm_qemu_ios.py` against UTM's `scripts/build_dependencies.sh`. The patch is idempotent and fails if upstream changes the expected integration points.
5. During UTM's dependency build, `scripts/patch_qemu_meson_ios.py` updates QEMU's iOS POSIX_MEMALIGN feature and adds `add_project_link_arguments` for Apple's compiler runtime to QEMU C targets.
6. Immediately after QEMU's Meson configure step and before its compilation starts, UTM invokes `scripts/verify_qemu_meson_link.py` against `QEMU_DIR/build/build.ninja`. It requires the `libqemu-x86_64-softmmu.dylib` link edge itself to contain the exact `-Wl,-force_load,<libclang_rt.ios.a>` argument. The build stops before thousands of compile tasks if the argument is absent.
7. Build the UTM iOS archive, package its device-arm64 QEMU library, framework dependencies and firmware/data, validate the artifact, and upload `iSteam-qemu-runtime-ios-arm64`.
8. The release workflow downloads that artifact from the same workflow run before packaging the iOS IPA; it does not fall back to a stale or optional runtime artifact.

## Patch and test files

- `scripts/patch_utm_qemu_ios.py` — idempotently patches the upstream UTM dependency script: POSIX_MEMALIGN cross-file feature, x86_64-softmmu target selection, QEMU Meson patch invocation, and a pre-build link verification hook.
- `scripts/patch_qemu_meson_ios.py` — patches QEMU's Meson feature probe and adds the project-level C linker argument using the Xcode compiler runtime path.
- `scripts/verify_qemu_meson_link.py` — inspects the generated Ninja link edge for `libqemu-x86_64-softmmu.dylib`; verifies the actual link configuration rather than checking only environment variables or source text.
- `scripts/tests/test_qemu_build_patches.py` — regression tests idempotence, expected patch insertion and fail-closed linker verification.
- `.github/workflows/build-qemu-runtime.yml` — reusable/manual runtime build, cache fingerprint and same-run artifact upload.
- `.github/workflows/release.yml` — runtime dependency ordering and required artifact download before the iOS IPA is packaged.
- `.github/workflows/validate-repository.yml` — strict YAML checks, both-direction mirror preservation, workflow contract checks and Python patcher tests.

## Run locally on macOS

```sh
python3 scripts/patch_utm_qemu_ios.py UTM/scripts/build_dependencies.sh
IOS_COMPILER_RT=/path/to/libclang_rt.ios.a python3 scripts/patch_qemu_meson_ios.py UTM/build-iOS-arm64/qemu-*/meson.build
python3 -m unittest discover -s scripts/tests -p 'test_*.py'
```

The normal workflow invokes the Meson patcher only after UTM has downloaded the QEMU source, and invokes the Ninja verifier after QEMU configure has generated `build/build.ninja`.

## Failure diagnosis and limits

- The previously observed link failure was `___isPlatformVersionAtLeast` unresolved in `tcg/region.c.o`; the compiler-runtime archive appeared in top-level `LDFLAGS` but was absent from QEMU's generated Meson target link command.
- The new pre-build verifier checks that exact target edge. It is designed to fail early if a future UTM/QEMU update stops propagating the Meson project linker arguments.
- A passing Ninja-file check proves only that the compiler-runtime argument is present in the configured link command. It does not prove that QEMU compiles, packages, loads on iOS, or boots a guest.
- The runtime workflow remains a macOS/Xcode CI job. It cannot be executed from an iPad browser or by the GitLab source editor itself.
- Do not modify `.github/workflows/blank.yml`; it is the required GitHub → GitLab sync workflow. The repository validator explicitly checks that it remains present.

## Validation

Run `python3 -m unittest discover -s scripts/tests -p 'test_*.py'` for the deterministic patcher tests. The full CI workflow additionally validates YAML with duplicate-key rejection, checks the release/runtime artifact contract, validates QEMU source integration, and compiles the iOS/tvOS/visionOS simulator schemes. A successful simulator or source-validation job is not evidence of a physical iPad guest boot.
