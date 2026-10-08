import Foundation

enum AntiCheatCompatibility {
    case supported
    case guestOnly
    case unsupported

    var message: String {
        switch self {
        case .supported: return "Normal user-mode compatibility"
        case .guestOnly: return "Requires a complete Windows guest"
        case .unsupported: return "Kernel anti-cheat may reject emulated/virtualized environments"
        }
    }
}

final class AntiCheatCompatibilityChecker {
    static let shared = AntiCheatCompatibilityChecker()
    private init() {}

    func check() -> AntiCheatCompatibility {
        .guestOnly
    }
}
