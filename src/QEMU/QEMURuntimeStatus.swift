import Foundation

/// Locates the UTM-built QEMU dynamic library and companion data directory.
/// The packaging workflow writes the exact library path because UTM changes
/// library names/layout between revisions. The bridge performs an explicit load/dependency/export probe before reporting ready.
enum QEMURuntimeStatus {
    case unavailable(String)
    case ready(libraryURL: URL, dataDirectory: URL)

    static func inspect(bundle: Bundle = .main) -> QEMURuntimeStatus {
        let fm = FileManager.default
        let dataDirectory = bundle.bundleURL.appendingPathComponent("QEMU", isDirectory: true)
        guard fm.fileExists(atPath: dataDirectory.path) else {
            return .unavailable("The QEMU data directory is missing from the app bundle.")
        }

        // Prefer the build-generated manifest. This avoids relying on a filename
        // that may change between UTM releases or packaging layouts.
        let manifest = dataDirectory.appendingPathComponent("runtime-library-path.txt")
        if let rawPath = try? String(contentsOf: manifest, encoding: .utf8) {
            let relativePath = rawPath.trimmingCharacters(in: .whitespacesAndNewlines)
            if !relativePath.isEmpty,
               !relativePath.hasPrefix("/"),
               !relativePath.split(separator: "/").contains("..") {
                let library = bundle.bundleURL.appendingPathComponent(relativePath)
                var isDirectory: ObjCBool = false
                if fm.fileExists(atPath: library.path, isDirectory: &isDirectory),
                   !isDirectory.boolValue {
                    return validateLoadableLibrary(library, dataDirectory: dataDirectory)
                }
            }
        }

        // Backward-compatible fallback for previously packaged runtime artifacts.
        let frameworks = bundle.privateFrameworksURL
        var candidates = [
            frameworks?.appendingPathComponent("QEMU.framework/QEMU"),
            frameworks?.appendingPathComponent("libqemu-system-x86_64.dylib"),
            frameworks?.appendingPathComponent("qemu-x86_64-softmmu"),
            frameworks?.appendingPathComponent("qemu-x86_64-softmmu.dylib"),
            bundle.bundleURL.appendingPathComponent("QEMU/libqemu-system-x86_64.dylib")
        ].compactMap { $0 }

        if let frameworks,
           let enumerator = fm.enumerator(
                at: frameworks,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles]
           ) {
            for case let url as URL in enumerator {
                let name = url.lastPathComponent.lowercased()
                if name.contains("qemu-x86_64-softmmu")
                    || name == "libqemu-system-x86_64.dylib"
                    || (name == "qemu" && url.path.contains("/QEMU.framework/")) {
                    candidates.append(url)
                }
            }
        }

        guard let library = candidates.first(where: {
            var isDirectory: ObjCBool = false
            return fm.fileExists(atPath: $0.path, isDirectory: &isDirectory)
                && !isDirectory.boolValue
        }) else {
            return .unavailable("No embedded x86_64 QEMU device library was found. Run the UTM runtime packaging workflow, embed its Frameworks and QEMU directories, and code-sign nested code.")
        }
        return validateLoadableLibrary(library, dataDirectory: dataDirectory)
    }

    /// A file's existence is not proof that it is a usable runtime. dlopen with
    /// RTLD_NOW checks the device loader, code signature and transitive dylibs;
    /// dlsym verifies the lifecycle exports required by our native bridge.
    /// This does not boot a guest or prove firmware/device support.
    private static func validateLoadableLibrary(_ library: URL,
                                                dataDirectory: URL) -> QEMURuntimeStatus {
        var errorBuffer = [CChar](repeating: 0, count: 512)
        let valid = library.path.withCString { libraryPath in
            errorBuffer.withUnsafeMutableBufferPointer { buffer -> Bool in
                guard let baseAddress = buffer.baseAddress else { return false }
                return isteam_qemu_validate_library(
                    libraryPath, baseAddress, Int32(buffer.count)
                )
            }
        }
        guard valid else {
            let message = String(cString: errorBuffer)
            return .unavailable(message.isEmpty
                ? "The bundled QEMU library failed its load/export validation."
                : message)
        }
        return .ready(libraryURL: library, dataDirectory: dataDirectory)
    }

    static var diagnostic: String {
        switch inspect() {
        case .unavailable(let reason): return reason
        case .ready(let libraryURL, let dataDirectory):
            return "QEMU library located at \(libraryURL.path); data at \(dataDirectory.path). The bridge load/dependency/export probe passed; guest boot is not verified."
        }
    }
}
