import UIKit

final class VMDisplayViewController: UIViewController {
    private let gpu: MetalGPUBackend
    private let virtioGPU: VirtIOGPU
    private let engine: VMEngine
    private let status = UILabel()
    private var gamepad: TouchGamepadView?
    private let vrSettings = VRSettings.shared

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
        if vrSettings.touchGamepadEnabled { addTouchGamepad() }
        configureControllerInput()
        configureMotionInput()
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

    private func addTouchGamepad() {
        let pad = TouchGamepadView()
        pad.translatesAutoresizingMaskIntoConstraints = false
        pad.onMove = { point in EmulationLog.shared.write(String(format: "Touch stick x=%.2f y=%.2f", point.x, point.y)) }
        pad.onLook = { [weak self] delta in
            guard VRSettings.shared.pointerLockEnabled else { return }
            self?.view.isMultipleTouchEnabled = true
            EmulationLog.shared.write(String(format: "Pointer-look delta %.1f, %.1f", delta.x, delta.y))
        }
        pad.onButton = { key, down in EmulationLog.shared.write("Touch gamepad \(key): \(down ? "down" : "up")") }
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
        input.onButton = { key, down in EmulationLog.shared.write("Controller \(key): \(down ? "down" : "up")") }
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
        MotionInputManager.shared.stop()
        ControllerInputManager.shared.stop()
        engine.stop()
        virtioGPU.stop()
    }
}
