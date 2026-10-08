import Foundation

enum GuestExecutableFormat: String {
    case windowsPE = "Windows PE"
    case linuxELF = "Linux ELF"
    case unknown = "Unknown"
}

struct GuestProcess {
    let executable: URL
    let workingDirectory: URL
    let format: GuestExecutableFormat
    var arguments: [String] = []

    var commandLine: String {
        ([executable.path] + arguments).joined(separator: " ")
    }
}

final class GuestProcessManager {
    static let shared = GuestProcessManager()
    private init() {}

    func inspect(_ url: URL) -> GuestProcessFormatResult {
        guard let handle = try? FileHandle(forReadingFrom: url) else {
            return .failure("Unable to read executable")
        }
        let data = (try? handle.read(upToCount: 4096)) ?? Data()
        if data.count >= 2 && data[data.startIndex] == 0x4D && data[data.startIndex + 1] == 0x5A {
            return .success(.windowsPE)
        }
        if data.count >= 4 && data[data.startIndex] == 0x7F && data[data.startIndex + 1] == 0x45 && data[data.startIndex + 2] == 0x4C && data[data.startIndex + 3] == 0x46 {
            return .success(.linuxELF)
        }
        return .success(.unknown)
    }
}

enum GuestProcessFormatResult {
    case success(GuestExecutableFormat)
    case failure(String)
}
