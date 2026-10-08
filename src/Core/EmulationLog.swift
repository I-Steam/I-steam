import Foundation

final class EmulationLog {
    static let shared = EmulationLog()
    private let queue = DispatchQueue(label: "com.chantinlongx.iSteam.emulation-log")
    private let fm = FileManager.default
    private var url: URL {
        let dir = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Logs", isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("emulation.log")
    }
    private init() {}

    func write(_ message: String) {
        queue.async {
            let line = "[\(ISO8601DateFormatter().string(from: Date()))] \(message)\n"
            guard let data = line.data(using: .utf8) else { return }
            if let handle = try? FileHandle(forWritingTo: self.url) {
                try? handle.seekToEnd()
                try? handle.write(contentsOf: data)
                try? handle.close()
            } else {
                try? data.write(to: self.url)
            }
        }
    }
}
