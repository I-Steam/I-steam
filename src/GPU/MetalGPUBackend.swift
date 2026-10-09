import Foundation
import UIKit
import Metal
import MetalKit

/// Presents validated BGRA/RGBA-sized frames on Metal.
/// Until a guest framebuffer is connected, the view clears to a stable dark screen
/// instead of drawing a synthetic test pattern that can look like corrupted guest output.
final class MetalGPUBackend: NSObject, GPUBackend {
    let name = "VirtIO GPU • Metal"
    let isHardwareAccelerated = MTLCreateSystemDefaultDevice() != nil
    let width: Int
    let height: Int
    let view: MTKView

    private let device: MTLDevice?
    private let queue: MTLCommandQueue?
    private let textureLock = NSLock()
    /// Submitted textures are immutable after publication, so an in-flight GPU blit
    /// cannot race a CPU write to the same texture.
    private var framebuffer: MTLTexture?
    private let targetFrameRate: Int

    init(width: Int, height: Int, frameRate: Int) {
        self.width = max(1, width)
        self.height = max(1, height)
        self.targetFrameRate = max(1, frameRate)
        device = MTLCreateSystemDefaultDevice()
        queue = device?.makeCommandQueue()
        view = MTKView(frame: .zero, device: device)
        super.init()
        view.colorPixelFormat = .bgra8Unorm
        view.framebufferOnly = true
        view.enableSetNeedsDisplay = true
        view.isPaused = true
        view.clearColor = MTLClearColor(red: 0.025, green: 0.03, blue: 0.045, alpha: 1)
        view.preferredFramesPerSecond = min(self.targetFrameRate, UIScreen.main.maximumFramesPerSecond)
        view.delegate = self
    }

    func start() {
        // Do not synthesize a large CPU-generated test frame on the UI thread.
        // The display stays clean until a real framebuffer is submitted.
        DispatchQueue.main.async { [weak self] in
            self?.view.setNeedsDisplay()
        }
    }

    func stop() {
        textureLock.lock()
        framebuffer = nil
        textureLock.unlock()
        DispatchQueue.main.async { [weak self] in
            self?.view.setNeedsDisplay()
        }
    }

    func submit(frame: Data, width frameWidth: Int, height frameHeight: Int) {
        guard frameWidth > 0, frameHeight > 0,
              frameWidth <= 8192, frameHeight <= 8192,
              frameWidth <= Int.max / frameHeight / 4,
              frame.count >= frameWidth * frameHeight * 4,
              let device,
              let queue,
              let commandTexture = makeTexture(device: device, width: frameWidth, height: frameHeight)
        else {
            EmulationLog.shared.write("Metal framebuffer ignored: invalid dimensions or byte count")
            return
        }

        // Upload into a fresh texture, then publish it. Never mutate a texture that
        // a previously submitted GPU command might still be reading.
        frame.withUnsafeBytes { raw in
            guard let base = raw.baseAddress else { return }
            commandTexture.replace(
                region: MTLRegionMake2D(0, 0, frameWidth, frameHeight),
                mipmapLevel: 0,
                withBytes: base,
                bytesPerRow: frameWidth * 4
            )
        }

        textureLock.lock()
        framebuffer = commandTexture
        textureLock.unlock()

        DispatchQueue.main.async { [weak self] in
            self?.view.setNeedsDisplay()
        }
        _ = queue // The queue is used by the view delegate for presentation.
    }

    private func makeTexture(device: MTLDevice, width: Int, height: Int) -> MTLTexture? {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .bgra8Unorm,
            width: width,
            height: height,
            mipmapped: false
        )
        descriptor.storageMode = .shared
        descriptor.usage = [.shaderRead]
        return device.makeTexture(descriptor: descriptor)
    }
}

extension MetalGPUBackend: MTKViewDelegate {
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

    func draw(in view: MTKView) {
        guard let queue, let commandBuffer = queue.makeCommandBuffer(),
              let drawable = view.currentDrawable,
              let pass = view.currentRenderPassDescriptor else { return }

        textureLock.lock()
        let source = framebuffer
        textureLock.unlock()

        if let source {
            guard let blit = commandBuffer.makeBlitCommandEncoder() else { return }
            let copyWidth = min(source.width, drawable.texture.width)
            let copyHeight = min(source.height, drawable.texture.height)
            guard copyWidth > 0, copyHeight > 0 else {
                blit.endEncoding()
                return
            }
            blit.copy(
                from: source,
                sourceSlice: 0,
                sourceLevel: 0,
                sourceOrigin: MTLOrigin(x: 0, y: 0, z: 0),
                sourceSize: MTLSize(width: copyWidth, height: copyHeight, depth: 1),
                to: drawable.texture,
                destinationSlice: 0,
                destinationLevel: 0,
                destinationOrigin: MTLOrigin(x: 0, y: 0, z: 0)
            )
            blit.endEncoding()
        } else {
            // A clear-only render pass produces a stable placeholder, not fake VM output.
            pass.colorAttachments[0].loadAction = .clear
            pass.colorAttachments[0].storeAction = .store
            pass.colorAttachments[0].clearColor = MTLClearColor(red: 0.025, green: 0.03, blue: 0.045, alpha: 1)
            guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: pass) else { return }
            encoder.endEncoding()
        }

        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
}
