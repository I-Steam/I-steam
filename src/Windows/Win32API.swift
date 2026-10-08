import Foundation

enum Win32API {
    case fileSystem
    case threads
    case memory
    case timing
    case sockets
    case input
    case audio

    var name: String {
        switch self {
        case .fileSystem: return "FileSystem"
        case .threads: return "Threads"
        case .memory: return "Memory"
        case .timing: return "Timing"
        case .sockets: return "Sockets"
        case .input: return "Input"
        case .audio: return "Audio"
        }
    }
}

final class Win32Subsystem {
    static let shared = Win32Subsystem()
    private init() {}

    let supportedAPIs: [Win32API] = [.fileSystem, .threads, .memory, .timing, .sockets, .input, .audio]
}
