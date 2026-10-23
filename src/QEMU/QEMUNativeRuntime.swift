import Foundation

/// Thin Swift wrapper around the optional, signed in-process QEMU library.
/// The app must bundle a QEMU build compiled for arm64 iOS and exporting the
/// lifecycle functions used by QEMUNativeBridge.c.
final class QEMUNativeRuntime {
    enum RuntimeError: LocalizedError {
        case runtimeUnavailable(String)

        var errorDescription: String? {
            switch self {
            case .runtimeUnavailable(let message): return message
            }
        }
    }

    private(set) var started = false

    func start(configuration: VMConfiguration, diskImage: URL, firmware: URL? = nil) throws {
        guard !started else { return }
        let libraryURL: URL
        let dataDirectory: URL
        switch QEMURuntimeStatus.inspect() {
        case .unavailable(let reason):
            throw RuntimeError.runtimeUnavailable(reason)
        case .ready(let library, let data):
            libraryURL = library
            dataDirectory = data
        }

        guard FileManager.default.fileExists(atPath: diskImage.path) else {
            throw RuntimeError.runtimeUnavailable("The selected guest disk image does not exist.")
        }

        var args = QEMUCommandBuilder(configuration: configuration).arguments(diskImage: diskImage, firmware: firmware)
        args += ["-L", dataDirectory.path]
        let arguments = ["qemu-system-\(configuration.architecture.rawValue)"] + args
        let strings: [UnsafeMutablePointer<CChar>?] = arguments.map { strdup($0) }
        defer { strings.forEach { if let value = $0 { free(value) } } }
        var errorBuffer = [CChar](repeating: 0, count: 512)

        let success = strings.map { $0.map { UnsafePointer<CChar>($0) } }
            .withUnsafeBufferPointer { pointerBuffer in
                isteam_qemu_start(Int32(pointerBuffer.count), pointerBuffer.baseAddress,
                                  libraryURL.path, &errorBuffer, Int32(errorBuffer.count))
            }

        guard success else {
            let message = String(cString: errorBuffer)
            throw RuntimeError.runtimeUnavailable(message.isEmpty ? "The native QEMU bridge failed to start." : message)
        }
        started = true
        EmulationLog.shared.write("QEMU runtime start requested with disk \(diskImage.lastPathComponent)")
    }

    func stop() {
        guard started else { return }
        isteam_qemu_request_stop()
        started = false
    }

    var isRunning: Bool { isteam_qemu_is_running() }
}
