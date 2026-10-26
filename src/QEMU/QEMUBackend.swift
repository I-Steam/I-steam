import Foundation

/// Starts the in-process QEMU runtime. The command preview is diagnostic only.
final class QEMUBackend {
    private let configuration: VMConfiguration
    private let builder: QEMUCommandBuilder
    private let runtime = QEMUNativeRuntime()

    init(configuration: VMConfiguration) {
        self.configuration = configuration
        self.builder = QEMUCommandBuilder(configuration: configuration)
    }

    func commandPreview(diskImage: URL? = nil, firmware: URL? = nil) -> String {
        let args = builder.arguments(diskImage: diskImage, firmware: firmware)
        return "qemu-system-\(configuration.architecture.rawValue) " + args.map(Self.quote).joined(separator: " ")
    }

    func start(diskImage: URL, firmware: URL? = nil) throws {
        try runtime.start(configuration: configuration, diskImage: diskImage, firmware: firmware)
    }

    func stop() { runtime.stop() }

    var isRunning: Bool { runtime.isRunning }
    var isActive: Bool { runtime.isActive }
    var lastError: String? { runtime.lastError }

    private static func quote(_ value: String) -> String {
        if value.rangeOfCharacter(from: .whitespacesAndNewlines) == nil { return value }
        return "\"" + value.replacingOccurrences(of: "\"", with: "\\\"") + "\""
    }
}
