import Foundation
import UIKit

enum VMExecutionMode: String, CaseIterable {
    case windowsRuntime = "Windows Runtime"
    case windowsVM = "Windows VM"
    case linuxVM = "Linux VM"

    var detail: String {
        switch self {
        case .windowsRuntime: return "LiveExec-style guest process path"
        case .windowsVM: return "QEMU full Windows guest"
        case .linuxVM: return "QEMU Linux guest"
        }
    }
}

enum VMAccelerationBackend: String, CaseIterable {
    case automatic = "Automatic"
    case qemuJIT = "QEMU TCG + JIT"
    case qemuInterpreter = "QEMU TCG"
    case hypervisor = "Hypervisor.framework"

    var detail: String {
        switch self {
        case .automatic: return "Best available iOS backend"
        case .qemuJIT: return "Recommended for iOS"
        case .qemuInterpreter: return "Slower compatibility fallback"
        case .hypervisor: return VMAccelerationBackend.hypervisorAvailable ? "Available" : "Unavailable on iOS"
        }
    }

    static var hypervisorAvailable: Bool { false }
}

enum DisplayFrameRate: String, CaseIterable {
    case fps24 = "24 FPS"
    case fps60 = "60 FPS"
    case fps120 = "120 FPS"

    var value: Int {
        switch self {
        case .fps24: return 24
        case .fps60: return 60
        case .fps120: return 120
        }
    }

    var detail: String {
        switch self {
        case .fps24: return "Low-power / minimum target"
        case .fps60: return "Standard high-quality target"
        case .fps120: return UIScreen.main.maximumFramesPerSecond >= 120 ? "120 Hz display target" : "Requires a 120 Hz display"
        }
    }
}

final class RuntimeSettings {
    static let shared = RuntimeSettings()
    private init() {}

    private let defaults = UserDefaults.standard

    var vmMode: VMExecutionMode {
        get { VMExecutionMode(rawValue: defaults.string(forKey: "iSteam.vmMode") ?? "") ?? .windowsRuntime }
        set { defaults.set(newValue.rawValue, forKey: "iSteam.vmMode") }
    }

    var acceleration: VMAccelerationBackend {
        get { VMAccelerationBackend(rawValue: defaults.string(forKey: "iSteam.acceleration") ?? "") ?? .automatic }
        set { defaults.set(newValue.rawValue, forKey: "iSteam.acceleration") }
    }

    var frameRate: DisplayFrameRate {
        get { DisplayFrameRate(rawValue: defaults.string(forKey: "iSteam.frameRate") ?? "") ?? .fps60 }
        set { defaults.set(newValue.rawValue, forKey: "iSteam.frameRate") }
    }
}
