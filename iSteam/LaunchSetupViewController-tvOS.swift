import UIKit

final class LaunchSetupViewController: UIViewController {
    private let stack = UIStackView()
    private let status = UILabel()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Launch Setup"
        view.backgroundColor = .black
        stack.axis = .vertical
        stack.alignment = .fill
        stack.distribution = .fillEqually
        stack.spacing = 20
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 100),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -100),
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            stack.heightAnchor.constraint(equalToConstant: 360)
        ])
        let heading = UILabel()
        heading.text = "Choose a guest OS"
        heading.font = .systemFont(ofSize: 38, weight: .bold)
        heading.textColor = .white
        heading.textAlignment = .center
        stack.addArrangedSubview(heading)
        stack.addArrangedSubview(makeButton("Launch Linux / Ubuntu") { [weak self] in
            self?.launch(VMConfiguration.defaultLinux)
        })
        stack.addArrangedSubview(makeButton("Launch Windows preview") { [weak self] in
            self?.launch(VMConfiguration.defaultWindows)
        })
        status.text = "Prototype: this opens the VM display scaffold; booting a full guest OS is not yet integrated."
        status.textColor = .lightGray
        status.numberOfLines = 0
        status.textAlignment = .center
        stack.addArrangedSubview(status)
    }

    private func makeButton(_ title: String, action: @escaping () -> Void) -> UIButton {
        var config = UIButton.Configuration.filled()
        config.title = title
        config.cornerStyle = .large
        let button = UIButton(configuration: config)
        button.addAction(UIAction { _ in action() }, for: .primaryActionTriggered)
        return button
    }

    private func launch(_ configuration: VMConfiguration) {
        UserDefaults.standard.set(configuration.bootWindows ? "Windows VM" : "Linux VM", forKey: "iSteam.lastVMMode")
        navigationController?.pushViewController(VMDisplayViewController(configuration: configuration), animated: true)
    }
}
