# i-Steam

i-Steam is an iOS Steam-focused compatibility runtime and Windows VM frontend.

The architecture now combines the **LiveExec32-style guest-process model** with an optional **QEMU full-system VM**:

```
Steam game / Windows executable
        ↓
Guest process runtime
        ↓
x86-64 translation + JIT
        ↓
Windows API / DLL compatibility layer
        ↓
Virtual GPU / D3D translation
        ↓
Metal
        ↓
iOS
```

## Runtime modes

- **Windows Runtime** — LiveExec-style process execution path. This is the fast path for compatible software.
- **Windows VM** — QEMU full-system Windows path for software that needs a complete guest OS.
- **Linux VM** — development/compatibility VM.

The VM backend uses QEMU TCG/JIT on iOS. Apple's Hypervisor.framework is not available to normal iOS applications, so the Hypervisor option is exposed in Settings for capability reporting but is disabled when unavailable.

## LiveExec-inspired architecture

The runtime is split into:

- Guest process and PE loading
- Guest memory and thread management
- x86-64 translation/JIT
- Windows API/DLL compatibility
- Root filesystem
- Crash diagnostics
- persistent translation cache

The uploaded LiveExec32 source is used as an architectural reference. Its ARM32/Darwin-specific implementation is not blindly reused for x86-64 Windows binaries.

## Graphics

The host display path supports:

- 24 FPS minimum frame pacing
- 60 FPS
- 120 FPS on displays that expose 120 Hz
- Metal-backed VirtIO framebuffer presentation
- persistent shader-cache infrastructure
- adaptive resolution hooks

120 FPS is only available when the physical display and OS expose a 120 Hz refresh rate.

## Performance

MeloNX-inspired ideas are represented by:

- persistent translation caching
- shader caching
- JIT-aware memory management
- thermal/performance monitoring
- frame pacing
- reduced-resolution performance mode

These are infrastructure components; they do not guarantee a particular FPS in every game.

## Windows / Steam

The project is designed around Windows Steam games, but compatibility still depends on the Windows runtime, graphics API, game dependencies and anti-cheat requirements. i-Steam does not bypass or defeat kernel anti-cheat systems.

## Build

GitHub Actions generates the Xcode project, builds the Box64 compatibility runtime and packages an unsigned `iSteam-SideStore.ipa`.
