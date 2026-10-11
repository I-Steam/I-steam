import UIKit

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        let window = UIWindow(frame: UIScreen.main.bounds)
        window.rootViewController = UINavigationController(rootViewController: TVHomeViewController())
        window.makeKeyAndVisible()
        self.window = window
        return true
    }
}

private final class TVHomeViewController: UIViewController {
    private let stack = UIStackView()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "i-Steam"
        view.backgroundColor = .black

        stack.axis = .vertical
        stack.alignment = .fill
        stack.distribution = .fillEqually
        stack.spacing = 22
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        let titleLabel = UILabel()
        titleLabel.text = "i-Steam for Apple TV"
        titleLabel.font = .systemFont(ofSize: 48, weight: .bold)
        titleLabel.textAlignment = .center
        titleLabel.textColor = .white
        stack.addArrangedSubview(titleLabel)

        let subtitle = UILabel()
        subtitle.text = "tvOS interface preview"
        subtitle.font = .systemFont(ofSize: 24)
        subtitle.textAlignment = .center
        subtitle.textColor = .lightGray
        stack.addArrangedSubview(subtitle)

        stack.addArrangedSubview(makeButton("Launch session") { [weak self] in
            self?.showNotice(
                title: "Runtime not connected",
                message: "The tvOS interface is building separately. The virtual-machine engine is not yet connected to this Apple TV target."
            )
        })
        stack.addArrangedSubview(makeButton("Steam Store") { [weak self] in
            self?.showNotice(
                title: "Steam Store",
                message: "The embedded store browser is available in the iOS app. A tvOS-compatible store experience has not been implemented yet."
            )
        })
        stack.addArrangedSubview(makeButton("Settings") { [weak self] in
            self?.showNotice(
                title: "Settings",
                message: "Apple TV settings controls will be added as the tvOS target is ported."
            )
        })

        NSLayoutConstraint.activate([
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 220),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -220),
            stack.heightAnchor.constraint(equalToConstant: 440)
        ])
    }

    private func makeButton(_ title: String, action: @escaping () -> Void) -> UIButton {
        var config = UIButton.Configuration.filled()
        config.title = title
        config.cornerStyle = .large
        config.buttonSize = .large
        let button = UIButton(configuration: config)
        button.addAction(UIAction { _ in action() }, for: .primaryActionTriggered)
        return button
    }

    private func showNotice(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}
