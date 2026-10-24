# QEMU runtime integration

## Current state

i-Steam now has a native in-process lifecycle bridge based on UTM's iOS QEMU approach, plus disk/ISO argument wiring and startup/stop state handling. The app does not yet bundle the device-targeted QEMU dynamic library or its data/dependencies, so the current repository alone cannot boot a guest OS.

## Required work

1. Build UTM's compatible QEMU fork for the actual iOS device arm64 target. A macOS or simulator build cannot run on an iPad.
2. Package the resulting QEMU library, matching data files, and all required dependencies in the app bundle.
3. Verify the exact exported lifecycle signatures for the pinned build; do not infer symbols from a different QEMU revision.
4. Integrate a real display backend such as UTM's SPICE stack and connect it to the i-Steam guest display. The current Metal view is not connected to QEMU framebuffer output.
5. Route keyboard, pointer, touch, and controller input into the configured QEMU devices.
6. Test lifecycle, storage, firmware, networking, and a redistributable test image on a physical device. UTM's iOS QEMU runtime can only be initialized once per app process; do not promise in-process restart.
7. Keep the app's status honest: native main-loop activity is not proof that a guest OS has completed booting.

## Upstream references

- QEMU: https://gitlab.com/qemu-project/qemu
- UTM: https://github.com/utmapp/UTM
- UTM iOS build guide: https://github.com/utmapp/UTM/blob/main/Documentation/iOSDevelopment.md
- UTM QEMU bootstrap: https://github.com/utmapp/UTM/blob/main/QEMULauncher/Bootstrap.c

## Validation boundary

GitLab CI currently validates workflow/project configuration and source-format invariants. The GitHub workflow packages app targets, but neither validation proves that a QEMU runtime is bundled or that a guest boots. Do not remove that distinction from release notes until a physical-device boot test passes.

## Licensing

i-Steam is GPL-3.0. QEMU and UTM-derived source have their own license terms; audit the exact configured runtime and preserve upstream notices before redistribution.
