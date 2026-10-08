import Foundation
import Metal
import MetalKit

final class MetalGPUBackend: NSObject, GPUBackend {
    let name = "VirtIO GPU → Metal"
    let isHardwareAccelerated = MTLCreateSystemDefaultDevice() != nil
    let width: Int
    let height: Int
    let view: MTKView

    private let queue: MTLCommandQueue?
    private var texture: MTLTexture?
    private let targetFrameRate: Int

    init(width: Int, height: Int, frameRate: Int) {
        self.width = width
        self.height = height
        self.targetFrameRate = frameRate
        let device = MTLCreateSystemDefaultDevice()
        self.view = MTKView(frame: .zero, device: device)
        self.queue = device?.makeCommandQueue()
        super.init()

        view.colorPixelFormat = .bgra8Unorm
        view.framebufferOnly = true
        view.enableSetNeedsDisplay = true
        view.isPaused = true
        view.preferredFramesPerSecond = min(frameRate, UIScreen.main.maximumFramesPerSecond)
        
        if let device {
            let descriptor = MTLTextureDescriptor.texture2DDescriptor(
                pixelFormat: .bgra8Unorm,
                width: width,
                height: height,
                mipmapped: false
            )
            descriptor.usage = [.shaderRead, .shaderWrite]
            texture = device.makeTexture(descriptor: descriptor)
        }
    }

    func start() {
        submit(frame: Self.testPattern(width: width, height: height), width: width, height: height)
    }

    func stop() {}

    func submit(frame: Data, width: Int, height: Int) {
        guard width == self.width, height == self.height, let texture else { return }
        guard frame.count >= width * height * 4 else { return }

        frame.withUnsafeBytes { raw in
            guard let base = raw.baseAddress else { return }
            texture.replace(
                region: MTLRegionMake2D(0, 0, width, height),
                mipmapLevel: 0,
                withBytes: base,
                bytesPerRow: width * 4
            )
        }

        DispatchQueue.main.async { [weak self] in
            self?.view.setNeedsDisplay()
        }
    }

    private static func testPattern(width: Int, height: Int) -> Data {
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        for y in 0..<height {
            for x in 0..<width {
                let i = (y * width + x) * 4
                bytes[i] = UInt8((x * 255) / max(width - 1, 1))
                bytes[i + 1] = UInt8((y * 255) / max(height - 1, 1))
                bytes[i + 2] = 40
                bytes[i + 3] = 255
            }
        }
        return Data(bytes)
    }
}

extension MetalGPUBackend: MTKViewDelegate {
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

    func draw(in view: MTKView) {
        guard let drawable = view.currentDrawable,
              let commandBuffer = queue?.makeCommandBuffer(),
              let source = texture else { return }

        let blit = commandBuffer.makeBlitCommandEncoder()
        let w = min(source.width, drawable.texture.width)
        let h = min(source.height, drawable.texture.height)
        blit?.copy(
            from: source,
            sourceSlice: 0,
            sourceLevel: 0,
            sourceOrigin: MTLOrigin(x: 0, y: 0, z: 0),
            sourceSize: MTLSize(width: w, height: h, depth: 1),
            to: drawable.texture,
            destinationSlice: 0,
            destinationLevel: 0,
            destinationOrigin: MTLOrigin(x: 0, y: 0, z: 0)
        )
        blit?.endEncoding()
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
}
