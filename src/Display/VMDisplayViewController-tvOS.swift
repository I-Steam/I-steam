import UIKit

final class VMDisplayViewController: UIViewController {
    private let engine: VMEngine
    private let gpu: MetalGPUBackend
    private let virtioGPU: VirtIOGPU
    private let status = UILabel()

    init(configuration: VMConfiguration) {
        let resolution = RuntimeSettings.shared.renderResolution
        let backend = MetalGPUBackend(width: resolution.width, height: resolution.height, frameRate: RuntimeSettings.shared.frameRate.value)
        gpu = backend
        virtioGPU = VirtIOGPU(backend: backend)
        engine = VMEngine(configuration: configuration)
        super.init(nibName: nil, bundle: nil)
        title = configuration.name
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        gpu.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(gpu.view)
        status.translatesAutoresizingMaskIntoConstraints = false
        status.text = "VM preview • \(RuntimeSettings.shared.frameRate.value) FPS target • Metal"
        status.textColor = .white
        status.backgroundColor = .black
        status.textAlignment = .center
        status.font = .systemFont(ofSize: 24, weight: .medium)
        view.addSubview(status)
        NSLayoutConstraint.activate([
            gpu.view.topAnchor.constraint(equalTo: view.topAnchor),
            gpu.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            gpu.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            gpu.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            status.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            status.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            status.heightAnchor.constraint(equalToConstant: 44)
        ])
        virtioGPU.start()
        engine.start()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        engine.stop()
        virtioGPU.stop()
    }
}
