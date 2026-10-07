import UIKit

final class ConsoleViewController: UIViewController {
    private let game: GameEntry
    private let textView = UITextView()

    init(game: GameEntry) {
        self.game = game
        super.init(nibName: nil, bundle: nil)
        title = game.name
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        textView.translatesAutoresizingMaskIntoConstraints = false
        textView.isEditable = false
        textView.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        view.addSubview(textView)

        NSLayoutConstraint.activate([
            textView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            textView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            textView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
            textView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -12)
        ])

        let available = Box64Bridge.isAvailable
        textView.text = """
        iSteam
        ======

        Executable:
        (game.executablePath)

        Working directory:
        (game.workingDirectory)

        Box64 bridge:
        (available ? "Available" : "Not linked")

        Starting the executable requires a Box64 build linked into the application.
        """

        if available {
            DispatchQueue.global(qos: .userInitiated).async {
                let executable = URL(fileURLWithPath: self.game.executablePath)
                let working = URL(fileURLWithPath: self.game.workingDirectory)
                let result = Box64Bridge.run(
                    executable: executable,
                    workingDirectory: working,
                    arguments: []
                )
                DispatchQueue.main.async {
                    self.textView.text.append("\n\nProcess exited with code: \(result)")
                }
            }
        }
    }
}
