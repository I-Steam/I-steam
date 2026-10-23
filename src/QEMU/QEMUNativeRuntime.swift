import Foundation

/// Thin Swift wrapper around the optional, signed in-process QEMU library.
/// The app must bundle a QEMU build specifically compiled for arm64 iOS and
/// exporting the lifecycle functions used by QEMUNativeBridge.c.
final class QEMUNativeRuntime {
    enum RuntimeError: LocalizedError {
        case runtimeUnavailable(String)
        case invalidArguments

        var errorDescription: String? {
            switch self {
            case .runtimeUnavailable(let message): return message
            case .invalidArguments: return "QEMU launch arguments are empty."
            }
        }
    }

    private(set) var started = false

    func start(configuration: VMConfiguration, diskImage: URL, firmware: URL? = nil) throws {
        guard !started else { return }
        guard case .ready(let libraryURL, let dataDirectory) = QEMURuntimeStatus.inspect() else {
            if case .unavailable(let reason) = QEMURuntimeStatus.inspect() {
                throw RuntimeError.runtimeUnavailable(reason)
            }
            throw RuntimeError.runtimeUnavailable("QEMU runtime is unavailable.")
        }

        guard FileManager.default.fileExists(atPath: diskImage.path) else {
            throw RuntimeError.runtimeUnavailable("The selected guest disk image does not exist.")
        }

        var args = QEMUCommandBuilder(configuration: configuration).arguments(diskImage: diskImage, firmware: firmware)
        args += ["-L", dataDirectory.path]
        let argv = (["qemu-system-\(configuration.architecture.rawValue)"] + args) as NSArray
        var errorBuffer = [CChar](repeating: 0, count: 512)
        let success: Bool = argv.withUnsafeBufferPointer { _ in
            let strings = (argv as? [String] ?? []).map { strdup($0) }
            defer { strings.forEach { if let value = $0 { free(value) } } }
            return strings.withUnsafeBufferPointer { buffer in
                let pointers = buffer.map { $0.map { UnsafePointer<CChar>($0) } }
                return pointers.withUnsafeBufferPointer { pointerBuffer in
                    isteam_qemu_start(Int32(pointerBuffer.count), pointerBuffer.baseAddress,
                                      libraryURL.path, &errorBuffer, Int32(errorBuffer.count))
                }
            }
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
