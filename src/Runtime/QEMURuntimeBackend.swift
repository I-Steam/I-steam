import Foundation

/// Swift-facing lifecycle adapter for the app-bundled QEMU system-emulator runtime.
///
/// The runtime is deliberately not downloaded or loaded from an arbitrary user path.
/// Ship a signed, arm64-compatible QEMU library inside the app bundle and validate it
/// before calling this adapter.
final class QEMURuntimeBackend {
    static let shared = QEMURuntimeBackend()

    enum State: Equatable {
        case idle
        case starting
        case running
        case stopping
        case failed(String)
    }

    enum BackendError: LocalizedError {
        case alreadyActive
        case runtimeMissing
        case noArguments
        case allocationFailed
        case launchFailed(String)

        var errorDescription: String? {
            switch self {
            case .alreadyActive: return "A QEMU guest session is already active."
            case .runtimeMissing: return "The bundled QEMU runtime is missing. Build and embed runtime/qemu/libqemu-system-aarch64.dylib."
            case .noArguments: return "At least one QEMU machine or device argument is required."
            case .allocationFailed: return "Could not allocate QEMU argument storage."
            case .launchFailed(let message): return message
            }
        }
    }

    private let lock = NSLock()
    private var storedState: State = .idle

    private init() {}

    var state: State {
        lock.lock()
        defer { lock.unlock() }
        return storedState
    }

    /// Starts a guest asynchronously. Arguments are QEMU CLI arguments excluding argv[0].
    /// Poll refreshState() from the app's existing UI refresh loop to observe lifecycle changes.
    func start(arguments: [String], bundle: Bundle = .main) throws {
        guard !arguments.isEmpty else { throw BackendError.noArguments }

        lock.lock()
        guard storedState == .idle || isTerminalFailure(storedState) else {
            lock.unlock()
            throw BackendError.alreadyActive
        }
        storedState = .starting
        lock.unlock()

        guard let runtimeURL = Self.runtimeURL(in: bundle),
              FileManager.default.isReadableFile(atPath: runtimeURL.path) else {
            setState(.failed(BackendError.runtimeMissing.localizedDescription))
            throw BackendError.runtimeMissing
        }

        let argv = ["qemu-system-aarch64"] + arguments
        var allocated = [UnsafeMutablePointer<CChar>]()
        allocated.reserveCapacity(argv.count)
        for value in argv {
            guard let pointer = strdup(value) else {
                allocated.forEach { free($0) }
                setState(.failed(BackendError.allocationFailed.localizedDescription))
                throw BackendError.allocationFailed
            }
            allocated.append(pointer)
        }
        defer { allocated.forEach { free($0) } }

        let cArguments: [UnsafePointer<CChar>?] = allocated.map { UnsafePointer($0) }
        var errorBuffer = [CChar](repeating: 0, count: 512)
        let accepted = cArguments.withUnsafeBufferPointer { argumentBuffer in
            runtimeURL.path.withCString { libraryPath in
                errorBuffer.withUnsafeMutableBufferPointer { error in
                    isteam_qemu_start(
                        Int32(cArguments.count),
                        argumentBuffer.baseAddress!,
                        libraryPath,
                        error.baseAddress!,
                        Int32(error.count)
                    )
                }
            }
        }

        guard accepted else {
            let message = errorBuffer.withUnsafeBufferPointer { buffer -> String in
                guard let base = buffer.baseAddress, base.pointee != 0 else {
                    return "The native QEMU bridge rejected the launch request."
                }
                return String(cString: base)
            }
            setState(.failed(message))
            throw BackendError.launchFailed(message)
        }
    }

    func stop() {
        lock.lock()
        let shouldStop = storedState == .starting || storedState == .running
        if shouldStop { storedState = .stopping }
        lock.unlock()
        if shouldStop { isteam_qemu_request_stop() }
    }

    /// Refreshes the local state from the native bridge without creating a timer.
    @discardableResult
    func refreshState() -> State {
        let nativeRunning = isteam_qemu_is_running()
        let nativeErrorPointer = isteam_qemu_last_error()
        let nativeError = nativeErrorPointer.map { String(cString: $0) } ?? ""

        lock.lock()
        defer { lock.unlock() }

        switch storedState {
        case .starting:
            if nativeRunning {
                storedState = .running
            } else if !nativeError.isEmpty {
                storedState = .failed(nativeError)
            }
        case .running, .stopping:
            if !nativeRunning {
                storedState = nativeError.isEmpty ? .idle : .failed(nativeError)
            }
        case .idle, .failed:
            break
        }
        return storedState
    }

    private func setState(_ state: State) {
        lock.lock()
        storedState = state
        lock.unlock()
    }

    private func isTerminalFailure(_ state: State) -> Bool {
        if case .failed = state { return true }
        return false
    }

    private static func runtimeURL(in bundle: Bundle) -> URL? {
        let candidates = [
            bundle.privateFrameworksURL?.appendingPathComponent("libqemu-system-aarch64.dylib"),
            bundle.bundleURL.appendingPathComponent("Frameworks/libqemu-system-aarch64.dylib"),
            bundle.resourceURL?.appendingPathComponent("runtime/qemu/libqemu-system-aarch64.dylib")
        ]
        return candidates.compactMap { $0 }.first {
            FileManager.default.fileExists(atPath: $0.path)
        }
    }
}
