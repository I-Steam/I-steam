import Foundation

/// Coordinates a configured VM session. "Running" means the native QEMU main
/// loop has entered its active state; accepting a launch request is not enough.
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
    private var backend: QEMUBackend?
    private var monitor: DispatchSourceTimer?
    private var startupDeadline: DispatchTime?

    init(configuration: VMConfiguration) {
        self.configuration = configuration
    }

    /// The UI can open before a guest disk is chosen. Do not invent a disk path
    /// or report a successful boot; keep the renderer available and explain the missing input.
    func start() {
        guard case .stopped = state else { return }
        state = .failed("Choose a guest disk image in the VM setup screen before starting the engine.")
        EmulationLog.shared.write("VM start blocked: no guest disk image was supplied.")
    }

    func start(diskImage: URL, firmware: URL? = nil) {
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
            let candidate = QEMUBackend(configuration: configuration)
            try candidate.start(diskImage: diskImage, firmware: firmware)
            backend = candidate
            startupDeadline = .now() + 15
            EmulationLog.shared.write("QEMU launch accepted; waiting for the native main loop to become active.")
            let timer = DispatchSource.makeTimerSource(queue: .main)
            timer.schedule(deadline: .now() + .milliseconds(100), repeating: .milliseconds(100))
            timer.setEventHandler { [weak self, weak candidate] in
                guard let self, let candidate else { return }
                self.checkStartup(candidate)
            }
            monitor = timer
            timer.resume()
        } catch {
            backend?.stop()
            backend = nil
            state = .failed(error.localizedDescription)
            EmulationLog.shared.write("Session start failed: \(error.localizedDescription)")
        }
    }

    private func checkStartup(_ candidate: QEMUBackend) {
        guard case .starting = state else {
            if case .running = state, !candidate.isRunning {
                fail("QEMU main loop exited. Check the emulator log and guest boot image.")
            }
            return
        }
        if candidate.isRunning {
            state = .running
            startupDeadline = nil
            EmulationLog.shared.write("QEMU main loop is active. Guest OS boot is not independently verified.")
            return
        }
        if let error = candidate.lastError {
            fail("QEMU startup/runtime error: \(error)")
            return
        }
        if let deadline = startupDeadline, DispatchTime.now() >= deadline {
            fail("QEMU did not enter its active main loop within 15 seconds. Verify the bundled runtime and its startup logs.")
        }
    }

    private func fail(_ message: String) {
        monitor?.cancel()
        monitor = nil
        startupDeadline = nil
        backend?.stop()
        backend = nil
        state = .failed(message)
        EmulationLog.shared.write(message)
    }

    func stop() {
        guard case .stopped = state else {
            state = .stopping
            monitor?.cancel()
            monitor = nil
            startupDeadline = nil
            backend?.stop()
            backend = nil
            EmulationLog.shared.write("Stopped session: \(configuration.name)")
            state = .stopped
            return
        }
    }
}
