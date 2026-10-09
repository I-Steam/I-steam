import Foundation

/// Honest status facade for Windows execution.
///
/// This class deliberately does not claim to execute PE files. A real guest
/// runtime (including CPU emulation, Windows API/DLL support and process
/// memory management) must be integrated before launch can succeed.
final class WindowsRuntime {
    static let shared = WindowsRuntime()
    private init() {}

    private(set) var prepared = false

    func prepare() {
        prepared = false
        EmulationLog.shared.write("Windows runtime unavailable: guest execution engine is not integrated")
    }

    func stop() {
        prepared = false
        EmulationLog.shared.write("Windows runtime stopped")
    }

    @discardableResult
    func launch(_ process: GuestProcess) -> Bool {
        guard process.format == .windowsPE else {
            EmulationLog.shared.write("Windows launch rejected: executable is not a Windows PE file")
            return false
        }

        EmulationLog.shared.write("Cannot launch \(process.executable.lastPathComponent): i-Steam currently validates/imports PE files but has no integrated Windows guest execution engine")
        return false
    }
}
