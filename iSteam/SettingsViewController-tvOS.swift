import UIKit

final class SettingsViewController: UIViewController {
    private let stack = UIStackView()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Settings"
        view.backgroundColor = .black
        stack.axis = .vertical
        stack.alignment = .fill
        stack.spacing = 20
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 100),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -100),
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
        addLabel("i-Steam tvOS Nightly", size: 34, weight: .bold)
        addLabel("Display: \(RuntimeSettings.shared.renderResolution.title)", size: 24)
        addLabel("FPS target: \(RuntimeSettings.shared.frameRate.value)", size: 24)
        addLabel("VM acceleration: \(RuntimeSettings.shared.acceleration.rawValue)", size: 24)
        addLabel("Motion controls are unavailable on tvOS. Full guest OS boot is not yet integrated.", size: 20)
        var config = UIButton.Configuration.filled()
        config.title = "Back"
        let button = UIButton(configuration: config)
        button.addAction(UIAction { [weak self] _ in self?.navigationController?.popViewController(animated: true) }, for: .primaryActionTriggered)
        stack.addArrangedSubview(button)
    }

    private func addLabel(_ text: String, size: CGFloat, weight: UIFont.Weight = .regular) {
        let label = UILabel()
        label.text = text
        label.font = .systemFont(ofSize: size, weight: weight)
        label.textColor = .white
        label.numberOfLines = 0
        stack.addArrangedSubview(label)
    }
}
