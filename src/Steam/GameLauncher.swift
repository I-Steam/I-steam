import Foundation

final class GameLauncher {
    static let shared = GameLauncher()
    private init() {}

    @discardableResult
    func launch(executable: URL, workingDirectory: URL) -> Bool {
        let result = GuestProcessManager.shared.inspect(executable)
        guard case let .success(format) = result, format == .windowsPE else {
            EmulationLog.shared.write("Game launcher rejected non-Windows executable; Linux ELF execution is not integrated either")
            return false
        }

        let process = GuestProcess(executable: executable, workingDirectory: workingDirectory, format: format)
        SteamLibrary.shared.prepare()
        WindowsRuntime.shared.prepare()
        return WindowsRuntime.shared.launch(process)
    }
}
