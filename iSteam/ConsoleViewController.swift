import UIKit

final class ConsoleViewController: UIViewController {
    private let game: GameEntry
    private let textView = UITextView()
    private let fpsLabel = UILabel()

    private var displayLink: CADisplayLink?
    private var lastFrameTime: CFTimeInterval = 0
    private var frameCount = 0

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
        view.backgroundColor = .black

        fpsLabel.translatesAutoresizingMaskIntoConstraints = false
        fpsLabel.textColor = .white
        fpsLabel.backgroundColor = UIColor.black.withAlphaComponent(0.65)
        fpsLabel.font = .monospacedSystemFont(ofSize: 13, weight: .semibold)
        fpsLabel.textAlignment = .center
        fpsLabel.text = "FPS: --"
        fpsLabel.layer.cornerRadius = 8
        fpsLabel.clipsToBounds = true

        textView.translatesAutoresizingMaskIntoConstraints = false
        textView.isEditable = false
        textView.textColor = .white
        textView.backgroundColor = .clear
        textView.font = .monospacedSystemFont(ofSize: 13, weight: .regular)

        view.addSubview(textView)
        view.addSubview(fpsLabel)

        NSLayoutConstraint.activate([
            fpsLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 10),
            fpsLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -10),
            fpsLabel.widthAnchor.constraint(equalToConstant: 90),
            fpsLabel.heightAnchor.constraint(equalToConstant: 30),

            textView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            textView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            textView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
            textView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -12)
        ])

        startFrameMonitor()

        let available = Box64Bridge.isAvailable

        textView.text = """
        iSteam
        ======

        Game:
        \(game.name)

        Executable:
        \(game.executablePath)

        Working directory:
        \(game.workingDirectory)

        Box64:
        \(available ? "Available" : "Not linked")

        Display:
        CADisplayLink active

        Target:
        60 FPS UI / 24 FPS minimum target

        Note:
        The actual game's FPS depends on its renderer and
        the graphics backend supplied by the runtime.
        """

        if available {
            DispatchQueue.global(qos: .userInteractive).async { [weak self] in
                guard let self else { return }

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

    private func startFrameMonitor() {
        displayLink = CADisplayLink(
            target: self,
            selector: #selector(displayLinkTick(_:))
        )

        if #available(iOS 15.0, *) {
            displayLink?.preferredFrameRateRange = CAFrameRateRange(
                minimum: 24,
                maximum: 60,
                preferred: 60
            )
        } else {
            displayLink?.preferredFramesPerSecond = 60
        }

        displayLink?.add(to: .main, forMode: .common)
    }

    @objc private func displayLinkTick(_ link: CADisplayLink) {
        frameCount += 1

        if lastFrameTime == 0 {
            lastFrameTime = link.timestamp
            return
        }

        let elapsed = link.timestamp - lastFrameTime

        if elapsed >= 0.5 {
            let fps = Double(frameCount) / elapsed
            fpsLabel.text = String(format: "FPS: %.0f", fps)
            frameCount = 0
            lastFrameTime = link.timestamp
        }
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        displayLink?.invalidate()
        displayLink = nil
    }
}
