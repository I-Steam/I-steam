# Hybrid runtime composition

- **Status:** composable execution-policy prototype; most specialist runtimes are not integrated.
- **Planner:** `src/Runtime/ExecutionBackendRouter.swift`
- **Launch entry point:** `src/Steam/GameLauncher.swift` → `src/Runtime/WindowsRuntime.swift`
- **Related code:** `src/Runtime/WindowsPEImage.swift`, `src/Runtime/WindowsPELoader.swift`, `src/Runtime/X86_64Interpreter.swift`, `iSteam/Box64Bridge.*`, `src/QEMU/`, `src/Windows/`, `src/GPU/`.

## How simultaneous composition works

"Use everything simultaneously" means composing independent stages, not running every CPU emulator against the same instruction stream.

1. **AOT cache:** run validated, previously translated ARM64 code for supported guest modules/blocks.
2. **Dynamic translator:** one selected translator handles cache misses, invalidated code and runtime-generated code. FEXCore and Box64 are alternatives for a given process, not concurrent duplicate engines.
3. **Diagnostic interpreter:** only a limited bring-up fallback for instructions the translation pipeline cannot yet handle. It is not a general game compatibility engine.
4. **OS compatibility:** Windows PE loading, DLL/import handling, Win32/NT services and Wine/Proton are composed with the CPU path.
5. **Graphics:** DirectX → Vulkan → Metal is a separate pipeline and can run alongside CPU work when the required translation layers are present.
6. **Host services:** audio, input, networking and storage are orthogonal subsystems and can run alongside CPU/GPU work.
7. **Full-system fallback:** QEMU TCG owns a complete guest machine when a whole OS/kernel is required. It is not an in-process fallback for a PE executable and cannot share CPU execution with Wine/FEX/Box64 for the same process.
8. **Architecture-specific paths:** a32rt is only for ARM32 guests; native ARM64 is used only where the guest ABI is compatible.

## Routing policy

| Guest workload | Composition |
|---|---|
| Windows x64 PE process | AOT cache + one of Wine/Proton+FEXCore or Wine/Proton+Box64; Win32/DLL compatibility; optional DirectX→Vulkan→Metal; audio/input/network/storage services |
| Linux x64 ELF process | AOT cache + one of FEXCore or Box64; Linux syscall ABI; diagnostic interpreter only for limited bring-up |
| ARM32 Linux ELF | a32rt architecture backend; QEMU full-system where a complete OS is needed |
| Native ARM64 process | native ARM64 under a compatible ABI |
| Complete OS/kernel | QEMU TCG full-system emulation |

## What is actually integrated today

- **Windows PE:** `WindowsPEImage` performs bounded metadata inspection; `WindowsPELoader` is read-only inspection. No PE image mapping, executable memory, import resolver, AOT translator or Windows process execution engine is integrated.
- **Static AOT:** no complete x86-64→ARM64 code generator/relinker is integrated. The existing translation cache is only file storage.
- **FEXCore:** not integrated or packaged.
- **Box64:** a C/Swift bridge can look for an already-loaded Box64 entry point. It does not bundle Box64, provide a Linux rootfs/syscall ABI, or prove game execution.
- **Wine/Proton:** not integrated.
- **QEMU:** `QEMURuntimeStatus` now asks the native bridge to `dlopen` the candidate with `RTLD_NOW` and resolve `qemu_init`, `qemu_main_loop` and `qemu_cleanup` before reporting it ready. This validates the loader, transitive dylibs and required exports; it does not prove guest boot, firmware compatibility, graceful stop, display/input or persistence. QEMU remains full-system only, not a PE process translator.
- **Interpreter:** tiny x86-64 diagnostic subset only.
- **a32rt:** not integrated.
- **Graphics:** Metal framebuffer presentation exists; DirectX→Vulkan→Metal guest translation is not integrated.
- **Audio/input/network/storage:** host and prototype services exist in parts, but complete guest-device adapters are not proven.

The planner's availability set must be populated only by concrete runtime probes that validate the binary, architecture, ABI, transitive libraries, required compatibility services and platform constraints. The QEMU probe now validates loadability and lifecycle exports, but the higher-level planner is not yet wired to populate availability from this probe. A source file or enum case is not proof that a backend is installed. Empty availability is deliberately safe.

## Performance policy

- Prefer native ARM64 guest code when its ABI is already compatible.
- Use cached AOT translations for stable code; invalidate by source hash, translator version, CPU feature set and ABI.
- Use exactly one dynamic translator per process; prefer FEX or Box64 only after compatibility and measured performance checks.
- Compile hot blocks asynchronously where permitted; never block the render/input thread for translation.
- Keep QEMU for whole-machine requirements rather than routing every simple process through it.
- Bound guest memory, translation cache growth, worker concurrency and framebuffer allocations to device capabilities.
- Keep graphics translation independent from CPU translation and use Metal-native presentation when possible.
- Record backend choice, fallback reason, cache hit/miss and startup errors in diagnostics.

## Safety and compatibility boundaries

- iOS/iPadOS sandboxing, code-signing, executable-memory/JIT entitlements, memory budgets and available APIs constrain dynamic translation.
- A Windows kernel and kernel-mode anti-cheat cannot be replaced by user-mode CPU translation. Anti-cheat support requires publisher approval for the exact environment.
- Do not disable, bypass, spoof or tamper with anti-cheat.
- A planned composition is not a working runtime. Verify physical-device boot, process launch, graphics, input/audio, shutdown and persistence before claiming compatibility.
