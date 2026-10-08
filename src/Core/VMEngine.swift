import Foundation

final class VMEngine {
    enum State: Equatable {
        case stopped, starting, running, stopping, failed(String)
    }

    private(set) var state: State = .stopped
    private let configuration: VMConfiguration

    init(configuration: VMConfiguration) {
        self.configuration = configuration
    }

    func start() {
        guard case .stopped = state else { return }
        state = .starting
        EmulationLog.shared.write("Starting \(configuration.name)")
        EmulationLog.shared.write("Guest: \(configuration.bootWindows ? "Windows" : "Linux")")
        EmulationLog.shared.write("CPU=\(configuration.architecture.rawValue) RAM=\(configuration.memoryMB)MB CPUs=\(configuration.cpuCount)")
        EmulationLog.shared.write("Accelerator=\(configuration.accelerator.rawValue), JIT=\(configuration.accelerator == .jit)")
        EmulationLog.shared.write("GPU=\(configuration.gpu.rawValue), FPS=\(configuration.displayFPS)")
        WindowsRuntime.shared.prepare()
        TranslationCache.shared.prepare()
        ShaderCache.shared.prepare()
        state = .running
    }

    func stop() {
        guard case .running = state else { return }
        state = .stopping
        WindowsRuntime.shared.stop()
        EmulationLog.shared.write("Stopping \(configuration.name)")
        state = .stopped
    }
}
