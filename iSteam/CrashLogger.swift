import Foundation
import UIKit
import Darwin

final class CrashLogger {
    static let shared = CrashLogger()
    private let queue = DispatchQueue(label: "com.chantinlongx.iSteam.crashlog")
    private let fileManager = FileManager.default
    private init() {}

    private var directory: URL {
        fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("Logs", isDirectory: true)
    }
    var latestLogURL: URL { directory.appendingPathComponent("latest-crash.log") }

    func install() {
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        NSSetUncaughtExceptionHandler { exception in
            CrashLogger.shared.record(type: "NSException", reason: exception.reason ?? "Unknown exception", details: exception.callStackSymbols.joined(separator: "\n"))
        }
        write("iSteam started — \(Date())")
    }

    func write(_ message: String) {
        queue.async {
            try? self.fileManager.createDirectory(at: self.directory, withIntermediateDirectories: true)
            let line = "[\(ISO8601DateFormatter().string(from: Date()))] \(message)\n"
            if let data = line.data(using: .utf8) {
                if let handle = try? FileHandle(forWritingTo: self.latestLogURL) {
                    try? handle.seekToEnd()
                    try? handle.write(contentsOf: data)
                    try? handle.close()
                } else {
                    try? data.write(to: self.latestLogURL)
                }
            }
        }
    }

    func record(type: String, reason: String, details: String) {
        let text = """
        ===== iSteam Crash =====
        Date: \(Date())
        Type: \(type)
        Reason: \(reason)

        \(details)

        Device: \(UIDevice.current.model)
        System: \(UIDevice.current.systemName) \(UIDevice.current.systemVersion)
        Bundle: \(Bundle.main.bundleIdentifier ?? "unknown")
        ========================
        """
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        try? text.data(using: .utf8)?.write(to: latestLogURL)
    }

    func clear() { try? fileManager.removeItem(at: latestLogURL) }
}
