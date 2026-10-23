import Foundation

/// Coordinates a configured VM session. A session is only reported as running
/// after the native QEMU runtime accepts the launch request and its main loop
/// reports active. Without a compatible bundled runtime, startup fails clearly.
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

    init(configuration: VMConfiguration) {
        self.configuration = configuration
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
            state = .running
            EmulationLog.shared.write("QEMU session started; guest OS boot has not yet been independently verified.")
            let timer = DispatchSource.makeTimerSource(queue: .global(qos: .utility))
            timer.schedule(deadline: .now() + 1, repeating: 1)
            timer.setEventHandler { [weak self, weak candidate] in
                guard let self, let candidate else { return }
                if !candidate.isRunning {
                    self.monitor?.cancel()
                    self.monitor = nil
                    self.backend = nil
                    self.state = .failed("QEMU main loop exited. Check the emulator log and guest boot image.")
                    EmulationLog.shared.write("QEMU main loop exited unexpectedly.")
                }
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

    func stop() {
        guard case .stopped = state else {
            state = .stopping
            monitor?.cancel()
            monitor = nil
            backend?.stop()
            backend = nil
            EmulationLog.shared.write("Stopped session: \(configuration.name)")
            state = .stopped
            return
        }
    }
}
