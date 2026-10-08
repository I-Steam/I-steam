import Foundation

final class TranslationCache {
    static let shared = TranslationCache()
    private let fm = FileManager.default
    private init() {}

    var directory: URL {
        let base = fm.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let url = base.appendingPathComponent("iSteam/TranslationCache", isDirectory: true)
        try? fm.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    func prepare() {
        try? fm.createDirectory(at: directory, withIntermediateDirectories: true)
        EmulationLog.shared.write("Translation cache: \(directory.path)")
    }

    func path(for key: String) -> URL {
        directory.appendingPathComponent(key.replacingOccurrences(of: "/", with: "_"))
    }
}
