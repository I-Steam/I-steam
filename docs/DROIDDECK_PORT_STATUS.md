# DroidDeck port status

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
