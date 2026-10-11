# SharpEmu evaluation and i-Steam runtime roadmap

Date: 2026-10-11

Reference: [sharpemu/sharpemu](https://github.com/sharpemu/sharpemu)

## What can and cannot be reused

SharpEmu is an experimental PlayStation 5 emulator written in C# for desktop Windows, Linux and macOS. Its architecture can be studied for separation of CPU execution, memory access, loader validation, diagnostics and GPU work. Its PS5-specific system modules, host assumptions, Vulkan/MoltenVK pipeline and C# implementation are not drop-in components for an iOS Swift app targeting Windows/Linux guests.

**This documentation does not claim SharpEmu source code is bundled or copied.** The current i-Steam project is GPL-3.0, while SharpEmu identifies its project as GPL-2.0; these license versions are not automatically interchangeable. Before importing any upstream implementation, check the exact license for the specific file and obtain legal review or permission if needed. Do not copy code based only on a README license label.

## Current implementation boundaries

- The app has a bounded, read-only Windows PE metadata inspector. It validates the MZ header, PE offset/signature, COFF header, optional-header bounds and PE32/PE32+ magic before reading metadata.
- The inspector exposes metadata such as machine type, bitness, subsystem, section count, optional-header size and file size. It does not execute the executable or prove Windows compatibility.
- Guest-memory and block-device primitives are prototypes, not a complete machine model or a bootable storage controller.
- Metal presentation and frame pacing are rendering experiments. They do not prove a guest GPU driver or real 3D acceleration is connected.
- The tvOS app is currently a separate UI preview and is not connected to the iOS guest-runtime code.
- CI checks build/package structure and SHA-256 checksums. Those checks are not physical-device runtime tests.

## Recommended milestones

1. Add unit tests for malformed/truncated PE files, invalid offsets, PE32/PE32+ headers and supported machine types.
2. Add tests for guest-memory bounds, overflow and permission failures.
3. Define a stable execution-backend protocol and keep loaders separate from execution.
4. Select an iOS-compatible QEMU/emulation integration and verify its license, build dependencies, JIT requirements and device support before integrating it.
5. Add a real graphics/input bridge only after guest execution works.
6. Connect a real guest framebuffer to Metal with pixel-format, stride and buffer-lifetime validation.
7. Add guest storage controllers and prove that guest-visible reads/writes reach a disk image safely.
8. Keep Windows API, Wine/Proton, Android, macOS guest and advanced GPU features disabled or clearly labelled until implemented and tested.
9. Add physical-device test evidence separately from compile/package success.

## Upstream links

- [SharpEmu repository](https://github.com/sharpemu/sharpemu)
- [SharpEmu README](https://github.com/sharpemu/sharpemu/blob/main/README.md)
- [SharpEmu license](https://github.com/sharpemu/sharpemu/blob/main/LICENSE.txt)
- [SharpEmu contribution guide](https://github.com/sharpemu/sharpemu/blob/main/CONTRIBUTING.md)
