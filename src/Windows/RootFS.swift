import Foundation

final class RootFS {
    static let shared = RootFS()
    private let fm = FileManager.default
    private init() {}

    var root: URL {
        let url = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("WindowsRootFS", isDirectory: true)
        try? fm.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    func prepare() {
        let dirs = ["Windows", "Program Files", "Program Files (x86)", "Users", "Temp"]
        for dir in dirs {
            try? fm.createDirectory(at: root.appendingPathComponent(dir), withIntermediateDirectories: true)
        }
    }
}
