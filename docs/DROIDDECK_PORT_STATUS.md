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
This file records the current native i-Steam port of features inventoried from the supplied DroidDeck Android source archive. It distinguishes committed host-side features from runtime features that still cannot work without their platform-specific engines.

## Committed native feature ports

- **Library transfer:** `src/Steam/DroidDeckFeatureServices.swift` exports/imports versioned JSON backups, caps imports at 20 MiB and 10,000 games/profiles, rejects duplicate game IDs and invalid/orphaned profiles, and merges without overwriting existing games. Imported executable paths remain untrusted metadata.
- **Per-game settings:** `src/Steam/GameRuntimeProfile.swift` stores bounded resolution/FPS/memory/CPU preferences, launch arguments, environment values and controller/touch preferences in atomic app-support JSON files. Settings only take effect when a backend consumes them.
- **Artwork and metadata:** `src/Steam/GameArtworkStore.swift` and the library/compatibility services provide local metadata/artwork workflows; this is not a Steam account client or a promise of executable compatibility.
- **Controller and touch UI:** `src/Display/ControllerMappingStore.swift`, `ControllerInputManager.swift`, `TouchGamepadView.swift` and keyboard overlay code provide host-side input/configuration pieces. Guest-device injection still needs a working emulator input path.
- **External files:** `src/Runtime/ExternalDriveStore.swift` handles document-provider access/bookmarks and safe imports. iOS does not expose arbitrary physical USB drives as guest block devices through this API.
- **Component integrity:** `src/Runtime/RuntimeComponentManifest.swift` validates local component manifests and file hashes. A hash check is not publisher authentication, and this code is not a runtime downloader/installer.
- **Runtime bridge:** `src/QEMU/QEMUNativeRuntime.swift` and `iSteam/QEMUNativeBridge.c` attempt to load an app-bundled QEMU library, resolve required lifecycle symbols, pass arguments, request shutdown and retain file scopes while a session is active. This bridge is only usable when a compatible library is actually built and packaged.

## Runtime blockers — not complete

- **Full-system QEMU:** no verified, packaged arm64 iOS QEMU runtime plus data/device models and a successful on-device guest boot has been demonstrated. Runtime discovery or a successful app build does not satisfy this.
- **Display and input:** the QEMU lifecycle bridge does not yet prove a complete QEMU display backend is connected to the app's Metal view or that controller/keyboard input reaches the guest.
- **Windows execution:** PE parsing is not Win32 execution. Wine/Proton, a compatible CPU translation strategy, required system calls, graphics, audio, input and networking must work together before Windows games can run.
- **FEX / Box64:** Android/Linux binaries are not iOS drop-ins. A target-compatible build, executable-memory strategy, licensing review and device tests are required.
- **Linux desktop, Flatpak and AppImage:** require a bootable Linux guest and package-manager integration.
- **Turnip, Vulkan, Gamescope and frame generation:** Android/Linux graphics components cannot simply be copied into iOS. They require compatible Apple-platform rendering/integration.
- **SteamVR and smart glasses:** each vendor/pose path requires a separate supported Apple-platform implementation and device validation.
- **GOG/Epic/Amazon launchers:** need service-compatible integration and separate authentication/DRM/legal review; no Android launcher should be assumed to work on iOS.
- **Raw USB block devices and Android host features:** Android JNI, wireless ADB, ZRAM, proot and Android process/device integration are not portable iOS features.

## Acceptance checklist for claiming the engine works

- [ ] Build a licensed, code-signed arm64 iOS QEMU runtime with required machine/device models and data files.
- [ ] Package it into the app and verify the required exported lifecycle symbols on a real device.
- [ ] Boot a known Linux image on a supported iPad/iPhone and capture logs showing guest kernel progress, not just QEMU thread startup.
- [ ] Connect the guest display to the native renderer and validate resizing, refresh pacing and recovery from display changes.
- [ ] Verify keyboard, controller, pointer/tablet, storage, networking and audio paths against the running guest.
- [ ] Exercise stop, crash, failed boot, repeated start/stop and file-provider security-scope lifetimes.
- [ ] Only then evaluate a Windows guest and Wine/Proton; separately test each game and compatibility limitation.
- [ ] Build and test iOS, tvOS and visionOS targets independently. A CI YAML validation job is not an Xcode compile or a hardware test.

## Licensing and source reuse

DroidDeck is GPL-3.0 according to the supplied archive. Any code-level reuse must comply with its license and preserve relevant third-party notices. Android-specific code should be ported only where the API and licensing make sense; portable behavior can be reimplemented natively rather than copying incompatible binaries.
