import Foundation

final class VMEngine {
    enum State: Equatable { case stopped, starting, running, stopping, failed(String) }
    private(set) var state: State = .stopped
    private let configuration: VMConfiguration

    init(configuration: VMConfiguration) { self.configuration = configuration }

    func start() {
        guard case .stopped = state else { return }
        state = .starting
        EmulationLog.shared.write("Starting VM \(configuration.name)")
        EmulationLog.shared.write("CPU=\(configuration.architecture.rawValue) RAM=\(configuration.memoryMB)MB CPUs=\(configuration.cpuCount)")
        EmulationLog.shared.write("Accelerator=\(configuration.accelerator.rawValue) GPU=\(configuration.gpu.rawValue)")
        state = .running
    }

    func stop() {
        guard case .running = state else { return }
        state = .stopping
        EmulationLog.shared.write("Stopping VM \(configuration.name)")
        state = .stopped
    }
}
