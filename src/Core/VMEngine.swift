import Foundation

/// Coordinates a configured VM session.
///
/// This is not itself a full-system emulator. It refuses to report a guest as
/// running until a bootable machine backend is actually integrated.
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
            let guest = GuestMachine(configuration: configuration)
            machine = guest
            guard configuration.architecture == .x86_64 else {
                throw GuestEngineError.backendNotInstalled(configuration.architecture)
            }

            let message: String
            switch QEMURuntimeStatus.inspect() {
            case .unavailable(let reason):
                message = "Full-system boot unavailable. \(reason)"
            case .ready(let libraryURL, let dataDirectory):
                message = "QEMU files detected (\(libraryURL.lastPathComponent), \(dataDirectory.lastPathComponent)), but the in-process QEMU lifecycle/display bridge and a successful boot smoke test are not implemented. Refusing to report the guest as running."
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
