import Foundation

enum Box64Bridge {
    static var isAvailable: Bool {
        box64IsAvailable()
    }

    static func run(executable: URL, workingDirectory: URL, arguments: [String]) -> Int32 {
        var args = [executable.path] + arguments
        var cArgs = args.map { strdup($0) }
        cArgs.append(nil)
        defer {
            for pointer in cArgs.dropLast() {
                free(pointer)
            }
        }

        return cArgs.withUnsafeBufferPointer { buffer in
            box64Run(
                executable.path,
                workingDirectory.path,
                Int32(args.count),
                buffer.baseAddress
            )
        }
    }
}
