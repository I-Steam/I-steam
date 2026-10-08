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
        link = CADisplayLink(target: self, selector: #selector(tick(_:)))
        if #available(iOS 15.0, *) {
            let maxRate = UIScreen.main.maximumFramesPerSecond
            let requested = min(RuntimeSettings.shared.frameRate.value, maxRate)
            link?.preferredFrameRateRange = CAFrameRateRange(
                minimum: Float(min(24, maxRate)),
                maximum: Float(maxRate),
                preferred: Float(requested)
            )
        } else {
            link?.preferredFramesPerSecond = min(RuntimeSettings.shared.frameRate.value, 60)
        }
        link?.add(to: .main, forMode: .common)
    }

    func stop() {
        link?.invalidate()
        link = nil
    }

    @objc private func tick(_ link: CADisplayLink) {
        frames += 1
        guard lastTimestamp != 0 else {
            lastTimestamp = link.timestamp
            return
        }
        let elapsed = link.timestamp - lastTimestamp
        guard elapsed >= 0.5 else { return }
        currentFPS = Double(frames) / elapsed
        frames = 0
        lastTimestamp = link.timestamp
    }
}
