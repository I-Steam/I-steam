import Foundation

final class QEMUBackend {
    private let configuration: VMConfiguration
    private let builder: QEMUCommandBuilder

    init(configuration: VMConfiguration) {
        self.configuration = configuration
        self.builder = QEMUCommandBuilder(configuration: configuration)
    }

    func commandPreview(diskImage: URL? = nil, firmware: URL? = nil) -> String {
        let args = builder.arguments(diskImage: diskImage, firmware: firmware)
        return "qemu-system-\(configuration.architecture.rawValue) " + args.map(Self.quote).joined(separator: " ")
    }

    private static func quote(_ value: String) -> String {
        if value.rangeOfCharacter(from: .whitespacesAndNewlines) == nil { return value }
        return "\"\(value.replacingOccurrences(of: "\"", with: "\\\""))\""
    }
}
