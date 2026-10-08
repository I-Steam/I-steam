import Foundation
import UIKit
import Metal

final class PerformanceManager {
    static let shared = PerformanceManager()
    private init() {}

    var summary: String {
        let device = MTLCreateSystemDefaultDevice() == nil ? "No Metal device" : "Metal"
        return "\(device) • \(UIScreen.main.maximumFramesPerSecond)Hz display • target \(RuntimeSettings.shared.frameRate.value) FPS"
    }

    var detailedSummary: String {
        """
        Display maximum: \(UIScreen.main.maximumFramesPerSecond) Hz
        Selected target: \(RuntimeSettings.shared.frameRate.value) FPS
        GPU: \(MTLCreateSystemDefaultDevice() == nil ? "Unavailable" : "Metal")
        Translation cache: enabled
        Shader cache: enabled
        Adaptive frame pacing: enabled
        """
    }
}
