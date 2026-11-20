# Windows x64 → ARM64 static translation: implementation plan

## Scope

This subsystem targets Windows x86-64 PE32+ executables and DLLs as input. It is distinct from ElevatorII's Linux ELF → AArch64 research target. AnyPS5 is an architectural reference for executable rewriting, import redirection, module loading, and shader translation; it is not a reusable x86-to-ARM translator because PS5 and desktop Windows share x86-64 instruction architecture.

A PE parser/relinker is not itself a static translator. The initial implementation in this branch is the safe PE metadata foundation only.

## Planned pipeline

1. PE analysis: validate AMD64 PE32+, map RVAs, enumerate sections, normal imports, and x64 DIR64 base relocations.
2. Control-flow recovery: discover code, indirect branches, jump tables, exception/unwind regions, TLS callbacks, and generated code. Ambiguous code/data must remain unresolved rather than guessed.
3. x86-64 lifting: decode instructions and lift semantics into a target-neutral IR, preserving flags, memory ordering, atomics, SIMD, x87, exceptions, and Windows x64 ABI behavior.
4. ARM64 code generation: lower IR to AArch64, generate veneers/trampolines, preserve unwind metadata, and emit a complete relocation plan.
5. Windows loader compatibility: imports, delay imports, forwarded exports, TLS, SEH/unwind, loader notifications, DLL search policy, and process startup.
6. Win32/NT compatibility: user-mode API implementations with explicit unsupported boundaries. This does not emulate a Windows kernel.
7. Graphics/audio/input: Direct3D translation to a supported Apple graphics backend, audio, HID/gamepad, timers, and synchronization.
8. Anti-cheat policy: report compatibility requirements; do not patch, evade, or impersonate anti-cheat. Kernel drivers require a supported Windows kernel environment and cannot be made compatible by user-mode translation.

## Implemented in this branch

- `src/Runtime/WindowsPEImage.swift`: Foundation-only bounded parser for AMD64 PE32+ headers, sections, file-backed RVA mapping, normal import descriptors/thunks (name and ordinal), and DIR64 relocation records.
- It rejects malformed bounds, unsupported machine/optional-header formats, non-DIR64 x64 relocation types, and excessive table sizes.
- It does not map or execute images, resolve imports, handle delay imports, rewrite code, or generate ARM64 instructions.
- Existing `WindowsPELoader.swift`, `Win32API.swift`, and `AntiCheatCompatibility.swift` remain separate earlier prototypes/placeholders.

## Dependencies and platform constraints

- The parser uses Foundation only and is included automatically by the existing XcodeGen `src` source directory.
- No LLVM, disassembler, binary rewriter, or translator dependency is integrated yet.
- iOS sandbox, code signing, executable-memory/JIT restrictions, and the difference between iOS Mach-O and Windows guest ABI remain separate constraints.
- Translating instructions does not provide a Windows kernel or make EAC/BattlEye approve an environment.

## Validation and next steps

- Source review only. No Xcode/macOS compiler was available in this work session; compilation and runtime tests are pending.
- Add synthetic PE fixtures for malformed headers, overflow, section/RVA boundaries, imports by name/ordinal, missing terminators, and relocation blocks.
- Select and license a real x86-64 decoder/IR/AOT backend after verifying upstream source availability and iOS portability. LLVM MC alone is not a ready-made PE-to-ARM64 static translator.
