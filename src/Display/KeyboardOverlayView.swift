import UIKit

/// On-screen key panel for touch-only play. Key events are surfaced through
/// onKey so the runtime input bridge can consume them.
final class KeyboardOverlayView: UIView {
    var onKey: ((String) -> Void)?

    private let column = UIStackView()

    init(onKey: @escaping (String) -> Void) {
        self.onKey = onKey
        super.init(frame: .zero)
        configure()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func configure() {
        backgroundColor = UIColor(white: 0.08, alpha: 0.94)
        layer.cornerRadius = 14
        layer.borderWidth = 1
        layer.borderColor = UIColor.white.withAlphaComponent(0.16).cgColor
        clipsToBounds = true

        column.axis = .vertical
        column.alignment = .fill
        column.distribution = .fillEqually
        column.spacing = 5
        column.translatesAutoresizingMaskIntoConstraints = false
        addSubview(column)
        NSLayoutConstraint.activate([
            column.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            column.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            column.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            column.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8)
        ])

        addRow(["1","2","3","4","5","6","7","8","9","0","-","="])
        addRow(["Q","W","E","R","T","Y","U","I","O","P","[","]"])
        addRow(["A","S","D","F","G","H","J","K","L",";","'"])
        addRow(["SHIFT","Z","X","C","V","B","N","M",",",".","/","⌫"])
        addRow(["ESC","TAB","CTRL","ALT","SPACE","←","↑","↓","→","ENTER"])
    }

    private func addRow(_ keys: [String]) {
        let row = UIStackView()
        row.axis = .horizontal
        row.alignment = .fill
        row.distribution = .fillEqually
        row.spacing = 4
        for key in keys {
            let button = UIButton(type: .system)
            button.setTitle(key == "SPACE" ? "Space" : key, for: .normal)
            button.titleLabel?.font = .systemFont(ofSize: key.count > 1 ? 10 : 13, weight: .semibold)
            button.setTitleColor(.white, for: .normal)
            button.backgroundColor = UIColor(white: 0.24, alpha: 1)
            button.layer.cornerRadius = 5
            button.accessibilityLabel = key
            button.addAction(UIAction { [weak self] _ in
                self?.onKey?(key == "⌫" ? "BACKSPACE" : key)
            }, for: .touchUpInside)
            row.addArrangedSubview(button)
        }
        column.addArrangedSubview(row)
    }
}
