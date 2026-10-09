import Foundation

/// The CPU boundary used by the guest machine.
///
/// A backend must implement instruction execution and register state. Merely
/// conforming to this protocol does not make a CPU emulator; i-Steam currently
/// has no production x86_64 or ARM64 guest CPU backend wired in.
protocol GuestCPUBackend: AnyObject {
    var architecture: VMConfiguration.Architecture { get }
    var instructionCount: UInt64 { get }

    func reset(entryPoint: UInt64) throws
    func run(maxInstructions: UInt64) throws -> GuestCPUExit
    func requestStop()
}

enum GuestCPUExit: Equatable {
    case instructionLimit
    case halted
    case interrupted
    case unsupportedInstruction(address: UInt64)
    case memoryFault(address: UInt64)
    case backendUnavailable(String)
}

enum GuestEngineError: LocalizedError {
    case invalidInstructionBudget
    case backendNotInstalled(VMConfiguration.Architecture)

    var errorDescription: String? {
        switch self {
        case .invalidInstructionBudget:
            return "The guest CPU instruction budget must be greater than zero."
        case .backendNotInstalled(let architecture):
            return "No guest CPU backend is installed for \(architecture.rawValue)."
        }
    }
}

/// Explicit engine state so UI and logs cannot mistake a configured VM for a
/// running guest. The engine deliberately fails closed until a real backend is
/// registered.
final class GuestMachine {
    enum State: Equatable {
        case stopped
        case configured
        case running
        case paused
        case failed(String)
    }

    let configuration: VMConfiguration
    let memory: GuestMemory
    private(set) var state: State = .stopped
    private(set) var lastExit: GuestCPUExit?
    private var cpu: GuestCPUBackend?

    init(configuration: VMConfiguration, memorySize: UInt64? = nil) {
        self.configuration = configuration
        let requestedSize = memorySize ?? UInt64(max(1, configuration.memoryMB)) * 1024 * 1024
        self.memory = GuestMemory(size: requestedSize)
    }

    /// Installs a compatible CPU backend. This is dependency injection only;
    /// the caller must supply a real emulator implementation.
    func installCPUBackend(_ backend: GuestCPUBackend) throws {
        guard backend.architecture == configuration.architecture else {
            throw GuestEngineError.backendNotInstalled(configuration.architecture)
        }
        cpu?.requestStop()
        cpu = backend
        state = .configured
        lastExit = nil
    }

    func reset(entryPoint: UInt64) throws {
        guard let cpu else {
            state = .failed(GuestEngineError.backendNotInstalled(configuration.architecture).localizedDescription)
            throw GuestEngineError.backendNotInstalled(configuration.architecture)
        }
        memory.clear()
        do {
            try cpu.reset(entryPoint: entryPoint)
            lastExit = nil
            state = .configured
        } catch {
            state = .failed(error.localizedDescription)
            throw error
        }
    }

    /// Runs a bounded batch so the host app can yield between batches instead
    /// of freezing the UI. A future scheduler should call this off the main
    /// thread and apply a time budget as well.
    @discardableResult
    func runBatch(maxInstructions: UInt64) throws -> GuestCPUExit {
        guard maxInstructions > 0 else { throw GuestEngineError.invalidInstructionBudget }
        guard let cpu else {
            let error = GuestEngineError.backendNotInstalled(configuration.architecture)
            state = .failed(error.localizedDescription)
            throw error
        }

        state = .running
        do {
            let exit = try cpu.run(maxInstructions: maxInstructions)
            lastExit = exit
            switch exit {
            case .instructionLimit:
                state = .configured
            case .interrupted:
                state = .paused
            case .halted:
                state = .stopped
            case .unsupportedInstruction, .memoryFault, .backendUnavailable:
                state = .failed(String(describing: exit))
            }
            return exit
        } catch {
            state = .failed(error.localizedDescription)
            throw error
        }
    }

    func pause() {
        cpu?.requestStop()
        if state == .running { state = .paused }
    }

    func stop() {
        cpu?.requestStop()
        memory.clear()
        state = .stopped
        lastExit = nil
    }
}
