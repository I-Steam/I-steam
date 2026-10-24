import Foundation

/// Locates the UTM-built QEMU dynamic library and its companion data directory.
/// The bridge validates lifecycle exports again when dlopen is attempted.
enum QEMURuntimeStatus {
    case unavailable(String)
    case ready(libraryURL: URL, dataDirectory: URL)

    static func inspect(bundle: Bundle = .main) -> QEMURuntimeStatus {
        let frameworks = bundle.privateFrameworksURL
        var candidates = [
            frameworks?.appendingPathComponent("QEMU.framework/QEMU"),
            frameworks?.appendingPathComponent("libqemu-system-x86_64.dylib"),
            frameworks?.appendingPathComponent("qemu-x86_64-softmmu"),
            frameworks?.appendingPathComponent("qemu-x86_64-softmmu.dylib"),
            bundle.bundleURL.appendingPathComponent("QEMU/libqemu-system-x86_64.dylib")
        ].compactMap { $0 }

        // UTM versions differ in the exact suffix and may wrap a library in a
        // framework. Discover only QEMU x86_64 softmmu libraries, not QEMUHelper.
        if let frameworks,
           let enumerator = FileManager.default.enumerator(
                at: frameworks,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles]
           ) {
            for case let url as URL in enumerator {
                let name = url.lastPathComponent.lowercased()
                let isQEMULibrary = name.contains("qemu-x86_64-softmmu")
                    || name == "libqemu-system-x86_64.dylib"
                    || (name == "qemu" && url.path.contains("/QEMU.framework/"))
                if isQEMULibrary { candidates.append(url) }
            }
        }

        let fm = FileManager.default
        guard let library = candidates.first(where: {
            var isDirectory: ObjCBool = false
            return fm.fileExists(atPath: $0.path, isDirectory: &isDirectory) && !isDirectory.boolValue
        }) else {
            return .unavailable("No embedded x86_64 QEMU device library was found. Build and embed the UTM arm64 iOS runtime, including its Frameworks dependencies.")
        }

        let dataDirectory = bundle.bundleURL.appendingPathComponent("QEMU", isDirectory: true)
        guard fm.fileExists(atPath: dataDirectory.path) else {
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
