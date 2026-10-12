import Foundation

/// Locates a QEMU runtime embedded in the app bundle.
///
/// This intentionally does not launch a command-line QEMU process: iOS does
/// not provide a supported way for an app to spawn arbitrary bundled binaries.
/// A runtime is considered usable only when a native in-process bridge is
/// linked into the app. The current repository does not yet ship that bridge.
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
            return .unavailable("No embedded QEMU device runtime was found. This build contains only the command preview; a compiled arm64 iOS QEMU runtime and native lifecycle bridge are required.")
        }

        let dataDirectory = bundle.bundleURL.appendingPathComponent("QEMU", isDirectory: true)
        guard FileManager.default.fileExists(atPath: dataDirectory.path) else {
            return .unavailable("The QEMU library exists, but its QEMU data directory is missing.")
        }

        return .ready(libraryURL: library, dataDirectory: dataDirectory)
    }

    static var diagnostic: String {
        switch inspect() {
        case .unavailable(let reason):
            return reason
        case .ready(let libraryURL, let dataDirectory):
            return "QEMU library located at \(libraryURL.path); data at \(dataDirectory.path). A successful guest boot still requires the native QEMU bridge and boot smoke test."
        }
    }
}
