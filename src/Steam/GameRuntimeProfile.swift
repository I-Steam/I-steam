import Foundation

/// Portable per-game settings inspired by DroidDeck's game profiles.
/// These settings are metadata until a compatible guest runtime consumes them.
struct GameRuntimeProfile: Codable, Equatable, Identifiable {
    let id: UUID
    var gameID: UUID
    var displayName: String
    var launchArguments: [String]
    var environment: [String: String]
    var preferredResolutionWidth: Int
    var preferredResolutionHeight: Int
    var targetFPS: Int
    var memoryMB: Int
    var cpuCount: Int
    var controllerEnabled: Bool
    var showOnScreenControls: Bool
    var compatibilityNotes: String
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        gameID: UUID,
        displayName: String,
        launchArguments: [String] = [],
        environment: [String: String] = [:],
        preferredResolutionWidth: Int = 1280,
        preferredResolutionHeight: Int = 720,
        targetFPS: Int = 60,
        memoryMB: Int = 4096,
        cpuCount: Int = 4,
        controllerEnabled: Bool = true,
        showOnScreenControls: Bool = false,
        compatibilityNotes: String = "",
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.gameID = gameID
        self.displayName = displayName
        self.launchArguments = launchArguments
        self.environment = environment
        self.preferredResolutionWidth = preferredResolutionWidth
        self.preferredResolutionHeight = preferredResolutionHeight
        self.targetFPS = targetFPS
        self.memoryMB = memoryMB
        self.cpuCount = cpuCount
        self.controllerEnabled = controllerEnabled
        self.showOnScreenControls = showOnScreenControls
        self.compatibilityNotes = compatibilityNotes
        self.updatedAt = updatedAt
    }

    func validate() throws {
        guard !displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ProfileError.invalidName
        }
        guard (320...8192).contains(preferredResolutionWidth),
              (240...8192).contains(preferredResolutionHeight) else {
            throw ProfileError.invalidResolution
        }
        guard (24...120).contains(targetFPS) else { throw ProfileError.invalidFrameRate }
        guard (256...16384).contains(memoryMB) else { throw ProfileError.invalidMemory }
        guard (1...16).contains(cpuCount) else { throw ProfileError.invalidCPUCount }
        guard environment.keys.allSatisfy({ !$0.isEmpty && !$0.contains("=") && !$0.contains("\0") }),
              environment.values.allSatisfy({ !$0.contains("\0") }) else {
            throw ProfileError.invalidEnvironment
        }
    }

    enum ProfileError: LocalizedError {
        case invalidName, invalidResolution, invalidFrameRate, invalidMemory, invalidCPUCount, invalidEnvironment
        var errorDescription: String? {
            switch self {
            case .invalidName: return "A game profile needs a name."
            case .invalidResolution: return "Resolution must be between 320×240 and 8192×8192."
            case .invalidFrameRate: return "Target FPS must be between 24 and 120."
            case .invalidMemory: return "Profile memory must be between 256 MB and 16384 MB."
            case .invalidCPUCount: return "Profile CPU count must be between 1 and 16."
            case .invalidEnvironment: return "Environment variable names or values contain invalid characters."
            }
        }
    }
}

/// Atomic, app-sandboxed profile storage. Environment variables are stored as
/// data only; they are never evaluated as shell code.
final class GameRuntimeProfileStore {
    static let shared = GameRuntimeProfileStore()
    private let fm = FileManager.default
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private var directory: URL {
        let base = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let url = base.appendingPathComponent("GameProfiles", isDirectory: true)
        try? fm.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private init() {
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    }

    private func url(for id: UUID) -> URL {
        directory.appendingPathComponent(id.uuidString).appendingPathExtension("json")
    }

    func save(_ profile: GameRuntimeProfile) throws {
        try profile.validate()
        var value = profile
        value.updatedAt = Date()
        try encoder.encode(value).write(to: url(for: value.gameID), options: .atomic)
        EmulationLog.shared.write("Saved runtime profile for \(value.displayName)")
    }

    func profile(for gameID: UUID) -> GameRuntimeProfile? {
        guard let data = try? Data(contentsOf: url(for: gameID)),
              let value = try? decoder.decode(GameRuntimeProfile.self, from: data) else { return nil }
        return value
    }

    func removeProfile(for gameID: UUID) throws {
        let file = url(for: gameID)
        if fm.fileExists(atPath: file.path) { try fm.removeItem(at: file) }
    }

    var allProfiles: [GameRuntimeProfile] {
        let files = (try? fm.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
        return files.filter { $0.pathExtension == "json" }.compactMap { file in
            guard let data = try? Data(contentsOf: file) else { return nil }
            return try? decoder.decode(GameRuntimeProfile.self, from: data)
        }.sorted { $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending }
    }
}
