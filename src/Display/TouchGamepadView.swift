import UIKit

final class TouchGamepadView: UIView {
    var onMove: ((CGPoint) -> Void)?
    var onLook: ((CGPoint) -> Void)?
    var onButton: ((String, Bool) -> Void)?

    private let stick = UIView()
    private let knob = UIView()
    private var stickOrigin: CGPoint = .zero
    private var activeTouch: UITouch?

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isMultipleTouchEnabled = true

        stick.backgroundColor = UIColor.white.withAlphaComponent(0.17)
        stick.layer.borderColor = UIColor.white.withAlphaComponent(0.65).cgColor
        stick.layer.borderWidth = 1.5
        stick.layer.cornerRadius = 54
        addSubview(stick)

        knob.backgroundColor = UIColor.white.withAlphaComponent(0.65)
        knob.layer.cornerRadius = 22
        addSubview(knob)

        for (title, key) in [("A", "A"), ("B", "B"), ("X", "X"), ("Y", "Y"), ("＋", "Start")] {
            let button = UIButton(type: .system)
            button.setTitle(title, for: .normal)
            button.setTitleColor(.white, for: .normal)
            button.titleLabel?.font = .boldSystemFont(ofSize: 20)
            button.backgroundColor = UIColor.black.withAlphaComponent(0.35)
            button.layer.borderColor = UIColor.white.withAlphaComponent(0.65).cgColor
            button.layer.borderWidth = 1
            button.layer.cornerRadius = 25
            button.accessibilityIdentifier = key
            button.addTarget(self, action: #selector(buttonDown(_:)), for: .touchDown)
            button.addTarget(self, action: #selector(buttonUp(_:)), for: [.touchUpInside, .touchUpOutside, .touchCancel])
            addSubview(button)
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        stick.frame = CGRect(x: 18, y: bounds.height - 132, width: 108, height: 108)
        knob.frame = CGRect(x: stick.frame.midX - 22, y: stick.frame.midY - 22, width: 44, height: 44)
        let positions: [(CGFloat, CGFloat)] = [
            (bounds.width - 70, bounds.height - 90),
            (bounds.width - 125, bounds.height - 145),
            (bounds.width - 180, bounds.height - 90),
            (bounds.width - 125, bounds.height - 35),
            (bounds.midX, bounds.height - 42)
        ]
        for (i, subview) in subviews.compactMap({ $0 as? UIButton }).enumerated() where i < positions.count {
            subview.frame = CGRect(x: positions[i].0 - 25, y: positions[i].1 - 25, width: 50, height: 50)
        }
    }

    @objc private func buttonDown(_ sender: UIButton) {
        if let key = sender.accessibilityIdentifier { onButton?(key, true) }
    }

    @objc private func buttonUp(_ sender: UIButton) {
        if let key = sender.accessibilityIdentifier { onButton?(key, false) }
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first(where: { $0.location(in: self).x < bounds.width * 0.42 }) else { return }
        activeTouch = touch
        stickOrigin = stick.frame.center
        updateStick(touch.location(in: self))
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            let p = touch.location(in: self)
            if touch === activeTouch {
                updateStick(p)
            } else if p.x > bounds.width * 0.42 {
                let previous = touch.previousLocation(in: self)
                onLook?(CGPoint(x: p.x - previous.x, y: p.y - previous.y))
            }
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        if touches.contains(where: { $0 === activeTouch }) {
            activeTouch = nil
            knob.center = stickOrigin
            onMove?(.zero)
        }
    }

    private func updateStick(_ point: CGPoint) {
        let dx = point.x - stickOrigin.x
        let dy = point.y - stickOrigin.y
        let length = max(sqrt(dx * dx + dy * dy), 1)
        let scale = min(1, 38 / length)
        knob.center = CGPoint(x: stickOrigin.x + dx * scale, y: stickOrigin.y + dy * scale)
        onMove?(CGPoint(x: (knob.center.x - stickOrigin.x) / 38, y: (knob.center.y - stickOrigin.y) / 38))
    }
}

private extension CGRect {
    var center: CGPoint { CGPoint(x: midX, y: midY) }
}
