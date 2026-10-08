import Foundation
import CoreMotion

final class MotionInputManager {
    static let shared = MotionInputManager()
    private let motion = CMMotionManager()
    private let queue: OperationQueue = {
        let queue = OperationQueue()
        queue.name = "iSteam.MotionInput"
        queue.qualityOfService = .userInteractive
        return queue
    }()
    private init() {}

    var isAvailable: Bool { motion.isDeviceMotionAvailable }
    var isRunning: Bool { motion.isDeviceMotionActive }
    var sensitivity: Double {
        get {
            let stored = UserDefaults.standard.double(forKey: "iSteam.motionSensitivity")
            return stored > 0 ? min(stored, 5) : 1
        }
        set {
            UserDefaults.standard.set(min(max(newValue, 0.1), 5), forKey: "iSteam.motionSensitivity")
        }
    }
    var onOrientation: ((Double, Double, Double) -> Void)?
    var onLookDelta: ((Double, Double) -> Void)?
    private var previousYaw: Double?
    private var previousPitch: Double?

    func start() {
        guard motion.isDeviceMotionAvailable, !motion.isDeviceMotionActive else { return }
        motion.deviceMotionUpdateInterval = 1.0 / 60.0
        previousYaw = nil
        previousPitch = nil
        motion.startDeviceMotionUpdates(using: .xArbitraryCorrectedZVertical, to: queue) { [weak self] data, error in
            guard error == nil, let self, let data else { return }
            let yaw = data.attitude.yaw
            let pitch = data.attitude.pitch
            let roll = data.attitude.roll
            self.onOrientation?(yaw, pitch, roll)
            if let oldYaw = self.previousYaw, let oldPitch = self.previousPitch {
                var deltaYaw = yaw - oldYaw
                if deltaYaw > .pi { deltaYaw -= 2 * .pi }
                if deltaYaw < -.pi { deltaYaw += 2 * .pi }
                self.onLookDelta?(deltaYaw * self.sensitivity, (pitch - oldPitch) * self.sensitivity)
            }
            self.previousYaw = yaw
            self.previousPitch = pitch
        }
    }

    func stop() {
        motion.stopDeviceMotionUpdates()
        previousYaw = nil
        previousPitch = nil
    }

    func recenter() {
        previousYaw = nil
        previousPitch = nil
    }
}
