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

## Runtime component manifest

RuntimeComponentManifest is intentionally an integrity checker for local files, not a binary downloader or installer. Distribution must still use a trusted release channel, record each component's license, and package code that is validly signed for the target platform. SHA-256 verifies bytes, not publisher identity.

## Acceptance criteria

A runtime feature is complete only when the required target-specific binaries and licenses are present, CI builds the app, automated tests cover the lifecycle, and a target device boots a guest and validates display/input/storage. Until then, UI must show the feature as unavailable or partial.
