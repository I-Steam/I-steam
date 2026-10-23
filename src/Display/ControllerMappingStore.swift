import Foundation

/// Persisted host-side controller preferences. These mappings are used by
/// ControllerInputManager; a guest still needs a transport adapter to consume
/// the resulting logical actions.
struct ControllerMappingProfile: Codable, Equatable {
    var buttonActions: [String: String]
    var leftDeadzone: Float
    var rightDeadzone: Float
    var invertLookY: Bool
    var swapSticks: Bool

    static let standard = ControllerMappingProfile(
        buttonActions: [
            "A": "confirm", "B": "cancel", "X": "west", "Y": "north",
            "Start": "menu", "LB": "previous", "RB": "next"
        ],
        leftDeadzone: 0.12,
        rightDeadzone: 0.12,
        invertLookY: false,
        swapSticks: false
    )

    func validate() throws {
        guard (0...0.8).contains(leftDeadzone),
              (0...0.8).contains(rightDeadzone),
              buttonActions.count <= 64,
              buttonActions.allSatisfy({ !$0.key.isEmpty && !$0.key.contains("\0") && !$0.value.contains("\0") }) else {
            throw MappingError.invalidProfile
        }
    }

    func action(for physicalButton: String) -> String {
        buttonActions[physicalButton] ?? physicalButton.lowercased()
    }

    enum MappingError: LocalizedError {
        case invalidProfile
        var errorDescription: String? { "The controller mapping contains invalid deadzone or button values." }
    }
}

final class ControllerMappingStore {
    static let shared = ControllerMappingStore()
    private let defaultsKey = "iSteam.controllerMapping.v1"
    private init() {}

    var profile: ControllerMappingProfile {
        get {
            guard let data = UserDefaults.standard.data(forKey: defaultsKey),
                  let value = try? JSONDecoder().decode(ControllerMappingProfile.self, from: data),
                  (try? value.validate()) != nil else { return .standard }
            return value
        }
        set {
            guard (try? newValue.validate()) != nil,
                  let data = try? JSONEncoder().encode(newValue) else { return }
            UserDefaults.standard.set(data, forKey: defaultsKey)
        }
    }

    func reset() {
        UserDefaults.standard.removeObject(forKey: defaultsKey)
    }
}
