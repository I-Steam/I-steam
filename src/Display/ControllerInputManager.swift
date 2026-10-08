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
        pad.leftThumbstick.valueChangedHandler = { [weak self] _, x, y in self?.onMove?(x, y) }
        pad.rightThumbstick.valueChangedHandler = { [weak self] _, x, y in self?.onLook?(x, y) }
        let buttons: [(GCControllerButtonInput, String)] = [
            (pad.buttonA, "A"), (pad.buttonB, "B"), (pad.buttonX, "X"),
            (pad.buttonY, "Y"), (pad.buttonMenu, "Start"),
            (pad.leftShoulder, "LB"), (pad.rightShoulder, "RB")
        ]
        for (button, name) in buttons {
            button.valueChangedHandler = { [weak self] _, _, pressed in self?.onButton?(name, pressed) }
        }
    }
}
