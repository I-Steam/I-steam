import Foundation

/// Owns one native QEMU session and keeps any Files-provider security scopes
/// alive for the full lifetime of QEMU (not just while constructing argv).
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
    private var scopedURLs: [URL] = []

    func start(configuration: VMConfiguration, diskImage: URL, firmware: URL? = nil) throws {
        guard !started else { return }

        try configuration.validateForStart()
        guard configuration.architecture == .x86_64 else {
            throw RuntimeError.runtimeUnavailable(
                "The bundled QEMU bridge is currently configured for x86_64 guests only."
            )
        }

        let libraryURL: URL
        let dataDirectory: URL
        switch QEMURuntimeStatus.inspect() {
        case .unavailable(let reason):
            throw RuntimeError.runtimeUnavailable(reason)
        case .ready(let library, let data):
            libraryURL = library
            dataDirectory = data
        }

        var newlyScoped: [URL] = []
        for url in [diskImage, firmware].compactMap({ $0 }) {
            let granted = url.startAccessingSecurityScopedResource()
            if granted { newlyScoped.append(url) }
            do {
                let values = try url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
                guard values.isRegularFile == true, let size = values.fileSize, size > 0 else {
                    throw RuntimeError.runtimeUnavailable(
                        "The selected disk or firmware must be a non-empty regular file."
                    )
                }
            } catch {
                newlyScoped.forEach { $0.stopAccessingSecurityScopedResource() }
                throw error
            }
        }

        var args = QEMUCommandBuilder(configuration: configuration)
            .arguments(diskImage: diskImage, firmware: firmware)
        args += ["-L", dataDirectory.path]
        let arguments = ["qemu-system-\(configuration.architecture.rawValue)"] + args
        let strings: [UnsafeMutablePointer<CChar>?] = arguments.map { strdup($0) }
        defer { strings.forEach { if let value = $0 { free(value) } } }
        var errorBuffer = [CChar](repeating: 0, count: 512)

        let pointerStrings: [UnsafePointer<CChar>] = strings.compactMap { value in
            value.map { UnsafePointer<CChar>($0) }
        }
        guard pointerStrings.count == arguments.count else {
            newlyScoped.forEach { $0.stopAccessingSecurityScopedResource() }
            throw RuntimeError.runtimeUnavailable("Unable to allocate QEMU argument strings.")
        }

        let success = pointerStrings.withUnsafeBufferPointer { pointerBuffer -> Bool in
            guard let argv = pointerBuffer.baseAddress else { return false }
            return libraryURL.path.withCString { libraryPath in
                errorBuffer.withUnsafeMutableBufferPointer { errorPointer -> Bool in
                    guard let error = errorPointer.baseAddress else { return false }
                    return isteam_qemu_start(Int32(pointerBuffer.count), argv,
                                             libraryPath, error, Int32(errorPointer.count))
                }
            }
        }

        guard success else {
            newlyScoped.forEach { $0.stopAccessingSecurityScopedResource() }
            let message = String(cString: errorBuffer)
            throw RuntimeError.runtimeUnavailable(
                message.isEmpty ? "The native QEMU bridge failed to start." : message
            )
        }

        scopedURLs = newlyScoped
        started = true
        EmulationLog.shared.write(
            "QEMU runtime start requested with disk \(diskImage.lastPathComponent)"
        )
    }

    func stop() {
        guard started else { return }
        isteam_qemu_request_stop()
        started = false
        releaseScopesWhenStopped()
    }

    private func releaseScopesWhenStopped() {
        guard isteam_qemu_is_active() else {
            scopedURLs.forEach { $0.stopAccessingSecurityScopedResource() }
            scopedURLs.removeAll()
            return
        }
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + .milliseconds(250)) { [weak self] in
            self?.releaseScopesWhenStopped()
        }
    }

    var isRunning: Bool { isteam_qemu_is_running() }

    var lastError: String? {
        let message = String(cString: isteam_qemu_last_error())
        return message.isEmpty ? nil : message
    }
}
