import Foundation

enum VirtIOGPUCommand {
    case reset
    case updateFramebuffer(Data, width: Int, height: Int)
    case present
}

final class VirtIOGPU {
    private let backend: GPUBackend
    private(set) var frameCount = 0

    init(backend: GPUBackend) {
        self.backend = backend
    }

    func start() {
        backend.start()
    }

    func stop() {
        backend.stop()
    }

    func submit(_ command: VirtIOGPUCommand) {
        switch command {
        case .reset:
            frameCount = 0
        case let .updateFramebuffer(data, width, height):
            backend.submit(frame: data, width: width, height: height)
            frameCount += 1
        case .present:
            break
        }
    }
}
