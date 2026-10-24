# QEMU runtime component

i-Steam already contains a native loader bridge in `iSteam/QEMUNativeBridge.c`
and a Swift session owner in `src/QEMU/QEMURuntime.swift`. This folder documents
the runtime artifact contract and provides a validation script.

## Required runtime artifact

The bridge expects a **real, signed, arm64 iOS-compatible** dynamic library at one
of these app-bundle locations:

- `Frameworks/libqemu-system-aarch64.dylib`
- `runtime/qemu/libqemu-system-aarch64.dylib` (resource fallback)

The library must export all four symbols:

- `qemu_init`
- `qemu_main_loop`
- `qemu_cleanup`
- `qemu_system_shutdown_request`

An ordinary macOS QEMU build is not compatible. Do not rename a macOS dylib to
make it appear to be an iOS runtime. The artifact must be built for the iOS device
SDK and signed as nested app code; tvOS and visionOS need separately validated
platform builds and must not reuse an iOS binary blindly.

## Current port status

- Native bridge loader and shutdown request: present.
- Swift lifecycle adapter: present.
- QEMU guest engine binary: **not included yet**.
- Boot validation on physical iOS/tvOS/visionOS hardware: **not done**.

This folder intentionally does not contain a fake or placeholder library. Until a
compatible runtime is built and packaged, the adapter returns a clear missing-runtime
error instead of claiming a guest has booted.

## Integration

Call `try QEMURuntimeBackend.shared.start(arguments: [...])` from the guest
launch path after validating the selected disk image and machine configuration.
Call `stop()` to request shutdown, and use the app's existing UI refresh loop to
call `refreshState()`. Do not block the main thread waiting for the guest.

Example arguments for a basic AArch64 virtual machine (only after the runtime and
all required device models are available):

```swift
try QEMURuntimeBackend.shared.start(arguments: [
    "-machine", "virt",
    "-cpu", "cortex-a72",
    "-m", "2048",
    "-nographic"
])
```

A bootable desktop guest additionally needs working storage, display, input, network,
audio, and a supported boot image. Those device integrations are not supplied by
this adapter alone.
