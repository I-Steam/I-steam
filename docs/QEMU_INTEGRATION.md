# QEMU runtime integration

## Goal

Replace the command-preview-only `QEMUBackend` with a real in-process QEMU runtime so i-Steam can boot guest operating systems. The current app does not ship a QEMU executable or QEMU libraries; do not mark a VM as running until a guest machine has actually started.

## Upstream implementation to reuse

- QEMU source: https://gitlab.com/qemu-project/qemu
- UTM Apple-platform integration/reference: https://github.com/utmapp/UTM
- UTM's QEMU configuration and argument construction: https://github.com/utmapp/UTM/tree/main/Configuration
- UTM's QEMU launcher/runtime integration: https://github.com/utmapp/UTM/tree/main/QEMULauncher

Use upstream source and preserve its license notices. i-Steam is GPL-3.0; QEMU is generally GPL-2.0-or-later, but individual QEMU modules and bundled dependencies can have different licenses. Audit the exact configured build before redistributing it. Do not copy UTM code wholesale without preserving its GPL-3.0 license and notices.

## Required integration steps

1. Build QEMU for the actual iOS target (arm64 device), not macOS or the iOS simulator. Start with `x86_64-softmmu` for x86 Windows/Linux guests; add `aarch64-softmmu` separately if required. Disable unsupported host features and configure a supported display/device path.
2. Package the resulting runtime and every required data file in the app bundle. A system-installed `qemu-system-x86_64` binary cannot be assumed on iOS.
3. Integrate QEMU's supported in-process entry points from the exact pinned QEMU revision. Do not guess C function signatures or dynamically call undocumented symbols: QEMU's embedding interfaces vary by build/revision.
4. Map the app's VM configuration to QEMU arguments, including machine, CPU, RAM, firmware, storage, networking, input and display. Reject unsupported options instead of silently ignoring them.
5. Connect the guest display output to the iOS Metal/MetalKit view and route controller, keyboard and pointer events into QEMU's input devices.
6. Add lifecycle handling for start, stop, pause/resume, cancellation, crash reporting and cleanup. Do not block the main thread.
7. Add CI checks that confirm the packaged device runtime exists and exports the expected integration API, then run a boot smoke test with a redistributable test image. An IPA build alone does not prove an OS boots.

## Current status

The Swift `QEMUBackend` only previews a command line. iOS apps cannot launch an arbitrary command-line executable as if they were desktop apps, and this repository currently has no compiled QEMU runtime. The current `VMEngine` intentionally fails the session rather than pretending the guest is running. Keep that guard until the real runtime and boot smoke test are in place.

## Scope and expectations

A successful QEMU boot is only the first milestone. Running Windows games additionally needs a usable guest graphics path, input, storage, audio/networking, and a compatible Windows game runtime such as Wine/Proton where applicable. JIT availability alone does not supply these components.