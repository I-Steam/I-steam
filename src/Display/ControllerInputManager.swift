import Foundation
import GameController

final class ControllerInputManager {
    static let shared = ControllerInputManager()
    private init() {}

    var onMove: ((Float, Float) -> Void)?
    var onLook: ((Float, Float) -> Void)?
    var onButton: ((String, Bool) -> Void)?

    func start() {
        NotificationCenter.default.addObserver(self, selector: #selector(connect(_:)), name: .GCControllerDidConnect, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(disconnect(_:)), name: .GCControllerDidDisconnect, object: nil)
        GCController.startWirelessControllerDiscovery {}
        GCController.controllers().forEach(configure)
    }

    func stop() {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func connect(_ note: Notification) {
        guard let controller = note.object as? GCController else { return }
        configure(controller)
    }

    @objc private func disconnect(_ note: Notification) {}

    private func configure(_ controller: GCController) {
        guard let pad = controller.extendedGamepad else { return }
        pad.leftThumbstick.valueChangedHandler = { [weak self] _, x, y in
            guard let self else { return }
            let profile = ControllerMappingStore.shared.profile
            let point = Self.applyDeadzone(x: x, y: y, deadzone: profile.leftDeadzone)
            if profile.swapSticks { self.onLook?(point.0, point.1) }
            else { self.onMove?(point.0, point.1) }
        }
        pad.rightThumbstick.valueChangedHandler = { [weak self] _, x, y in
            guard let self else { return }
            let profile = ControllerMappingStore.shared.profile
            var point = Self.applyDeadzone(x: x, y: y, deadzone: profile.rightDeadzone)
            if profile.invertLookY { point.1 = -point.1 }
            if profile.swapSticks { self.onMove?(point.0, point.1) }
            else { self.onLook?(point.0, point.1) }
        }
        let buttons: [(GCControllerButtonInput, String)] = [
            (pad.buttonA, "A"), (pad.buttonB, "B"), (pad.buttonX, "X"),
            (pad.buttonY, "Y"), (pad.buttonMenu, "Start"),
            (pad.leftShoulder, "LB"), (pad.rightShoulder, "RB")
        ]
        for (button, name) in buttons {
            button.valueChangedHandler = { [weak self] _, _, pressed in self?.onButton?(ControllerMappingStore.shared.profile.action(for: name), pressed) }
        }
    }

    private static func applyDeadzone(x: Float, y: Float, deadzone: Float) -> (Float, Float) {
        let magnitude = min(1, (x * x + y * y).squareRoot())
        guard magnitude > deadzone else { return (0, 0) }
        let scaled = min(1, (magnitude - deadzone) / max(0.0001, 1 - deadzone))
        let factor = scaled / magnitude
        return (x * factor, y * factor)
    }
}
