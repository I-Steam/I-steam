import Foundation

/// Guest binary families understood by the runtime planner. This is metadata
/// about the guest file/ABI, not the host device architecture.
enum RuntimeGuestFormat: String, CaseIterable {
    case windowsX64PE
    case linuxX64ELF
    case linuxARM32ELF
    case nativeARM64
    case unknown
}

enum RuntimeBackend: String, CaseIterable {
    /// Planned PE/ELF ahead-of-time translation to AArch64.
    case staticAOT
    /// Linux x86-64 user-mode dynamic translator.
    case fexCore
    /// Linux x86-64 user-mode dynamic translator.
    case box64
    /// Full-machine emulation; not a user-mode translator.
    case qemuTCG
    /// Small diagnostic interpreter; not a general-purpose game backend.
    case x86Interpreter
    /// ARM32-to-ARM64 compatibility backend.
    case a32rt
    /// Already-native ARM64 guest code, where its OS ABI is supported.
    case nativeARM64
    /// Windows PE execution through a Windows compatibility stack plus
    /// a Linux x86-64 translator. This is a composed backend, not Box64 alone.
    case wineWithFEX
    case wineWithBox64
}

enum RuntimeCompatibilityLayer: String, CaseIterable {
    case wineOrProton
    case win32AndNT
    case windowsDLLLoader
    case directXToVulkan
    case vulkanToMetal
    case linuxSyscallABI
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

/// Availability is supplied by concrete integrations. Nothing is assumed to
/// exist merely because its adapter or planner case has been declared.
struct RuntimeBackendAvailability {
    private let installed: Set<RuntimeBackend>

    init(installed: Set<RuntimeBackend> = []) {
        self.installed = installed
    }

    func contains(_ backend: RuntimeBackend) -> Bool {
        installed.contains(backend)
    }
}

struct RuntimeExecutionPlan {
    /// First available candidate, if any. The caller must still ask the
    /// backend to validate the binary and initialise successfully.
    let selectedBackend: RuntimeBackend?
    let candidateOrder: [RuntimeBackend]
    let requiredLayers: [RuntimeCompatibilityLayer]
    let antiCheatAssessment: AntiCheatRuntimeAssessment
    let explanation: [String]

    var isExecutableWithInstalledBackends: Bool {
        selectedBackend != nil
    }
}

/// Central policy for choosing among static translation, dynamic translation,
/// interpretation, and full-system emulation. This type only plans execution;
/// it does not pretend to implement or launch missing backends.
enum RuntimeBackendRouter {
    static func plan(
        for request: RuntimeExecutionRequest,
        availability: RuntimeBackendAvailability
    ) -> RuntimeExecutionPlan {
        let layers = compatibilityLayers(for: request.format)
        let antiCheat: AntiCheatRuntimeAssessment
        if request.requiresKernelDriver {
            antiCheat = .kernelDriverRequiresSupportedWindowsKernel
        } else if request.antiCheatEnabled {
            antiCheat = .providerApprovalRequired
        } else {
            antiCheat = .notRequested
        }

        let candidates: [RuntimeBackend]
        if request.requiresFullOperatingSystem || request.requiresKernelDriver {
            // A process translator cannot provide a guest kernel or load a
            // kernel driver. QEMU is the full-system fallback, not an EAC fix.
            candidates = [.qemuTCG]
        } else {
            switch request.format {
            case .windowsX64PE:
                // Static PE translation is the preferred future path.
                // Wine/Proton + FEX/Box64 is a separate composed route; both
                // components must be installed and mutually compatible.
                candidates = [.staticAOT, .wineWithFEX, .wineWithBox64, .qemuTCG]
            case .linuxX64ELF:
                candidates = [.staticAOT, .fexCore, .box64, .qemuTCG, .x86Interpreter]
            case .linuxARM32ELF:
                candidates = [.a32rt, .qemuTCG]
            case .nativeARM64:
                candidates = [.nativeARM64, .qemuTCG]
            case .unknown:
                candidates = []
            }
        }

        let selected = candidates.first(where: availability.contains)
        var explanation: [String] = []
        if selected == nil {
            explanation.append("No installed backend in this plan is currently marked available.")
        } else if let selected {
            explanation.append("Selected candidate: \(selected.rawValue). Backend startup and guest ABI checks are still required.")
        }
        if request.format == .windowsX64PE {
            explanation.append("Windows PE execution also needs a Windows loader, DLL/import resolution, Win32/NT services, and a compatible graphics/audio/input stack.")
        }
        if request.antiCheatEnabled {
            explanation.append("Anti-cheat must be supported and approved by its publisher for this exact runtime environment; CPU translation does not grant compatibility.")
        }
        if request.requiresKernelDriver {
            explanation.append("Kernel-mode drivers require a supported Windows kernel environment; user-mode translation cannot provide one.")
        }

        return RuntimeExecutionPlan(
            selectedBackend: selected,
            candidateOrder: candidates,
            requiredLayers: layers,
            antiCheatAssessment: antiCheat,
            explanation: explanation
        )
    }

    private static func compatibilityLayers(
        for format: RuntimeGuestFormat
    ) -> [RuntimeCompatibilityLayer] {
        switch format {
        case .windowsX64PE:
            return [
                .windowsDLLLoader,
                .win32AndNT,
                .wineOrProton,
                .directXToVulkan,
                .vulkanToMetal
            ]
        case .linuxX64ELF, .linuxARM32ELF:
            return [.linuxSyscallABI]
        case .nativeARM64, .unknown:
            return []
        }
    }
}
