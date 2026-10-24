# UTM/QEMU port notes

i-Steam is adapting selected parts of UTM's Apple-platform QEMU integration. This is not a wholesale copy of UTM and is not yet a complete emulator port.

## Upstream references

- UTM repository: https://github.com/utmapp/UTM
- QEMU lifecycle wrapper: https://github.com/utmapp/UTM/blob/main/Services/UTMQemuSystem.m
- UTM QEMU launcher bootstrap: https://github.com/utmapp/UTM/blob/main/QEMULauncher/Bootstrap.c
- UTM's iOS dependency/QEMU build script: https://github.com/utmapp/UTM/blob/main/scripts/build_dependencies.sh
- UTM iOS development instructions: https://github.com/utmapp/UTM/blob/main/Documentation/iOSDevelopment.md
- UTM architecture notes: https://github.com/utmapp/UTM/blob/main/Documentation/Architecture.md

## Integrated in i-Steam

- Loads a bundled QEMU dynamic library and resolves the QEMU lifecycle entry points.
- Runs initialization and the QEMU main loop on a worker pthread rather than blocking the UI thread.
- Treats a non-zero qemu_init result as a startup failure.
- Keeps Files-provider security scopes alive until the native thread has exited, including when stop is requested during initialization.
- Defers stop requests until initialization has completed.
- Follows UTM's documented iOS limitation that QEMU can only be initialized once per app process. After a QEMU session has started, force-quit and relaunch i-Steam before attempting another session.
- Wires a selected disk image into the argument builder, recognizes ISO-9660 media and attaches it as a CD-ROM.
- Passes the QEMU data directory using -L.
- Keeps QEMU headless while no guest display backend is integrated, instead of falsely claiming that the app's separate Metal view is showing guest graphics.
- Adds source-format validation to CI to catch accidentally committed literal line-break escape sequences.

## Still required for a working guest OS

1. **Runtime build and packaging:** build UTM's compatible QEMU fork for iOS device arm64 and package its dynamic library, matching data files, and every required dependency into the app. The repository currently does not contain that runtime.
2. **Display:** integrate a real guest display path, such as UTM's SPICE server/client/renderer stack, and connect it to the i-Steam view. The existing Metal renderer is not a QEMU framebuffer.
3. **Input:** send keyboard, pointer, and controller events to QEMU input devices. The existing on-screen controls currently log some events rather than injecting them into the guest.
4. **Device/boot coverage:** validate QEMU arguments and devices against the exact runtime build, then boot a redistributable test image on a physical iPad. Main-loop startup alone does not prove that Linux or Windows booted.
5. **Guest support:** test storage formats, firmware, networking, USB, sound, and supported guest architectures against the devices actually compiled into QEMU.

## Important distinction

CI's current GitLab validation checks configuration and source-format invariants; it does **not** compile the iOS app, build QEMU, or prove a guest boot. The GitHub release workflow builds app packages, but a successful IPA package is not evidence that a QEMU runtime is present or functional.

UTM's iOS implementation also has a single-session-per-process constraint. The bridge now reports this limitation rather than attempting an unsafe in-process QEMU restart.

## Licensing

UTM's referenced source files are licensed under Apache-2.0. QEMU and each bundled dependency have their own licensing requirements. Audit the exact source revision and configuration, and preserve all applicable notices before redistributing compiled runtime artifacts. See [THIRD_PARTY_NOTICES.md](../THIRD_PARTY_NOTICES.md).
