import Foundation

enum Box64Bridge {
    static var isAvailable: Bool {
        box64IsAvailable()
    }

    static func run(executable: URL, workingDirectory: URL, arguments: [String]) -> Int32 {
        var strings = [executable.path] + arguments
        var cStrings: [UnsafeMutablePointer<CChar>?] = strings.map { strdup($0) }
        cStrings.append(nil)

        defer {
            for pointer in cStrings {
                if let pointer { free(pointer) }
            }
        }

        return cStrings.withUnsafeMutableBufferPointer { buffer in
            box64Run(
                executable.path,
                workingDirectory.path,
                Int32(strings.count),
                buffer.baseAddress
            )
        }
    }
}
