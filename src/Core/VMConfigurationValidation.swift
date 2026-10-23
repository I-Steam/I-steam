import Foundation

/// Validates resource requests before the engine allocates guest RAM or prepares
/// a native backend. These limits are safety bounds, not a promise that the
/// host device can sustain the requested configuration.
extension VMConfiguration {
    enum ValidationError: LocalizedError, Equatable {
        case emptyName
        case memoryOutOfRange(Int)
        case cpuCountOutOfRange(Int)
        case invalidResolution(width: Int, height: Int)
        case invalidFrameRate(Int)

        var errorDescription: String? {
            switch self {
            case .emptyName:
                return "Give this VM a name before starting it."
            case .memoryOutOfRange(let value):
                return "VM memory must be between 256 MB and 16384 MB (requested: \(value) MB)."
            case .cpuCountOutOfRange(let value):
                return "The virtual CPU count must be between 1 and 16 (requested: \(value))."
            case .invalidResolution(let width, let height):
                return "Display dimensions must be between 320×240 and 8192×8192 (requested: \(width)×\(height))."
            case .invalidFrameRate(let value):
                return "The target frame rate must be between 24 and 120 FPS (requested: \(value))."
            }
        }
    }

    func validateForStart() throws {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ValidationError.emptyName
        }
        guard (256...16384).contains(memoryMB) else {
            throw ValidationError.memoryOutOfRange(memoryMB)
        }
        guard (1...16).contains(cpuCount) else {
            throw ValidationError.cpuCountOutOfRange(cpuCount)
        }
        guard (320...8192).contains(displayWidth),
              (240...8192).contains(displayHeight) else {
            throw ValidationError.invalidResolution(width: displayWidth, height: displayHeight)
        }
        guard (24...120).contains(displayFPS) else {
            throw ValidationError.invalidFrameRate(displayFPS)
        }
    }
}
