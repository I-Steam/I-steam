import Foundation

/// Evidence level for a runtime component. Only .operational capabilities may
/// be offered to the execution router. A loadable dylib is not proof that a
/// guest can boot or execute a workload correctly.
enum RuntimeCapabilityLevel: String, CaseIterable {
    case notProbed
    case missing
    case artifactPresent
    case loadable
    case operational
}

struct RuntimeCapabilityRecord: Equatable {
    let level: RuntimeCapabilityLevel
    let detail: String
}

/// Central snapshot of backend evidence. Probes are deliberately conservative:
/// source files and manifest entries do not count as operational runtimes.
struct RuntimeCapabilityRegistry {
    private let records: [RuntimeBackend: RuntimeCapabilityRecord]

    private init(records: [RuntimeBackend: RuntimeCapabilityRecord]) {
        self.records = records
    }

    /// The app bundle is immutable for this process, so cache the first probe
    /// rather than repeatedly dlopen/close QEMU on every game launch.
    static let current = inspect(probeQEMU: false)

    static func inspect(bundle: Bundle = .main,
                        probeQEMU: Bool = false) -> RuntimeCapabilityRegistry {
        var records: [RuntimeBackend: RuntimeCapabilityRecord] = [:]
        for backend in RuntimeBackend.allCases {
            records[backend] = RuntimeCapabilityRecord(
                level: .missing,
                detail: "No verified runtime probe is registered for this backend."
            )
        }

        if probeQEMU {
            switch QEMURuntimeStatus.inspect(bundle: bundle) {
            case .ready:
                records[.qemuTCG] = RuntimeCapabilityRecord(
                    level: .loadable,
                    detail: "The bundled library loads and required lifecycle exports resolve; guest boot and device operation are not yet verified."
                )
            case .unavailable(let reason):
                records[.qemuTCG] = RuntimeCapabilityRecord(
                    level: .missing,
                    detail: reason
                )
            }
        } else {
            records[.qemuTCG] = RuntimeCapabilityRecord(
                level: .notProbed,
                detail: "Deferred to the VM launch path to avoid loading the large QEMU dependency graph during a game-process launch."
            )
        }

        return RuntimeCapabilityRegistry(records: records)
    }

    func record(for backend: RuntimeBackend) -> RuntimeCapabilityRecord {
        records[backend] ?? RuntimeCapabilityRecord(
            level: .missing,
            detail: "No capability record was produced."
        )
    }

    /// Only operationally tested backends are exposed to the planner.
    var backendAvailability: RuntimeBackendAvailability {
        let operational = Set(RuntimeBackend.allCases.filter {
            record(for: $0).level == .operational
        })
        return RuntimeBackendAvailability(installed: operational)
    }

    var diagnostics: [String] {
        RuntimeBackend.allCases.map { backend in
            let evidence = record(for: backend)
            return "\(backend.rawValue): \(evidence.level.rawValue) — \(evidence.detail)"
        }
    }
}
