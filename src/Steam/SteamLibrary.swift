import Foundation

final class SteamLibrary {
    static let shared = SteamLibrary()
    private let fm = FileManager.default
    private init() {}

    var root: URL {
        let url = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("SteamLibrary", isDirectory: true)
        try? fm.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    func prepare() {
        try? fm.createDirectory(at: root, withIntermediateDirectories: true)
        RootFS.shared.prepare()
    }
}
