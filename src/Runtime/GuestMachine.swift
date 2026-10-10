import Foundation

/// CPU backend boundary. A real emulator implementation must be supplied.
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

final class GuestMachine {
    enum State: Equatable {
        case stopped, configured, running, paused, failed(String)
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

    func installCPUBackend(_ backend: GuestCPUBackend) throws {
        guard backend.architecture == configuration.architecture else {
            throw GuestEngineError.backendNotInstalled(configuration.architecture)
        }
        cpu?.requestStop()
        cpu = backend
        state = .configured
        lastExit = nil
    }

    /// Loads an ELF64 image into guest memory and initializes the CPU at its
    /// entry point. Loading requires a compatible, real CPU backend to be installed.
    @discardableResult
    func loadELFImage(at url: URL) throws -> ELF64Loader.Image {
        guard let cpu else {
            let error = GuestEngineError.backendNotInstalled(configuration.architecture)
            state = .failed(error.localizedDescription)
            throw error
        }

        do {
            let image = try ELF64Loader().load(url, into: memory,
                                               expectedArchitecture: configuration.architecture)
            try cpu.reset(entryPoint: image.entryPoint)
            lastExit = nil
            state = .configured
            return image
        } catch {
            state = .failed(error.localizedDescription)
            throw error
        }
    }

    /// Resets CPU registers only. Loaded guest memory is deliberately preserved.
    func reset(entryPoint: UInt64) throws {
        guard let cpu else {
            let error = GuestEngineError.backendNotInstalled(configuration.architecture)
            state = .failed(error.localizedDescription)
            throw error
        }
        do {
            try cpu.reset(entryPoint: entryPoint)
            lastExit = nil
            state = .configured
        } catch {
            state = .failed(error.localizedDescription)
            throw error
        }
    }

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
            case .instructionLimit: state = .configured
            case .interrupted: state = .paused
            case .halted: state = .stopped
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
