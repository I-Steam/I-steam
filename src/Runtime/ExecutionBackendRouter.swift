import Foundation

/// Guest binary families understood by the runtime planner. This is metadata
/// about the guest ABI, not the host device architecture.
enum RuntimeGuestFormat: String, CaseIterable, Hashable {
    case windowsX64PE
    case linuxX64ELF
    case linuxARM32ELF
    case nativeARM64
    case unknown
}

enum RuntimeBackend: String, CaseIterable, Hashable {
    /// Ahead-of-time translated code, loaded from a validated translation cache.
    case staticAOT
    /// Linux x86-64 user-mode dynamic translator.
    case fexCore
    /// Linux x86-64 user-mode dynamic translator.
    case box64
    /// Full-machine emulation; not a user-mode translator.
    case qemuTCG
    /// Small diagnostic interpreter; not a commercial-game backend.
    case x86Interpreter
    /// ARM32-to-ARM64 compatibility backend.
    case a32rt
    /// Native ARM64 code under a compatible guest ABI.
    case nativeARM64
    /// Composed Windows user-mode compatibility + FEXCore route.
    case wineWithFEX
    /// Composed Windows user-mode compatibility + Box64 route.
    case wineWithBox64
}

enum RuntimeCompatibilityLayer: String, CaseIterable, Hashable {
    case wineOrProton
    case win32AndNT
    case windowsDLLLoader
    case directXToVulkan
    case vulkanToMetal
    case linuxSyscallABI
}

/// These stages cooperate in one execution strategy. AOT and dynamic
/// translation share a code cache: cached translated blocks run directly;
/// misses, invalidated code and unsupported translation cases go to the
/// selected dynamic engine. The diagnostic interpreter is a last-resort
/// bring-up path, not a way to run arbitrary game code.
enum RuntimeExecutionStage: String, CaseIterable {
    case cachedStaticTranslation
    case dynamicTranslation
    case diagnosticInterpreter
    case fullSystemEmulation
}

/// Services that are independent of CPU instruction execution and can operate
/// alongside the selected CPU path once their concrete adapters are installed.
enum RuntimeParallelSubsystem: String, CaseIterable {
    case windowsCompatibility
    case graphicsTranslation
    case audio
    case input
    case networking
    case storage
}

enum AntiCheatRuntimeAssessment: Equatable {
    case notRequested
    case providerApprovalRequired
    case kernelDriverRequiresSupportedWindowsKernel
}

struct RuntimeExecutionRequest {
    let format: RuntimeGuestFormat
    let requiresFullOperatingSystem: Bool
    let requiresKernelDriver: Bool
    let antiCheatEnabled: Bool

    init(
        format: RuntimeGuestFormat,
        requiresFullOperatingSystem: Bool = false,
        requiresKernelDriver: Bool = false,
        antiCheatEnabled: Bool = false
    ) {
        self.format = format
        self.requiresFullOperatingSystem = requiresFullOperatingSystem
        self.requiresKernelDriver = requiresKernelDriver
        self.antiCheatEnabled = antiCheatEnabled
    }
}

/// Concrete adapters must populate this after checking the actual runtime
/// binary, ABI, transitive libraries, platform support and required services.
/// Merely having a source file or enum case never makes a backend available.
struct RuntimeBackendAvailability {
    private let installed: Set<RuntimeBackend>
    private let layers: Set<RuntimeCompatibilityLayer>

    init(
        installed: Set<RuntimeBackend> = [],
        layers: Set<RuntimeCompatibilityLayer> = []
    ) {
        self.installed = installed
        self.layers = layers
    }

    func contains(_ backend: RuntimeBackend) -> Bool {
        installed.contains(backend)
    }

    func contains(_ layer: RuntimeCompatibilityLayer) -> Bool {
        layers.contains(layer)
    }

    func containsAll(_ required: [RuntimeCompatibilityLayer]) -> Bool {
        required.allSatisfy(layers.contains)
    }
}

struct RuntimeExecutionPlan {
    /// Cached AOT code is preferred, with one compatible dynamic engine for
    /// cache misses and code invalidation. They are complementary, not two
    /// emulators executing the same instruction stream.
    let staticTranslationBackend: RuntimeBackend?
    let dynamicTranslationBackend: RuntimeBackend?
    let architectureBackend: RuntimeBackend?
    let diagnosticFallback: RuntimeBackend?
    let fullSystemFallback: RuntimeBackend?

    let executionStages: [RuntimeExecutionStage]
    let parallelSubsystems: [RuntimeParallelSubsystem]
    let requiredLayers: [RuntimeCompatibilityLayer]
    let optionalLayers: [RuntimeCompatibilityLayer]
    let antiCheatAssessment: AntiCheatRuntimeAssessment
    let explanation: [String]

    /// Preferred installed backend for compatibility with existing callers.
    var selectedBackend: RuntimeBackend? {
        staticTranslationBackend
            ?? dynamicTranslationBackend
            ?? architectureBackend
            ?? fullSystemFallback
            ?? diagnosticFallback
    }

    var candidateOrder: [RuntimeBackend] {
        [
            staticTranslationBackend,
            dynamicTranslationBackend,
            architectureBackend,
            fullSystemFallback,
            diagnosticFallback
        ].compactMap { $0 }
    }

    var isExecutableWithInstalledBackends: Bool {
        selectedBackend != nil
    }
}

/// Builds a composable execution strategy. CPU engines are not all run in
/// parallel: one dynamic translator owns a process at a time, while cached AOT
/// blocks, compatibility services and graphics can cooperate around it.
enum RuntimeBackendRouter {
    static func plan(
        for request: RuntimeExecutionRequest,
        availability: RuntimeBackendAvailability
    ) -> RuntimeExecutionPlan {
        let antiCheat: AntiCheatRuntimeAssessment
        if request.requiresKernelDriver {
            antiCheat = .kernelDriverRequiresSupportedWindowsKernel
        } else if request.antiCheatEnabled {
            antiCheat = .providerApprovalRequired
        } else {
            antiCheat = .notRequested
        }

        let windowsLayers: [RuntimeCompatibilityLayer] = [
            .windowsDLLLoader, .win32AndNT, .wineOrProton
        ]
        let graphicsLayers: [RuntimeCompatibilityLayer] = [
            .directXToVulkan, .vulkanToMetal
        ]

        var staticBackend: RuntimeBackend?
        var dynamicBackend: RuntimeBackend?
        var architectureBackend: RuntimeBackend?
        var interpreter: RuntimeBackend?
        var fullSystem: RuntimeBackend?
        var stages: [RuntimeExecutionStage] = []
        var parallel: [RuntimeParallelSubsystem] = []
        var required: [RuntimeCompatibilityLayer] = []
        var optional: [RuntimeCompatibilityLayer] = []
        var explanation: [String] = []

        if request.requiresFullOperatingSystem || request.requiresKernelDriver {
            // A user-mode translator cannot provide a kernel or load a
            // kernel-mode driver. QEMU is the only full-system candidate here.
            if availability.contains(.qemuTCG) {
                fullSystem = .qemuTCG
                stages = [.fullSystemEmulation]
            }
            explanation.append("Full operating-system or kernel-driver workloads require a full-system backend; process translators are not substitutes.")
        } else {
            switch request.format {
            case .windowsX64PE:
                required = windowsLayers
                optional = graphicsLayers
                if availability.contains(.staticAOT) {
                    staticBackend = .staticAOT
                    stages.append(.cachedStaticTranslation)
                }
                // FEXCore and Box64 are mutually exclusive process engines.
                // Pick one, never run both against the same process.
                if availability.contains(.wineWithFEX) {
                    dynamicBackend = .wineWithFEX
                    stages.append(.dynamicTranslation)
                } else if availability.contains(.wineWithBox64) {
                    dynamicBackend = .wineWithBox64
                    stages.append(.dynamicTranslation)
                }
                if !stages.isEmpty {
                    parallel = [.windowsCompatibility, .graphicsTranslation, .audio, .input, .networking, .storage]
                }
                explanation.append("Windows PE requires a real PE/DLL loader and Win32/NT compatibility in addition to CPU translation.")
                explanation.append("DirectX-to-Vulkan and Vulkan-to-Metal are independent graphics stages; they do not translate CPU instructions.")
            case .linuxX64ELF:
                required = [.linuxSyscallABI]
                if availability.contains(.staticAOT) {
                    staticBackend = .staticAOT
                    stages.append(.cachedStaticTranslation)
                }
                if availability.contains(.fexCore) {
                    dynamicBackend = .fexCore
                    stages.append(.dynamicTranslation)
                } else if availability.contains(.box64) {
                    dynamicBackend = .box64
                    stages.append(.dynamicTranslation)
                }
                if availability.contains(.x86Interpreter) {
                    interpreter = .x86Interpreter
                    stages.append(.diagnosticInterpreter)
                }
                if !stages.isEmpty {
                    parallel = [.audio, .input, .networking, .storage]
                }
            case .linuxARM32ELF:
                if availability.contains(.a32rt) {
                    architectureBackend = .a32rt
                    stages = [.dynamicTranslation]
                    parallel = [.audio, .input, .networking, .storage]
                }
            case .nativeARM64:
                if availability.contains(.nativeARM64) {
                    architectureBackend = .nativeARM64
                    parallel = [.audio, .input, .networking, .storage]
                }
            case .unknown:
                explanation.append("The executable format is unknown; no execution backend is selected.")
            }
        }

        // A backend without its mandatory ABI/OS layer is not a launchable
        // candidate. Keep the plan's explanation explicit rather than silently
        // pretending a translator can supply those services.
        let selected = staticBackend ?? dynamicBackend ?? architectureBackend ?? fullSystem ?? interpreter
        if selected == nil {
            explanation.append("No installed compatible backend is available. Missing integrations are not inferred from source files.")
        } else {
            explanation.append("Preferred backend candidate: \(selected!.rawValue). Its own startup and guest validation must still succeed.")
        }
        if !required.isEmpty && !availability.containsAll(required) {
            explanation.append("Required compatibility layers are missing: " +
                required.filter { !availability.contains($0) }.map(\.rawValue).joined(separator: ", "))
        }
        if !optional.isEmpty {
            explanation.append("Optional graphics layers: " + optional.map(\.rawValue).joined(separator: " → "))
        }
        if request.antiCheatEnabled {
            explanation.append("Anti-cheat requires explicit publisher support for this exact runtime. CPU translation does not grant compatibility.")
        }
        if request.requiresKernelDriver {
            explanation.append("Kernel anti-cheat drivers require a supported Windows kernel; this plan does not bypass or emulate away that requirement.")
        }

        return RuntimeExecutionPlan(
            staticTranslationBackend: staticBackend,
            dynamicTranslationBackend: dynamicBackend,
            architectureBackend: architectureBackend,
            diagnosticFallback: interpreter,
            fullSystemFallback: fullSystem,
            executionStages: stages,
            parallelSubsystems: parallel,
            requiredLayers: required,
            optionalLayers: optional,
            antiCheatAssessment: antiCheat,
            explanation: explanation
        )
    }
}
