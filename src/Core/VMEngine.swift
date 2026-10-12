import Foundation

/// Coordinates a configured VM session.
///
/// Important: this type is a session coordinator, not a full-system emulator.
/// Until a bootable machine backend is integrated, starting a Windows/Linux
/// session must fail visibly instead of reporting a false running state.
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

    /// Starts a session only when a bootable guest backend is available.
    ///
    /// The current app includes an instruction-test interpreter for a small
    /// x86-64 subset, but it does not yet include a full-system boot backend.
    /// We therefore refuse to mark an OS session as running until that backend
    /// can actually load firmware/kernel and provide devices.
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

            // GuestMachine's built-in interpreter can execute only a limited
            // instruction subset; it cannot boot Windows or a general Linux OS.
            let message = "Full-system boot is unavailable: i-Steam has no integrated QEMU/firmware/device backend. The x86-64 interpreter is for limited instruction tests only."
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
