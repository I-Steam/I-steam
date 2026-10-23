# DroidDeck feature-port plan for i-Steam

This document inventories the user-provided DroidDeck source archive. It is a port plan, not a claim that these features already work in i-Steam.

## Platform constraints

DroidDeck is an Android/Linux gaming environment for supported Adreno devices. It relies on Linux userlands, FEX, Wine/Proton, Vulkan/Turnip, Gamescope, Android process/device integration and Android-specific native libraries. i-Steam targets iOS, tvOS and visionOS. Apple's app sandbox, JIT/signing restrictions, platform APIs and lack of public Hypervisor.framework access prevent a direct source-level port of the Android runtime.

Do not copy Android binaries into an iOS app or mark a feature complete because its UI exists. Port portable algorithms and product flows, replace platform APIs, rebuild native dependencies for each target, review licenses, and keep unsupported execution paths disabled until a real backend exists.

## Feature inventory

| DroidDeck feature | i-Steam port approach | Constraints / acceptance criteria |
| --- | --- | --- |
| Steam Big Picture / session home | Controller-first library and session UI | UI does not imply game execution works |
| Game library, EXE import, artwork, per-game edits | Metadata, artwork cache, favourites, launch arguments and per-game settings | Imported PE/ELF metadata is not executable support |
| Steam Store | Embedded store on supported Apple platforms | Browser and login behavior varies by platform |
| Linux desktop, Flatpak and AppImage | Research a sandbox-compatible guest package manager | Requires a real Linux guest runtime |
| Windows games via FEX and Wine/Proton | Long-term runtime research | No drop-in iOS port; CPU translation, syscalls, Win32, graphics, audio and input are all required |
| Turnip/Vulkan, Gamescope, frame generation | Port settings concepts; investigate Metal presentation | Android GPU injection and Linux Vulkan hooks are not portable as-is |
| Controllers, touch gamepad, keyboard overlay, pointer lock | Use UIKit and GameController equivalents | Validate each input path on device |
| Resolution, FPS and performance diagnostics | Extend existing display/performance settings | Requested FPS is only a target |
| VITURE, XREAL, RayNeo and Rokid glasses | Port protocol/pose algorithms after license review; native spatial display separately | Android USB/HID/SDK paths need replacement |
| 3DoF/6DoF, hand tracking and Joy-Con VR | Reimplement against supported Apple APIs such as ARKit where applicable | CameraX, Android Activities and Android shared-memory paths cannot be reused directly |
| Save slots, per-game config, logs and crash reports | Extend existing save-slot metadata and diagnostics | Config saves are not VM snapshots |
| Component/driver manager and updates | Signed manifest, checksums and compatible artifact management | Only target-compatible binaries; review each license |
| GOG/Epic/Amazon integrations | Investigate supported APIs and license-compatible clients | Authentication, DRM and service terms require separate review |
| File manager and removable storage | Document picker, bookmarks and import/export | Files access is not raw USB block-device passthrough |
| Device reports and scrubbed logs | Extend diagnostics/export | Never collect tokens or credentials |
| Android child-process settings, wireless ADB, ZRAM, proot and JNI | Do not port; replace only if a supported Apple equivalent exists | Android/Linux host facilities have no direct iOS equivalent |

## Suggested implementation order

1. Portable app features: game-library metadata, per-game settings, artwork/cache, controller mappings, save-slot metadata, diagnostics and import/export.
2. Native Apple integration: gamepad/keyboard handling, Metal presentation, frame pacing, file-provider access and visionOS spatial presentation.
3. Runtime foundation: select a compatible full-system or user-mode runtime, build for arm64 iOS, add a narrow native bridge, and prove a Linux boot with display/input before enabling guest launch.
4. Only after reliable guest boot, evaluate graphics/audio/networking and Windows compatibility. Test game compatibility per title.
5. Add XR vendor integrations as separately gated modules with device-specific test coverage.

## Definition of done

A feature is complete only when code and dependencies are committed, licenses are recorded, automated builds/tests pass, and hardware-dependent behavior is exercised on the target platform. A setting, stub, successful build, or imported file is not proof that a runtime feature works.

## Source and licensing

Inventory based on the uploaded DroidDeck-main.zip README, Android app sources, native components, XR/glasses modules, GPU modules, runtime integration and build workflows. DroidDeck source is GPL-3.0; any code-level reuse must comply with that license and all third-party notices.

## Implemented portable services (2026-10-23)

The first code-level port batch adds `src/Steam/DroidDeckFeatureServices.swift`:

- Versioned JSON library backup export/import with a 20 MB file cap, bounded entry counts, duplicate-ID and invalid-field checks, atomic export, and merge-without-overwrite semantics.
- Backup includes library metadata and per-game runtime profiles. Import does not execute anything, restore sandbox permissions, or reconnect external file paths; paths remain untrusted metadata.
- Default per-game profile creation from global resolution/FPS preferences.
- A feature-readiness registry that explicitly distinguishes host-side partial features from unavailable runtime-dependent features.

This is a useful native port of portable product flows, not the completion of DroidDeck's Linux/Windows gaming engine. The Android FEX/Proton/Turnip/Gamescope/SteamVR stack cannot be made functional by copying its UI or Kotlin files. The full-system QEMU feature remains unavailable until a compatible arm64 iOS QEMU library is built, bundled, loaded and demonstrated booting a guest on device. The feature registry intentionally reports that limitation.
