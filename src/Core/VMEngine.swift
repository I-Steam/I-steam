import Foundation

/// Coordinates a configured VM session.
/// A guest is never reported as running until a bootable machine backend
/// actually starts and confirms that it is alive.
final class VMEngine {
    enum State: Equatable {
        case stopped
        case starting
        case running
        case stopping
        case failed(String)
    }

    private(set) var state: State = .stopped
    private let configuration: VMConfiguration
    private var machine: GuestMachine?

    init(configuration: VMConfiguration) {
        self.configuration = configuration
    }

    func start() {
        guard case .stopped = state else { return }
        state = .starting

        EmulationLog.shared.write("Preparing session: \(configuration.name)")
        EmulationLog.shared.write("Guest: \(configuration.bootWindows ? "Windows" : "Linux")")
        EmulationLog.shared.write("CPU=\(configuration.architecture.rawValue) RAM=\(configuration.memoryMB)MB CPUs=\(configuration.cpuCount)")
        EmulationLog.shared.write("Requested accelerator=\(configuration.accelerator.rawValue); GPU=\(configuration.gpu.rawValue); FPS=\(configuration.displayFPS)")

        do {
            try configuration.validateForStart()
            guard configuration.architecture == .x86_64 else {
                throw GuestEngineError.backendNotInstalled(configuration.architecture)
            }

            // Do not allocate guest RAM until a usable full-system backend has
            // been confirmed. The current repository only contains a CPU
            // interpreter and a QEMU command preview, not a bootable machine.
            let message: String
            switch QEMURuntimeStatus.inspect() {
            case .unavailable(let reason):
                message = "Full-system boot unavailable. \(reason)"
            case .ready(let libraryURL, let dataDirectory):
                message = "QEMU files detected (\(libraryURL.lastPathComponent), \(dataDirectory.lastPathComponent)), but the native QEMU lifecycle, device, display/input bridge, and boot smoke test are missing. Refusing to allocate guest RAM or report the guest as running."
            }
            machine = nil
            state = .failed(message)
            EmulationLog.shared.write(message)
        } catch {
            machine = nil
            state = .failed(error.localizedDescription)
            EmulationLog.shared.write("Session start failed: \(error.localizedDescription)")
        }
    }

    func stop() {
        guard case .running = state else {
            if case .failed = state {
                machine?.stop()
                machine = nil
                state = .stopped
            }
            return
        }

        state = .stopping
        machine?.stop()
        machine = nil
        EmulationLog.shared.write("Stopped session: \(configuration.name)")
        state = .stopped
    }
}
