import UIKit

/// A configurable Xbox-style touch layout. Emits logical control events; guest
/// delivery still depends on a working runtime input bridge.
final class TouchGamepadView: UIView {
    var onMove: ((CGPoint) -> Void)?
    var onLook: ((CGPoint) -> Void)?
    var onButton: ((String, Bool) -> Void)?

    private let leftStick = StickControl()
    private let rightStick = StickControl()
    private var buttons: [UIButton] = []
    // Store normalized coordinates so layouts survive rotation, Split View and
    // Stage Manager window resizing instead of restoring controls off-screen.
    private let layoutKey = "iSteam.touchGamepad.layout.v3"
    private var editMode = false
    private var didApplyLayout = false
    private var lastBoundsSize: CGSize = .zero
    private var editButtonControl: UIButton!

    private let buttonDefinitions: [(String, String)] = [
        ("LB", "L1"), ("LT", "L2"), ("L3", "L3"),
        ("RB", "R1"), ("RT", "R2"), ("R3", "R3"),
        ("View", "View"), ("Menu", "Menu"),
        ("A", "A"), ("B", "B"), ("X", "X"), ("Y", "Y"),
        ("↑", "DPadUp"), ("↓", "DPadDown"), ("←", "DPadLeft"), ("→", "DPadRight")
    ]

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isMultipleTouchEnabled = true
        leftStick.onChange = { [weak self] value in self?.onMove?(value) }
        rightStick.onChange = { [weak self] value in self?.onLook?(value) }
        addSubview(leftStick)
        addSubview(rightStick)

        for (title, key) in buttonDefinitions {
            let button = UIButton(type: .system)
            button.setTitle(title, for: .normal)
            button.setTitleColor(.white, for: .normal)
            button.titleLabel?.font = .systemFont(ofSize: 14, weight: .bold)
            button.backgroundColor = UIColor.black.withAlphaComponent(0.55)
            button.layer.borderColor = UIColor.white.withAlphaComponent(0.65).cgColor
            button.layer.borderWidth = 1
            button.layer.cornerRadius = 24
            button.accessibilityIdentifier = key
            button.addTarget(self, action: #selector(buttonDown(_:)), for: .touchDown)
            button.addTarget(self, action: #selector(buttonUp(_:)), for: [.touchUpInside, .touchUpOutside, .touchCancel])
            let longPress = UILongPressGestureRecognizer(target: self, action: #selector(editButton(_:)))
            longPress.minimumPressDuration = 0.65
            button.addGestureRecognizer(longPress)
            addSubview(button)
            buttons.append(button)
        }

        let edit = UIButton(type: .system)
        edit.setTitle("Move / Resize", for: .normal)
        edit.setTitleColor(.white, for: .normal)
        edit.titleLabel?.font = .systemFont(ofSize: 11, weight: .semibold)
        edit.backgroundColor = UIColor.black.withAlphaComponent(0.45)
        edit.layer.cornerRadius = 8
        edit.addTarget(self, action: #selector(toggleEditMode), for: .touchUpInside)
        addSubview(edit)
        editButtonControl = edit
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        if bounds.size != lastBoundsSize {
            lastBoundsSize = bounds.size
            if !didApplyLayout {
                didApplyLayout = true
                applyDefaultLayout()
            }
            if !editMode { restoreLayout() }
        }
        editButtonControl.frame = CGRect(x: bounds.midX - 52, y: 12, width: 104, height: 30)
        if editMode { installEditGesturesIfNeeded() }
    }

    private func installEditGesturesIfNeeded() {
        for control in [leftStick as UIView, rightStick as UIView] + buttons {
            control.layer.borderColor = UIColor.systemYellow.cgColor
            control.layer.borderWidth = 2
            control.isUserInteractionEnabled = true
            if !(control.gestureRecognizers?.contains { $0 is UIPanGestureRecognizer } ?? false) {
                control.addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(dragControl(_:))))
            }
            if !(control.gestureRecognizers?.contains { $0 is UIPinchGestureRecognizer } ?? false) {
                control.addGestureRecognizer(UIPinchGestureRecognizer(target: self, action: #selector(resizeControl(_:))))
            }
        }
    }

    private func applyDefaultLayout() {
        guard bounds.width > 0, bounds.height > 0 else { return }
        let diameter: CGFloat = 94
        leftStick.frame = CGRect(x: 28, y: bounds.height - 124, width: diameter, height: diameter)
        rightStick.frame = CGRect(x: bounds.width - 122, y: bounds.height - 124, width: diameter, height: diameter)
        let positions: [CGPoint] = [
            CGPoint(x: 45, y: 55), CGPoint(x: 45, y: 103), CGPoint(x: 45, y: bounds.height - 164),
            CGPoint(x: bounds.width - 45, y: 55), CGPoint(x: bounds.width - 45, y: 103), CGPoint(x: bounds.width - 45, y: bounds.height - 164),
            CGPoint(x: bounds.midX - 38, y: 52), CGPoint(x: bounds.midX + 38, y: 52),
            CGPoint(x: bounds.width - 56, y: bounds.height - 180),
            CGPoint(x: bounds.width - 30, y: bounds.height - 222),
            CGPoint(x: bounds.width - 100, y: bounds.height - 222),
            CGPoint(x: bounds.width - 126, y: bounds.height - 180),
            CGPoint(x: bounds.midX - 44, y: bounds.height - 150),
            CGPoint(x: bounds.midX - 44, y: bounds.height - 102),
            CGPoint(x: bounds.midX - 68, y: bounds.height - 126),
            CGPoint(x: bounds.midX - 20, y: bounds.height - 126)
        ]
        for (index, button) in buttons.enumerated() where index < positions.count {
            button.frame = CGRect(x: positions[index].x - 24, y: positions[index].y - 24, width: 48, height: 48)
        }
    }

    @objc private func toggleEditMode() {
        editMode.toggle()
        editButtonControl.setTitle(editMode ? "Done Editing" : "Move / Resize", for: .normal)
        if editMode {
            installEditGesturesIfNeeded()
        } else {
            saveLayout()
            for control in [leftStick as UIView, rightStick as UIView] + buttons {
                control.layer.borderColor = UIColor.white.withAlphaComponent(0.65).cgColor
                control.layer.borderWidth = 1
                control.gestureRecognizers?.filter { $0 is UIPanGestureRecognizer || $0 is UIPinchGestureRecognizer }.forEach { control.removeGestureRecognizer($0) }
            }
        }
    }

    @objc private func editButton(_ gesture: UILongPressGestureRecognizer) {
        guard gesture.state == .began else { return }
        toggleEditMode()
    }

    @objc private func dragControl(_ gesture: UIPanGestureRecognizer) {
        guard editMode, let control = gesture.view else { return }
        let delta = gesture.translation(in: self)
        let halfW = control.bounds.width / 2
        let halfH = control.bounds.height / 2
        control.center = CGPoint(
            x: min(bounds.width - halfW, max(halfW, control.center.x + delta.x)),
            y: min(bounds.height - halfH, max(halfH, control.center.y + delta.y))
        )
        gesture.setTranslation(.zero, in: self)
        if gesture.state == .ended { saveLayout() }
    }

    @objc private func resizeControl(_ gesture: UIPinchGestureRecognizer) {
        guard editMode, let control = gesture.view else { return }
        let scale = min(1.8, max(0.65, gesture.scale))
        let newSize = min(150, max(40, control.bounds.width * scale))
        control.bounds.size = CGSize(width: newSize, height: newSize)
        control.center = CGPoint(
            x: min(bounds.width - newSize / 2, max(newSize / 2, control.center.x)),
            y: min(bounds.height - newSize / 2, max(newSize / 2, control.center.y))
        )
        if let button = control as? UIButton { button.layer.cornerRadius = newSize / 2 }
        gesture.scale = 1
        if gesture.state == .ended { saveLayout() }
    }

    @objc private func buttonDown(_ sender: UIButton) {
        guard !editMode, let key = sender.accessibilityIdentifier else { return }
        onButton?(key, true)
    }

    @objc private func buttonUp(_ sender: UIButton) {
        guard !editMode, let key = sender.accessibilityIdentifier else { return }
        onButton?(key, false)
    }

    private func saveLayout() {
        guard bounds.width > 0, bounds.height > 0 else { return }
        let controls = [leftStick as UIView, rightStick as UIView] + buttons
        let entries: [[String: CGFloat]] = controls.map { control in
            [
                "x": control.center.x / bounds.width,
                "y": control.center.y / bounds.height,
                "w": control.bounds.width / bounds.width,
                "h": control.bounds.height / bounds.height
            ]
        }
        UserDefaults.standard.set(entries, forKey: layoutKey)
    }

    private func restoreLayout() {
        guard bounds.width > 0, bounds.height > 0,
              let entries = UserDefaults.standard.array(forKey: layoutKey) as? [[String: CGFloat]],
              entries.count == buttons.count + 2 else { return }
        let controls = [leftStick as UIView, rightStick as UIView] + buttons
        for (index, control) in controls.enumerated() {
            let item = entries[index]
            let maxSize = min(150, max(40, min(bounds.width, bounds.height) * 0.22))
            let width = min(maxSize, max(40, (item["w"] ?? 0.08) * bounds.width))
            let height = min(maxSize, max(40, (item["h"] ?? 0.08) * bounds.height))
            control.bounds.size = CGSize(width: width, height: height)
            control.center = CGPoint(
                x: min(bounds.width - width / 2, max(width / 2, (item["x"] ?? 0.5) * bounds.width)),
                y: min(bounds.height - height / 2, max(height / 2, (item["y"] ?? 0.5) * bounds.height))
            )
            if let button = control as? UIButton { button.layer.cornerRadius = min(width, height) / 2 }
        }
    }
}

private final class StickControl: UIView {
    var onChange: ((CGPoint) -> Void)?
    private let knob = UIView()
    private var touchOrigin: CGPoint = .zero
    private var tracking = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = UIColor.white.withAlphaComponent(0.14)
        layer.borderColor = UIColor.white.withAlphaComponent(0.65).cgColor
        layer.borderWidth = 1.5
        layer.cornerRadius = 999
        knob.backgroundColor = UIColor.white.withAlphaComponent(0.72)
        knob.layer.cornerRadius = 18
        addSubview(knob)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        if !tracking { knob.frame = CGRect(x: bounds.midX - 18, y: bounds.midY - 18, width: 36, height: 36) }
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        tracking = true
        touchOrigin = bounds.center
        update(touch.location(in: self))
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        update(touch.location(in: self))
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        tracking = false
        knob.center = bounds.center
        onChange?(.zero)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        touchesEnded(touches, with: event)
    }

    private func update(_ point: CGPoint) {
        let dx = point.x - touchOrigin.x
        let dy = point.y - touchOrigin.y
        let length = max(sqrt(dx * dx + dy * dy), 1)
        let scale = min(1, (min(bounds.width, bounds.height) * 0.36) / length)
        knob.center = CGPoint(x: touchOrigin.x + dx * scale, y: touchOrigin.y + dy * scale)
        let radius = max(1, min(bounds.width, bounds.height) * 0.36)
        onChange?(CGPoint(x: (knob.center.x - touchOrigin.x) / radius, y: (knob.center.y - touchOrigin.y) / radius))
    }
}

private extension CGRect {
    var center: CGPoint { CGPoint(x: midX, y: midY) }
}
