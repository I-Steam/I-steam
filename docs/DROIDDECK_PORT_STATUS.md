# DroidDeck port status

This status tracks code that is native to i-Steam, not a promise that Android binaries execute on Apple platforms.

## Implemented in the native app

- Library metadata, search/favourites, per-game preferences and JSON backup/restore.
- Artwork import into app storage with security-scoped access, coordinated reads, size bounds and image decoding validation.
- Local compatibility records for titles, runtime versions, devices and notes. Entries are user-maintained and are not automatically labelled as verified.
- Runtime component manifest parsing and local SHA-256 verification, including platform checks and traversal-safe relative paths.
- Existing controller input abstractions, touch-gamepad prototype, frame pacing/preferences, diagnostics and document-picker import flows.

## Still not a finished engine

- **Full-system QEMU:** the app requires a real QEMU build compiled for arm64 iOS, packaged with its data files and device models. The bridge's presence is not proof that this library exists or that a guest boots.
- **Windows games:** PE parsing is not Win32 execution. Wine/Proton, syscall support, graphics, audio, input, networking and a compatible CPU execution path are not all integrated.
- **FEX / Box64:** Android/Linux builds are not iOS drop-ins. They need a supported iOS build, appropriate licensing, executable-memory/JIT strategy and device tests.
- **Linux desktop / Flatpak / AppImage:** these require a working Linux guest and package manager.
- **Turnip / Vulkan / Gamescope:** Android/Linux GPU drivers and compositors cannot be copied into an iOS app; graphics need an Apple-compatible backend.
- **SteamVR / vendor glasses / 6DoF:** require separate Apple-platform tracking, rendering and device integration.
- **Raw USB block devices:** iOS document-provider access does not expose arbitrary physical disks to a guest as block devices.

## QEMU runtime packaging status (2026-10-25)

The previous native runtime build failed at `util/memalign.c:65` because QEMU's generated configuration selected no aligned allocator. A later run ([#40239296591](https://github.com/I-Steam/I-steam/actions/runs/40239296591)) failed earlier because the workflow's Meson cross-file patch marker no longer matched current UTM source. The workflow now anchors on UTM's `has_function_dup3` cross-file line and adds `has_function_posix_memalign = true` idempotently. The rebuilt runtime job [#40240044522](https://github.com/I-Steam/I-steam/actions/runs/40240044522) is in progress; no artifact has been confirmed. Inspect its final result before claiming the aligned allocator or runtime blocker is fixed.



The iOS release workflow now validates the runtime manifest and required QEMU lifecycle exports, copies the runtime's `Frameworks/` dependencies and `QEMU/` data into the app bundle, and checks that the declared library and data files exist before IPA creation. The release workflow YAML and source-level integration checks passed in GitLab pipeline #326:
https://gitlab.com/chantinlongxthrx/I-steam/-/pipelines/2986607027

This is **packaging-path validation only**. It does not prove the separate UTM runtime build produced a usable device-arm64 QEMU library, that all dynamic dependencies can be loaded on iOS, that an IPA was successfully produced, or that a guest OS boots on hardware. Keep the emulator status partial until those checks and a physical-iPad boot test pass.

## Runtime component manifest

RuntimeComponentManifest is intentionally an integrity checker for local files, not a binary downloader or installer. Distribution must still use a trusted release channel, record each component's license, and package code that is validly signed for the target platform. SHA-256 verifies bytes, not publisher identity.

## Acceptance criteria

A runtime feature is complete only when the required target-specific binaries and licenses are present, CI builds the app, automated tests cover the lifecycle, and a target device boots a guest and validates display/input/storage. Until then, UI must show the feature as unavailable or partial.


## SteamOS Gaming Mode (new native profile)

The Launch Setup screen now offers **SteamOS Gaming Mode** on iOS and the tvOS prototype. It selects a Linux guest profile with 4 GB configured RAM, four virtual CPUs, 1280×800/60 FPS targets, and USB keyboard/tablet input. The selection is remembered and can be saved in a VM configuration slot.

This is a DroidDeck-inspired *profile/mode*, not Valve's SteamOS distribution and not a promise of Steam Big Picture booting. The user must provide a compatible guest image; SteamOS-like distributions commonly require UEFI and graphics features that are not yet guaranteed by i-Steam. Until the QEMU runtime, UEFI firmware and display/input path pass on-device boot tests, readiness remains partial.

## Cross-chat coordination

Shared handoff and full port inventory: https://gitlab.com/chantinlongxthrx/chatgpt-messsage-board/-/blob/main/messages/2026-10-25-isteam-full-context-handoff.md

Read the latest messages in the shared board before editing this project, work on the active GitLab branch, and append a new dated board message after substantial changes. GitLab is canonical; GitHub is the configured mirror.


## QEMU command configuration

`src/QEMU/QEMUCommandBuilder.swift` now passes the VM profile's selected `GPUModel` to QEMU instead of silently forcing `virtio-gpu-pci`. This wires the existing per-VM GPU choice into command generation. It does not guarantee every model is present or supported in the packaged UTM build; runtime capability and guest boot must still be verified. The builder continues to expose VNC on loopback and attaches ISO or detected raw/QCOW2/VMDK/VHDX disk images through QEMU's command line.
