import Foundation

final class ShaderCache {
    static let shared = ShaderCache()
    private let fm = FileManager.default
    private init() {}

    var directory: URL {
        let base = fm.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let url = base.appendingPathComponent("iSteam/ShaderCache", isDirectory: true)
        try? fm.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    func prepare() {
        try? fm.createDirectory(at: directory, withIntermediateDirectories: true)
        EmulationLog.shared.write("Shader cache: \(directory.path)")
    }
}
