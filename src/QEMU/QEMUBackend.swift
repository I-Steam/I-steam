import Foundation

/// Builds arguments and starts an optional in-process QEMU runtime.
/// commandPreview remains diagnostic only; iOS cannot execute this string as a
/// shell command. Actual execution uses QEMUNativeRuntime and a bundled library.
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

    func stop() {
        runtime.stop()
    }

    var isRunning: Bool { runtime.isRunning }

    private static func quote(_ value: String) -> String {
        if value.rangeOfCharacter(from: .whitespacesAndNewlines) == nil { return value }
        return "\"" + value.replacingOccurrences(of: "\"", with: "\\\"") + "\""
    }
}
