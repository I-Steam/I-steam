import QuartzCore
import UIKit

final class FramePacer {
    static let shared = FramePacer()
    private(set) var currentFPS: Double = 0
    private var link: CADisplayLink?
    private var lastTimestamp: CFTimeInterval = 0
    private var frames = 0
    private init() {}

    func start() {
        stop()
        lastTimestamp = 0
        frames = 0
        let display = CADisplayLink(target: self, selector: #selector(tick(_:)))
        let maximum = max(1, UIScreen.main.maximumFramesPerSecond)
        let target = min(max(24, RuntimeSettings.shared.frameRate.value), maximum)
        if #available(iOS 15.0, *) {
            display.preferredFrameRateRange = CAFrameRateRange(
                minimum: Float(min(24, maximum)),
                maximum: Float(maximum),
                preferred: Float(target)
            )
        } else {
            display.preferredFramesPerSecond = target
        }
        link = display
        display.add(to: .main, forMode: .common)
    }

    func stop() {
        link?.invalidate()
        link = nil
        lastTimestamp = 0
        frames = 0
    }

    @objc private func tick(_ display: CADisplayLink) {
        frames += 1
        guard lastTimestamp != 0 else { lastTimestamp = display.timestamp; return }
        let elapsed = display.timestamp - lastTimestamp
        guard elapsed >= 0.5 else { return }
        currentFPS = Double(frames) / elapsed
        frames = 0
        lastTimestamp = display.timestamp
    }
}