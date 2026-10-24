# UTM/QEMU port notes

i-Steam is adapting the QEMU system-emulator lifecycle and argument-building approach used by UTM for Apple platforms. This is a targeted integration, not a wholesale copy of UTM's app.

## Upstream reference

- UTM repository: https://github.com/utmapp/UTM
- UTM's QEMU lifecycle wrapper: https://github.com/utmapp/UTM/blob/main/Services/UTMQemuSystem.m
- UTM's argument builder: https://github.com/utmapp/UTM/blob/main/Configuration/UTMQemuConfiguration%2BArguments.swift
- UTM's QEMU launcher bootstrap: https://github.com/utmapp/UTM/blob/main/QEMULauncher/Bootstrap.c
- UTM's iOS dependency/QEMU build script: https://github.com/utmapp/UTM/blob/main/scripts/build_dependencies.sh

## What is ported in this change

- Uses the QEMU lifecycle signatures that UTM's current wrapper expects: `int qemu_init(int, const char *[], const char *[])`, `void qemu_main_loop(void)`, and `void qemu_cleanup(void)`.
- Treats a non-zero initialization result as a startup failure instead of marking the guest as running.
- Reports initialization failures to the VM state monitor.
- Uses a headless QEMU display option until UTM's SPICE client/renderer path is ported. The current Metal view is not yet a QEMU framebuffer, so this change does **not** claim visible guest graphics.
- Keeps QEMU's data directory passed with `-L`, as UTM does for its resource files.

## Still required before this is a working UTM port

1. Build and bundle a signed **iOS device arm64** QEMU shared library from UTM's pinned QEMU fork/patch set. A macOS or simulator library is not usable on the iPad.
2. Bundle the matching QEMU data files and all dependent libraries/frameworks.
3. Integrate UTM's SPICE display/client stack (or another real QEMU display backend) with i-Steam's Metal view.
4. Connect keyboard, pointer and controller events to QEMU input devices rather than only logging them.
5. Verify stop/restart behavior against the exact QEMU build; UTM normally manages QEMU as a process and exits/terminates that process, while i-Steam's current bridge is in-process.
6. Run a real-device boot smoke test with a test image and verify guest boot separately from the QEMU main loop starting.

Until those pieces are complete, the app should report a missing runtime or display limitation instead of claiming that Windows/Linux has booted.

## License

UTM's referenced source files are licensed under the Apache License, Version 2.0. QEMU itself and individual components have their own licenses; audit the exact build and preserve upstream notices before redistributing any compiled runtime. See [THIRD_PARTY_NOTICES.md](../THIRD_PARTY_NOTICES.md).
