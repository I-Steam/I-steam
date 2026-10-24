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
- Adds a loopback-only QEMU VNC server and a minimal RFB client that forwards real framebuffer rectangles to the Metal texture backend. The VNC client supports raw rectangles and DesktopSize updates; it does not implement SPICE or accelerated 3D guest graphics.
- Adds source-format validation to CI to catch accidentally committed literal line-break escape sequences.

## Still required for a working guest OS

1. **Runtime build and packaging:** build UTM's compatible QEMU fork for iOS device arm64 and package its dynamic library, matching data files, and every required dependency into the app. The repository currently does not contain that runtime.
2. **Display:** the app now has a basic loopback VNC/RFB display path for raw framebuffer updates. Verify that the pinned QEMU build enables VNC, test pixel formats/resolution changes, and consider UTM's SPICE stack for accelerated graphics. The Metal renderer is only a presenter; the VNC client supplies its pixels.
3. **Input:** basic RFB keyboard events, pointer movement, touch-stick WASD, and controller buttons are wired. Validate key mappings, mouse-button events, hardware keyboard support, and controller layouts against real guests.
4. **Device/boot coverage:** validate QEMU arguments and devices against the exact runtime build, then boot a redistributable test image on a physical iPad. Main-loop startup alone does not prove that Linux or Windows booted.
5. **Guest support:** test storage formats, firmware, networking, USB, sound, and supported guest architectures against the devices actually compiled into QEMU. The current configuration supports x86_64 only and does not expose audio.

## Important distinction

CI's current GitLab validation checks configuration and source-format invariants; it does **not** compile the iOS app, build QEMU, or prove a guest boot. The GitHub release workflow builds app packages, but a successful IPA package is not evidence that a QEMU runtime is present or functional.

UTM's iOS implementation also has a single-session-per-process constraint. The bridge now reports this limitation rather than attempting an unsafe in-process QEMU restart.

## Licensing

UTM's referenced source files are licensed under Apache-2.0. QEMU and each bundled dependency have their own licensing requirements. Audit the exact source revision and configuration, and preserve all applicable notices before redistributing compiled runtime artifacts. See [THIRD_PARTY_NOTICES.md](../THIRD_PARTY_NOTICES.md).
