# QEMU runtime artifact contract

This directory documents the runtime packaging contract and contains a validator. It does **not** implement or bundle the QEMU engine, and it is not a completed DroidDeck backend port.

## Runtime layout

The build script `scripts/package-utm-qemu-runtime.sh` selects a loadable UTM/QEMU Mach-O binary by its exported lifecycle symbols. It writes the selected path to `QEMU/runtime-library-path.txt`.

The release workflow embeds the complete `Frameworks/` and `QEMU/` directories into the iOS app. Do not assume a fixed QEMU library filename: the manifest is authoritative, and UTM may change its internal library name or layout.

The library is an **iOS device arm64** binary that runs an **x86_64 system guest**. It must not be replaced with a macOS or simulator build.

## Native bridge contract

The native bridge in `iSteam/QEMUNativeBridge.c` requires these exported symbols:

- `qemu_init`
- `qemu_main_loop`
- `qemu_cleanup`

`qemu_system_shutdown_request` is optional. If it is absent, the bridge can start QEMU but cannot request graceful guest shutdown.

The Swift runtime locator is `src/QEMU/QEMURuntimeStatus.swift`; the lifecycle owner is `src/QEMU/QEMUNativeRuntime.swift`. The locator reads the generated manifest and resolves the library inside the app bundle. The native bridge then loads it with `dlopen` and resolves the lifecycle symbols with `dlsym`.

## Validation

Run:

```sh
bash scripts/validate-qemu-runtime.sh /path/to/the/manifest-selected-QEMU-library
```

The validator requires Apple tooling and checks that the file is Mach-O, contains the device `arm64` architecture, exports all three required symbols as defined external symbols, and passes strict code-signature verification. It reports the optional shutdown symbol separately.

This is a packaging check only. It does not prove that the library's dependencies load, that QEMU initializes, or that a guest boots.

## Current status and limitations

- Native bridge and Swift manifest-based runtime locator: present in source.
- UTM/QEMU runtime binary: must be produced by the runtime workflow and embedded by the release workflow.
- Physical-device runtime startup, guest boot, display, input, graceful shutdown, and disk persistence: not verified by this validator.
- The current app runtime configuration is for x86_64 guests; this artifact is not an ARM64 guest runtime.
- tvOS and visionOS need separately built and validated platform runtimes; the iOS binary must not be reused blindly.

A simulator compile, source check, or successful artifact inspection is not evidence of a working physical-device emulator.
