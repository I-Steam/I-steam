import Foundation
import UIKit

enum JITMethod: String, CaseIterable {
    case waitForDebugger = "Wait for Debugger"
    case stikDebug = "StikDebug"
}

final class JITCoordinator {
    static let shared = JITCoordinator()
    private init() {}

    var selectedMethod: JITMethod {
        get {
            JITMethod(rawValue: UserDefaults.standard.string(forKey: "iSteam.jitMethod") ?? "") ?? .stikDebug
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: "iSteam.jitMethod")
        }
    }

    var isRunningInLiveContainer: Bool {
        getenv("LC_HOME_PATH") != nil
    }

    // The entitlement cannot be queried with SecTask on the public iOS SDK.
    // Keep this conservative; signing/JIT helpers are responsible for granting it.
    var hasGetTaskAllow: Bool { false }

    var isJITProtocolSupported: Bool {
        iSteamJITIsSupported()
    }

    func requestJIT(from controller: UIViewController?) {
        guard hasGetTaskAllow else {
            show("This installation does not expose get-task-allow. Re-sign it with a JIT-capable signer.", title: "JIT unavailable", on: controller)
            return
        }

        switch selectedMethod {
        case .waitForDebugger:
            show("Attach StikDebug or another compatible JIT debugger to this process.", title: "Waiting for debugger", on: controller)
        case .stikDebug:
            openStikDebug(on: controller)
        }
    }

    private func openStikDebug(on controller: UIViewController?) {
        guard let bundleID = Bundle.main.bundleIdentifier else { return }
        var c = URLComponents()
        c.scheme = "stikdebug"
        c.host = "enable-jit"
        c.queryItems = [
            URLQueryItem(name: "bundle-id", value: bundleID),
            URLQueryItem(name: "pid", value: String(getpid())),
            URLQueryItem(name: "script-name", value: "universal.js")
        ]
        guard let url = c.url else { return }
        UIApplication.shared.open(url)
    }

    private func show(_ message: String, title: String, on controller: UIViewController?) {
        guard let controller else { return }
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        controller.present(alert, animated: true)
    }
}
