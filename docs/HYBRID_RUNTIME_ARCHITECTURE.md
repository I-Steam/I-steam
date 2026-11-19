# Hybrid runtime architecture

- **Status:** Orchestration policy prototype; execution backends are not all integrated.
- **Entry point:** `src/Runtime/ExecutionBackendRouter.swift`
- **Related work:** `src/Runtime/WindowsPEImage.swift`, `src/Runtime/WindowsPELoader.swift`, `src/Runtime/X86_64Interpreter.swift`, `iSteam/Box64Bridge.*`, `src/QEMU/`, `src/Windows/`, `src/GPU/`.

## Goal

Use the available execution techniques together, selecting by guest binary format and required operating-system features. Static translation, dynamic translation, interpretation, and full-system emulation are different execution levels; they are fallback/complementary options, not interchangeable implementations.

## Routing policy

| Guest workload | Candidate order | Notes |
|---|---|---|
| Windows x64 PE process | Static AOT translator → Wine/Proton + FEXCore → Wine/Proton + Box64 → QEMU full-system Windows VM | Wine/Proton supplies Windows user-mode APIs; FEXCore/Box64 translate Linux x86-64 processes, not PE files by themselves. The composed route requires a working Wine/Proton build and a compatible translator. |
| Linux x64 ELF process | Elevator-style static AOT → FEXCore → Box64 → QEMU full-system Linux → minimal x86 interpreter | Static AOT implementation is not yet available in this repository. The interpreter supports only a tiny diagnostic subset. |
| ARM32 Linux ELF | a32rt → QEMU full-system | Separate architecture path; not a substitute for x86-64 Steam execution. |
| ARM64 guest code | Native ARM64 path → QEMU | Native code still needs a compatible guest OS ABI. |
| Full OS, kernel, or driver requirement | QEMU full-system | A user-mode translator cannot provide a kernel. This does not guarantee anti-cheat support. |

## Windows execution layers

Windows PE instruction translation is only one layer. A complete Windows game path also needs:

1. PE loader, imports, relocations, TLS, exception/unwind metadata, DLL loading and process memory.
2. Windows x64 calling convention and CPU state mapping.
3. Win32 and NT user-mode API compatibility (Wine/Proton or an equivalent implementation).
4. DirectX translation to a host graphics API, followed by Vulkan-to-Metal where required.
5. Audio, input, timers, sockets, threading, synchronization and filesystem semantics.
6. Explicit anti-cheat compatibility assessment.

The static translator must not be described as a complete Windows runtime. The AArch64 output still needs a compatible execution ABI; an ARM64 Linux ELF is not an iOS Mach-O executable.

## Backend boundaries

- **Static AOT:** Elevator/ElevatorII is a research direction for x86-64 ELF → AArch64 ELF. It is not a drop-in Windows PE translator and no verified source integration is recorded here. A Windows PE lifter/relinker remains a separate implementation task.
- **FEXCore:** dynamic x86-64 Linux user-mode translation. Requires a Linux userspace/syscall environment.
- **Box64:** dynamic x86-64 Linux user-mode translation. The existing `Box64Bridge` only resolves an already-loaded Box64 entry point; it does not bundle or prove a working Box64 runtime.
- **QEMU TCG:** full-system emulation fallback. It is not a static translator. The iOS native runtime artifact and physical-device guest boot remain separate validation requirements.
- **x86 interpreter:** diagnostic bring-up only; the current instruction and Linux syscall subset is far too small for commercial games.
- **a32rt:** ARM32 compatibility only.
- **Wine/Proton and graphics translation:** compatibility layers, not CPU translators.

## Planner contract

`RuntimeBackendRouter.plan(for:availability:)` returns an ordered candidate list, the first backend explicitly reported installed, required compatibility layers, and anti-cheat caveats. The availability set must be populated only by real integration probes. Empty availability is the safe default. A selected backend is a candidate only: its own binary validation and startup can still fail.

The router is policy scaffolding; it does not currently launch any backend or silently switch a running process between incompatible execution environments. Runtime failover must occur at a safe process/session boundary and preserve guest state where the backend supports it.

## Platform and anti-cheat constraints

- iOS/iPadOS app sandbox, code-signing, executable-memory/JIT entitlements and memory limits constrain dynamic code generation and native runtime loading.
- iOS does not expose a general-purpose Windows kernel or Hypervisor.framework to ordinary App Store/sideloaded apps.
- Kernel anti-cheat drivers cannot be made operational by translating game instructions. Even user-mode anti-cheat requires publisher approval for the exact OS, architecture and virtualization/translation environment.
- Do not bypass, disable, spoof, or tamper with anti-cheat. Report unsupported configurations clearly.

## Validation still required

- Unit tests for each routing branch and every anti-cheat state.
- Real availability probes for each packaged backend and all transitive libraries.
- PE/ELF fixture tests, translator differential tests, and relocation/exception/threading coverage.
- Build and package validation for iOS, tvOS and visionOS.
- Physical iPad test for runtime startup, guest execution, display/input/audio, shutdown and persistence.
- Do not claim a game works until its actual launch and gameplay path is tested.
