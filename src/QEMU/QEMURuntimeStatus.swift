import Foundation

/// Locates an app-bundled QEMU library and its data directory.
/// Presence alone is not enough: the native bridge also checks that the
/// expected lifecycle symbols can be resolved when starting a session.
enum QEMURuntimeStatus {
    case unavailable(String)
    case ready(libraryURL: URL, dataDirectory: URL)

    static func inspect(bundle: Bundle = .main) -> QEMURuntimeStatus {
        let frameworks = bundle.privateFrameworksURL
        let candidates = [
            frameworks?.appendingPathComponent("QEMU.framework/QEMU"),
            frameworks?.appendingPathComponent("libqemu-system-x86_64.dylib"),
            bundle.bundleURL.appendingPathComponent("QEMU/libqemu-system-x86_64.dylib")
        ].compactMap { $0 }

        guard let library = candidates.first(where: { FileManager.default.fileExists(atPath: $0.path) }) else {
            return .unavailable("No embedded QEMU device runtime was found. Bundle a code-signed arm64 iOS QEMU library with exported qemu_init, qemu_main_loop, qemu_cleanup and qemu_system_shutdown_request symbols.")
        }

        let dataDirectory = bundle.bundleURL.appendingPathComponent("QEMU", isDirectory: true)
        guard FileManager.default.fileExists(atPath: dataDirectory.path) else {
            return .unavailable("The QEMU library exists, but its QEMU data directory is missing.")
        }
        return .ready(libraryURL: library, dataDirectory: dataDirectory)
    }

    static var diagnostic: String {
        switch inspect() {
        case .unavailable(let reason): return reason
        case .ready(let libraryURL, let dataDirectory):
            return "QEMU library located at \(libraryURL.path); data at \(dataDirectory.path). The bridge will validate lifecycle exports at startup."
        }
    }
}
