import Foundation

enum VRDisplayMode: String, CaseIterable {
    case flat = "Flat"
    case cardboard = "Cardboard VR"

    var detail: String {
        switch self {
        case .flat: return "Single full-screen view"
        case .cardboard: return "Side-by-side stereoscopic layout for a phone headset"
        }
    }
}

final class VRSettings {
    static let shared = VRSettings()
    private let defaults = UserDefaults.standard
    private init() {}

    var mode: VRDisplayMode {
        get { VRDisplayMode(rawValue: defaults.string(forKey: "iSteam.vrMode") ?? "") ?? .flat }
        set { defaults.set(newValue.rawValue, forKey: "iSteam.vrMode") }
    }

    var pointerLockEnabled: Bool {
        get { defaults.object(forKey: "iSteam.pointerLock") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "iSteam.pointerLock") }
    }

    var touchGamepadEnabled: Bool {
        get { defaults.object(forKey: "iSteam.touchGamepad") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "iSteam.touchGamepad") }
    }
}
