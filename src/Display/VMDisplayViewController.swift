import UIKit

final class VMDisplayViewController: UIViewController {
    private let gpu: MetalGPUBackend
    private let virtioGPU: VirtIOGPU
    private let engine: VMEngine
    private let status = UILabel()

    init(configuration: VMConfiguration) {
        let backend = MetalGPUBackend(width: configuration.displayWidth, height: configuration.displayHeight)
        self.gpu = backend
        self.virtioGPU = VirtIOGPU(backend: backend)
        self.engine = VMEngine(configuration: configuration)
        super.init(nibName: nil, bundle: nil)
        title = configuration.name
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black

        gpu.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(gpu.view)

        status.translatesAutoresizingMaskIntoConstraints = false
        status.textColor = .white
        status.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        status.font = .monospacedSystemFont(ofSize: 12, weight: .medium)
        status.text = "VirtIO GPU • Metal"
        status.textAlignment = .center
        status.layer.cornerRadius = 8
        status.clipsToBounds = true
        view.addSubview(status)

        NSLayoutConstraint.activate([
            gpu.view.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            gpu.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            gpu.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            gpu.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            status.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 10),
            status.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 10),
            status.widthAnchor.constraint(greaterThanOrEqualToConstant: 150),
            status.heightAnchor.constraint(equalToConstant: 30)
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
