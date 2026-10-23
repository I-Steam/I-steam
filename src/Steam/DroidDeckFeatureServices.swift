import Foundation

/// Portable library backup format. Executable paths are metadata only: importing
/// a backup never executes a file or grants access to the original path.
struct GameLibraryBackup: Codable {
    let schemaVersion: Int
    let exportedAt: Date
    let games: [GameEntry]
    let profiles: [GameRuntimeProfile]

    init(games: [GameEntry], profiles: [GameRuntimeProfile], exportedAt: Date = Date()) {
        self.schemaVersion = 1
        self.exportedAt = exportedAt
        self.games = games
        self.profiles = profiles
    }
}

/// Import/export service for DroidDeck-style library management. The backup is
/// atomically written, validated before merge, and never overwrites existing
/// entries with the same UUID.
final class GameLibraryTransferStore {
    static let shared = GameLibraryTransferStore()
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private init() {
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    func export(to destination: URL) throws {
        let backup = GameLibraryBackup(
            games: GameStore.shared.games,
            profiles: GameRuntimeProfileStore.shared.allProfiles
        )
        try encoder.encode(backup).write(to: destination, options: .atomic)
        EmulationLog.shared.write("Exported game library backup (\(backup.games.count) entries)")
    }

    @discardableResult
    func importBackup(from source: URL) throws -> Int {
        let data = try Data(contentsOf: source)
        guard data.count <= 20 * 1024 * 1024 else {
            throw TransferError.backupTooLarge
        }
        let backup = try decoder.decode(GameLibraryBackup.self, from: data)
        guard backup.schemaVersion == 1 else {
            throw TransferError.unsupportedVersion(backup.schemaVersion)
        }
        guard backup.games.count <= 10_000, backup.profiles.count <= 10_000 else {
            throw TransferError.tooManyEntries
        }

        var seen = Set<UUID>()
        for game in backup.games {
            guard !game.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  !game.name.contains("\0"),
                  !game.executablePath.contains("\0"),
                  !game.workingDirectory.contains("\0"),
                  seen.insert(game.id).inserted else {
                throw TransferError.invalidEntry
            }
        }
        var profileGameIDs = Set<UUID>()
        let validGameIDs = Set(GameStore.shared.games.map(\.id)).union(seen)
        for profile in backup.profiles {
            try profile.validate()
            guard validGameIDs.contains(profile.gameID),
                  profileGameIDs.insert(profile.gameID).inserted else {
                throw TransferError.invalidProfile
            }
            guard profile.launchArguments.count <= 256,
                  profile.launchArguments.allSatisfy({ $0.utf8.count <= 4096 && !$0.contains("\0") }),
                  profile.environment.count <= 128,
                  profile.compatibilityNotes.utf8.count <= 16_384 else {
                throw TransferError.invalidProfile
            }
        }

        var current = GameStore.shared.games
        let existingIDs = Set(current.map(\.id))
        let incoming = backup.games.filter { !existingIDs.contains($0.id) }
        current.append(contentsOf: incoming)
        GameStore.shared.save(current)

        for profile in backup.profiles where GameRuntimeProfileStore.shared.profile(for: profile.gameID) == nil {
            try GameRuntimeProfileStore.shared.save(profile)
        }
        EmulationLog.shared.write("Imported \(incoming.count) new game entries; executable paths remain untrusted metadata")
        return incoming.count
    }

    enum TransferError: LocalizedError {
        case backupTooLarge
        case unsupportedVersion(Int)
        case tooManyEntries
        case invalidEntry
        case invalidProfile

        var errorDescription: String? {
            switch self {
            case .backupTooLarge:
                return "The library backup is larger than the 20 MB safety limit."
            case .unsupportedVersion(let version):
                return "Library backup version \(version) is not supported."
            case .tooManyEntries:
                return "The backup contains too many entries."
            case .invalidEntry:
                return "The backup contains an invalid or duplicate game entry."
            case .invalidProfile:
                return "The backup contains an invalid, duplicate, or orphaned game profile."
            }
        }
    }
}

/// Per-game profile defaults derived from the global settings. Callers can save
/// this profile and edit it per title; these values are preferences until a
/// compatible runtime backend consumes them.
enum GameRuntimeProfileFactory {
    static func makeDefault(for game: GameEntry) -> GameRuntimeProfile {
        let resolution = RuntimeSettings.shared.resolution
        return GameRuntimeProfile(
            gameID: game.id,
            displayName: game.name,
            launchArguments: game.launchArguments,
            preferredResolutionWidth: resolution.width,
            preferredResolutionHeight: resolution.height,
            targetFPS: RuntimeSettings.shared.frameRate.value,
            controllerEnabled: true,
            showOnScreenControls: VRSettings.shared.touchGamepadEnabled
        )
    }
}

/// Explicit feature readiness prevents UI settings from implying that a native
/// runtime component exists. Update readiness only when its implementation and
/// target-device tests are present.
enum DroidDeckPortFeature: String, CaseIterable {
    case libraryManagement
    case perGameProfiles
    case libraryBackup
    case documentPickerImport
    case controllerInput
    case touchGamepad
    case performanceTargets
    case externalStorageBookmarks
    case linuxDesktop
    case flatpakAndAppImage
    case windowsProton
    case fexTranslation
    case turnipVulkan
    case frameGeneration
    case steamVR
    case glassesPoseTracking
    case rawUSBBlockDevices
    case fullSystemQEMU

    enum Readiness: String {
        case implemented
        case partial
        case unavailable
    }

    var readiness: Readiness {
        switch self {
        case .libraryManagement, .perGameProfiles, .libraryBackup,
             .documentPickerImport, .controllerInput, .touchGamepad,
             .performanceTargets, .externalStorageBookmarks:
            return .partial
        case .linuxDesktop, .flatpakAndAppImage, .windowsProton, .fexTranslation,
             .turnipVulkan, .frameGeneration, .steamVR, .glassesPoseTracking,
             .rawUSBBlockDevices, .fullSystemQEMU:
            return .unavailable
        }
    }

    var explanation: String {
        switch self {
        case .libraryManagement:
            return "Local library metadata and favourites are stored; this does not guarantee execution."
        case .perGameProfiles:
            return "Per-game launch and performance preferences can be persisted; runtime consumption is incomplete."
        case .libraryBackup:
            return "Versioned JSON export/import is available; imported executable paths are not trusted or reconnected."
        case .documentPickerImport:
            return "Files-provider import copies selected files into app storage."
        case .controllerInput:
            return "GameController input callbacks exist; mapping to guest devices is incomplete."
        case .touchGamepad:
            return "Touch controls are a host UI prototype and are not a complete guest input device."
        case .performanceTargets:
            return "Resolution/FPS targets and diagnostics exist; actual guest rendering may not honor them."
        case .externalStorageBookmarks:
            return "Security-scoped file access and bookmarks exist; raw USB block-device passthrough does not."
        case .linuxDesktop:
            return "No bootable Linux guest desktop is integrated."
        case .flatpakAndAppImage:
            return "Requires a working Linux guest and package-manager integration."
        case .windowsProton:
            return "Wine/Proton and a Windows compatibility runtime are not integrated."
        case .fexTranslation:
            return "Android FEX binaries and runtime are not an iOS-compatible drop-in."
        case .turnipVulkan:
            return "Turnip is an Android/Linux Vulkan driver; it is not an iOS Metal backend."
        case .frameGeneration:
            return "No compatible guest frame-generation pipeline is integrated."
        case .steamVR:
            return "SteamVR runtime and tracking integration are not available."
        case .glassesPoseTracking:
            return "Vendor-specific glasses and pose tracking require separate native integrations and device tests."
        case .rawUSBBlockDevices:
            return "iOS Files access cannot expose a physical USB disk as a guest block device."
        case .fullSystemQEMU:
            return QEMURuntimeStatus.diagnostic
        }
    }
}
