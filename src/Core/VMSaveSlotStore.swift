import Foundation

/// Persists named VM configuration slots and session metadata in Application Support.
/// A real game-state save still depends on a running guest and writable virtual disk.
final class VMSaveSlotStore {
    static let shared = VMSaveSlotStore()
    private let fm = FileManager.default
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private var directory: URL {
        let root = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let url = root.appendingPathComponent("VMSlots", isDirectory: true)
        try? fm.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private init() {
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    }

    private func safeFilename(_ name: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_ "))
        let clean = String(name.unicodeScalars.filter { allowed.contains($0) }).trimmingCharacters(in: .whitespacesAndNewlines)
        return String((clean.isEmpty ? "VM" : clean).prefix(64))
    }

    func saveConfiguration(_ configuration: VMConfiguration, name: String) throws {
        var saved = configuration
        saved.name = name
        let url = directory.appendingPathComponent(safeFilename(name) + ".json")
        try encoder.encode(saved).write(to: url, options: .atomic)
    }

    func configuration(named name: String) -> VMConfiguration? {
        let url = directory.appendingPathComponent(safeFilename(name) + ".json")
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? decoder.decode(VMConfiguration.self, from: data)
    }

    var configurationNames: [String] {
        let urls = (try? fm.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
        return urls.filter { $0.pathExtension == "json" }.map { $0.deletingPathExtension().lastPathComponent }.sorted()
    }

    func saveSessionMetadata(configuration: VMConfiguration, gameID: UUID? = nil) throws {
        struct Session: Codable {
            let configurationID: UUID
            let configurationName: String
            let gameID: UUID?
            let savedAt: Date
        }
        let session = Session(configurationID: configuration.id, configurationName: configuration.name, gameID: gameID, savedAt: Date())
        try encoder.encode(session).write(to: directory.appendingPathComponent("last-session.json"), options: .atomic)
    }
}
