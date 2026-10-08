import Foundation
enum Box64Bridge {
    static var isAvailable: Bool { box64IsAvailable() }
    static func run(executable: URL, workingDirectory: URL, arguments: [String]) -> Int32 {
        let strings = [executable.path] + arguments
        let allocated: [UnsafeMutablePointer<CChar>?] = strings.map { strdup($0) }
        defer { for pointer in allocated { if let pointer { free(pointer) } } }
        var argv: [UnsafePointer<CChar>?] = allocated.map { pointer in
            guard let pointer else { return nil }
            return UnsafePointer<CChar>(pointer)
        }
        argv.append(nil)
        return argv.withUnsafeBufferPointer { buffer in
            box64Run(executable.path, workingDirectory.path, Int32(strings.count), buffer.baseAddress)
        }
    }
}