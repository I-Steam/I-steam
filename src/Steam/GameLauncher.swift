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

        let request = RuntimeExecutionRequest(format: .windowsX64PE)
        let plan = RuntimeBackendRouter.plan(
            for: request,
            availability: RuntimeBackendAvailability()
        )
        for message in plan.explanation {
            EmulationLog.shared.write("[runtime-plan] " + message)
        }

        // This call still returns false until a concrete PE loader, Windows
        // compatibility stack and CPU execution adapter are packaged and
        // verified. The plan is now visible at the real launch boundary.
        guard plan.isExecutableWithInstalledBackends else {
            EmulationLog.shared.write("Game launch stopped: no verified Windows execution backend is installed.")
            return false
        }
        return WindowsRuntime.shared.launch(process)
    }
}
