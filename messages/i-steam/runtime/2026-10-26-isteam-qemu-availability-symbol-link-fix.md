# i-Steam — QEMU compiler-runtime link failure

- **Date:** 2026-10-26
- **Status:** Fix committed; awaiting runtime CI verification
- **Canonical repository:** https://gitlab.com/chantinlongxthrx/I-steam
- **Branch:** main
- **Related source/repository:** https://github.com/I-Steam/I-steam

## Directory and file changes
- `.github/workflows/build-qemu-runtime.yml` — patches QEMU's Meson project before configuration to explicitly link Apple's iOS compiler-runtime archive into C-linked QEMU targets.
- `.gitlab-ci.yml` — validates the explicit compiler-runtime link patch and rejects the previous ineffective `--extra-ldflags=-Wl,-force_load,...` approach.
- `docs/QEMU_RUNTIME_BUILD.md` — records the observed linker failure and next verification criteria.

## Changes made
- Investigated runtime run [40325684693](https://github.com/I-Steam/I-steam/actions/runs/40325684693). The earlier `posix_memalign` error was passed; QEMU later failed at link time with undefined `__isPlatformVersionAtLeast`, referenced by `tcg/region.c`.
- The log confirms the compiler-runtime archive existed and appeared in configure-time `LDFLAGS`, but was absent from the generated Meson target link command.
- The workflow now patches QEMU's `meson.build` to read `IOS_COMPILER_RT` from the environment and call `add_project_link_arguments(ios_compiler_rt, language: 'c')` before targets are declared. It removes the old extra-ldflags force-load attempt.
- Dependency cache invalidation continues to include the workflow content hash, so this change should create a fresh build tree.

## Evidence and validation
- **Failure run:** https://github.com/I-Steam/I-steam/actions/runs/40325684693 — failed in dependency build while linking `libqemu-x86_64-softmmu.dylib`.
- **Source diagnosis:** actual link line lacked `libclang_rt.ios.a`; linker reported `___isPlatformVersionAtLeast`.
- **Commit/pipeline:** to be filled after canonical commit and GitLab CI validation.
- **Device/runtime test:** Not tested.

## Blockers and unverified items
- The new Meson link argument patch has not yet run in CI.
- A successful runtime artifact, IPA packaging, physical iPad guest boot, and persistence remain unverified.

## Next actions
1. Confirm GitLab validation passes and GitLab-to-GitHub sync reaches the new commit.
2. Inspect the next QEMU link command for `libclang_rt.ios.a` and confirm the undefined symbol is resolved.
3. Verify the runtime artifact upload, then verify release IPA integration.
