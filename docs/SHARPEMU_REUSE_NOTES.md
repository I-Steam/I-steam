# SharpEmu evaluation and i-Steam runtime roadmap

Date: 2026-10-09

Reference: [sharpemu/sharpemu](https://github.com/sharpemu/sharpemu)

## What can and cannot be reused

SharpEmu is an experimental PlayStation 5 emulator written in C# for desktop Windows, Linux and macOS. Its architecture is useful for studying separation of CPU execution, memory access, loader validation, diagnostics and GPU work. Its PS5-specific CPU/system modules, host assumptions, Vulkan/MoltenVK pipeline and C# implementation are not drop-in components for an iOS Swift app that aims to run Windows/Linux guests.

**This change does not copy SharpEmu source files.** The current i-Steam LICENSE is GPL-3.0, while SharpEmu identifies its project as GPL-2.0; those license versions are not automatically interchangeable. Before importing any upstream implementation, confirm the exact license for the specific file and obtain legal review/permission if needed. Do not copy code based only on a README license label.

## Improvements made in this pass

- Reworked i-Steam's existing Windows PE metadata inspector using a bounded, read-only parsing approach.
- Validates the MZ header, PE offset, PE signature, COFF header, optional-header bounds and PE32/PE32+ magic before reading metadata.
- Uses overflow-safe range checks and memory-mapped file loading where supported.
- Exposes metadata needed by later compatibility checks: machine type, bitness, subsystem, section count, optional-header size and file size.
- Explicitly does not execute the executable or claim Windows compatibility.

## Next integration milestones

1. Add unit tests for malformed/truncated PE files, invalid offsets, PE32/PE32+ headers and supported machine types.
2. Build a guest-memory API with checked reads/writes and explicit access failures.
3. Implement an execution backend behind a stable protocol, rather than treating a loader as a runtime.
4. Select an actual, iOS-compatible QEMU/emulation integration and verify its license, build dependencies, JIT requirements and device support before integrating it.
5. Add a real graphics/input bridge only after guest execution works.
6. Keep unsupported Windows API, Wine/Proton, Android, macOS guest and GPU features disabled or clearly labelled until they are implemented and tested.

## Upstream links

- [SharpEmu repository](https://github.com/sharpemu/sharpemu)
- [SharpEmu README and status](https://github.com/sharpemu/sharpemu/blob/main/README.md)
- [SharpEmu license file](https://github.com/sharpemu/sharpemu/blob/main/LICENSE.txt)
- [SharpEmu contribution and coding guidelines](https://github.com/sharpemu/sharpemu/blob/main/CONTRIBUTING.md)
