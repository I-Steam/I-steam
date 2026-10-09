import UIKit
import GameController

final class VMDisplayViewController: UIViewController {
    private let gpu: MetalGPUBackend
    private let virtioGPU: VirtIOGPU
    private let engine: VMEngine
    private let status = UILabel()
    private var gamepad: TouchGamepadView?
    private let vrSettings = VRSettings.shared
    private var keyboardPanel: KeyboardOverlayView?
    private let keyboardToggle = UIButton(type: .system)
    private let functionKeyBar = UIStackView()
    private var keyboardObservers: [NSObjectProtocol] = []

    init(configuration: VMConfiguration) {
        let size = RuntimeSettings.shared.renderResolution
        let backend = MetalGPUBackend(width: size.width, height: size.height, frameRate: RuntimeSettings.shared.frameRate.value)
        self.gpu = backend
        self.virtioGPU = VirtIOGPU(backend: backend)
        self.engine = VMEngine(configuration: configuration)
        super.init(nibName: nil, bundle: nil)
        title = configuration.name
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override var prefersStatusBarHidden: Bool { true }
    override var prefersHomeIndicatorAutoHidden: Bool { true }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        gpu.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(gpu.view)
        status.translatesAutoresizingMaskIntoConstraints = false
        status.textColor = .white
        status.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        status.font = .monospacedSystemFont(ofSize: 12, weight: .medium)
        status.text = "\(RuntimeSettings.shared.renderResolution.title) • \(RuntimeSettings.shared.frameRate.value) FPS target • Metal"
        status.textAlignment = .center
        status.layer.cornerRadius = 8
        status.clipsToBounds = true
        view.addSubview(status)
        NSLayoutConstraint.activate([
            gpu.view.topAnchor.constraint(equalTo: view.topAnchor),
            gpu.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            gpu.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            gpu.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            status.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            status.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            status.heightAnchor.constraint(equalToConstant: 30)
        ])
        if vrSettings.mode == .cardboard { applyCardboardLayout() }
        addTouchGamepad() // Show the on-screen gamepad by default; settings can be wired to hide it later.
        addKeyboardControls()
        configureControllerInput()
        configureMotionInput()
        registerKeyboardNotifications()
        refreshHardwareKeyboardState()
        virtioGPU.start()
        engine.start()
    }

    private func applyCardboardLayout() {
        // Layout scaffold only; true stereo needs independent per-eye guest rendering.
        gpu.view.transform = CGAffineTransform(scaleX: 0.5, y: 1)
        gpu.view.layer.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        gpu.view.frame = CGRect(x: 0, y: 0, width: view.bounds.width * 2, height: view.bounds.height)
        gpu.view.contentMode = .scaleAspectFit
        status.text = "CARDBOARD • motion look prototype"
    }

    private func addKeyboardControls() {
        keyboardToggle.translatesAutoresizingMaskIntoConstraints = false
        keyboardToggle.setTitle("⌨ Keyboard", for: .normal)
        keyboardToggle.setTitleColor(.white, for: .normal)
        keyboardToggle.titleLabel?.font = .systemFont(ofSize: 13, weight: .semibold)
        keyboardToggle.backgroundColor = UIColor.black.withAlphaComponent(0.78)
        keyboardToggle.layer.cornerRadius = 9
        keyboardToggle.contentEdgeInsets = UIEdgeInsets(top: 8, left: 12, bottom: 8, right: 12)
        keyboardToggle.addTarget(self, action: #selector(toggleTouchKeyboard), for: .touchUpInside)
        view.addSubview(keyboardToggle)

        functionKeyBar.translatesAutoresizingMaskIntoConstraints = false
        functionKeyBar.axis = .horizontal
        functionKeyBar.alignment = .fill
        functionKeyBar.distribution = .fillEqually
        functionKeyBar.spacing = 4
        functionKeyBar.backgroundColor = UIColor.black.withAlphaComponent(0.84)
        for number in 1...12 {
            let key = "F\(number)"
            let button = UIButton(type: .system)
            button.setTitle(key, for: .normal)
            button.titleLabel?.font = .systemFont(ofSize: 11, weight: .bold)
            button.setTitleColor(.white, for: .normal)
            button.backgroundColor = UIColor(white: 0.24, alpha: 1)
            button.layer.cornerRadius = 5
            button.addAction(UIAction { [weak self] _ in self?.emitKeyboardKey(key) }, for: .touchUpInside)
            functionKeyBar.addArrangedSubview(button)
        }
        view.addSubview(functionKeyBar)
        functionKeyBar.isHidden = true

        let panel = KeyboardOverlayView { [weak self] key in self?.emitKeyboardKey(key) }
        panel.translatesAutoresizingMaskIntoConstraints = false
        panel.isHidden = true
        view.addSubview(panel)
        keyboardPanel = panel

        NSLayoutConstraint.activate([
            keyboardToggle.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            keyboardToggle.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
            functionKeyBar.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 8),
            functionKeyBar.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -8),
            functionKeyBar.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -4),
            functionKeyBar.heightAnchor.constraint(equalToConstant: 38),
            panel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 8),
            panel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -8),
            panel.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -4),
            panel.heightAnchor.constraint(equalToConstant: 238)
        ])
    }

    @objc private func toggleTouchKeyboard() {
        guard let panel = keyboardPanel else { return }
        panel.isHidden.toggle()
        keyboardToggle.setTitle(panel.isHidden ? "⌨ Keyboard" : "⌨ Hide keyboard", for: .normal)
        if !panel.isHidden { functionKeyBar.isHidden = true }
        else { refreshHardwareKeyboardState() }
    }

    private func emitKeyboardKey(_ key: String) {
        // The UI emits normalized key names; guest injection needs a connected
        // runtime input backend, which is not implemented in this scaffold yet.
        EmulationLog.shared.write("Keyboard input: \(key)")
    }

    private func registerKeyboardNotifications() {
        let center = NotificationCenter.default
        keyboardObservers.append(center.addObserver(
            forName: Notification.Name("GCKeyboardDidConnectNotification"),
            object: nil, queue: .main
        ) { [weak self] _ in self?.refreshHardwareKeyboardState() })
        keyboardObservers.append(center.addObserver(
            forName: Notification.Name("GCKeyboardDidDisconnectNotification"),
            object: nil, queue: .main
        ) { [weak self] _ in self?.refreshHardwareKeyboardState() })
    }

    private func refreshHardwareKeyboardState() {
        let connected = GCKeyboard.coalesced != nil
        // F-keys are only shown while a hardware keyboard is connected, and are
        // immediately hidden after disconnect or while the touch keyboard is open.
        functionKeyBar.isHidden = !connected || keyboardPanel?.isHidden == false
        if !connected { functionKeyBar.isHidden = true }
    }

    private func addTouchGamepad() {
        let pad = TouchGamepadView()
        pad.translatesAutoresizingMaskIntoConstraints = false
        pad.onMove = { point in EmulationLog.shared.write(String(format: "Touch stick x=%.2f y=%.2f", point.x, point.y)) }
        pad.onLook = { [weak self] delta in
            guard VRSettings.shared.pointerLockEnabled else { return }
            self?.view.isMultipleTouchEnabled = true
            EmulationLog.shared.write(String(format: "Pointer-look delta %.1f, %.1f", delta.x, delta.y))
        }
        pad.onButton = { key, down in EmulationLog.shared.write("Touch gamepad " + key + ": " + (down ? "down" : "up")) }
        view.addSubview(pad)
        NSLayoutConstraint.activate([
            pad.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            pad.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            pad.topAnchor.constraint(equalTo: view.topAnchor),
            pad.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        gamepad = pad
    }

    private func configureControllerInput() {
        let input = ControllerInputManager.shared
        input.onMove = { x, y in EmulationLog.shared.write(String(format: "Controller move %.2f, %.2f", x, y)) }
        input.onLook = { x, y in
            guard VRSettings.shared.pointerLockEnabled else { return }
            EmulationLog.shared.write(String(format: "Controller look %.2f, %.2f", x, y))
        }
        input.onButton = { key, down in EmulationLog.shared.write("Controller " + key + ": " + (down ? "down" : "up")) }
        input.start()
    }

    private func configureMotionInput() {
        let motion = MotionInputManager.shared
        motion.onOrientation = { [weak self] yaw, pitch, roll in
            DispatchQueue.main.async {
                self?.status.text = String(format: "MOTION • Y %.2f P %.2f R %.2f", yaw, pitch, roll)
            }
        }
        motion.onLookDelta = { yaw, pitch in
            guard VRSettings.shared.pointerLockEnabled else { return }
            EmulationLog.shared.write(String(format: "Motion look Δx=%.4f Δy=%.4f", yaw, pitch))
        }
        if vrSettings.mode == .cardboard { motion.start() }
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        keyboardObservers.forEach { NotificationCenter.default.removeObserver($0) }
        keyboardObservers.removeAll()
        MotionInputManager.shared.stop()
        ControllerInputManager.shared.stop()
        engine.stop()
        virtioGPU.stop()
    }
}
