import Foundation

/// A library entry is metadata only; it does not imply that the executable can run.
struct GameEntry: Codable, Identifiable, Equatable {
    let id: UUID
    var name: String
    var executablePath: String
    var workingDirectory: String
    var launchArguments: [String] = []
    var coverArtPath: String? = nil
    var isFavorite: Bool = false
    var tags: [String] = []
    var lastPlayedAt: Date? = nil
    var addedAt: Date = Date()
    var notes: String? = nil

    init(
        id: UUID = UUID(),
        name: String,
        executablePath: String,
        workingDirectory: String,
        launchArguments: [String] = [],
        coverArtPath: String? = nil,
        isFavorite: Bool = false,
        tags: [String] = [],
        lastPlayedAt: Date? = nil,
        addedAt: Date = Date(),
        notes: String? = nil
    ) {
        self.id = id
        self.name = name
        self.executablePath = executablePath
        self.workingDirectory = workingDirectory
        self.launchArguments = launchArguments
        self.coverArtPath = coverArtPath
        self.isFavorite = isFavorite
        self.tags = tags
        self.lastPlayedAt = lastPlayedAt
        self.addedAt = addedAt
        self.notes = notes
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, executablePath, workingDirectory, launchArguments
        case coverArtPath, isFavorite, tags, lastPlayedAt, addedAt, notes
    }

    /// Backward-compatible decoding for entries created by older i-Steam builds.
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(UUID.self, forKey: .id)
        name = try values.decode(String.self, forKey: .name)
        executablePath = try values.decode(String.self, forKey: .executablePath)
        workingDirectory = try values.decode(String.self, forKey: .workingDirectory)
        launchArguments = try values.decodeIfPresent([String].self, forKey: .launchArguments) ?? []
        coverArtPath = try values.decodeIfPresent(String.self, forKey: .coverArtPath)
        isFavorite = try values.decodeIfPresent(Bool.self, forKey: .isFavorite) ?? false
        tags = try values.decodeIfPresent([String].self, forKey: .tags) ?? []
        lastPlayedAt = try values.decodeIfPresent(Date.self, forKey: .lastPlayedAt)
        addedAt = try values.decodeIfPresent(Date.self, forKey: .addedAt) ?? .distantPast
        notes = try values.decodeIfPresent(String.self, forKey: .notes)
    }
}

final class GameStore {
    static let shared = GameStore()

    private let key = "iSteam.games"
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private init() {}

    var games: [GameEntry] {
        guard
            let data = UserDefaults.standard.data(forKey: key),
            let value = try? decoder.decode([GameEntry].self, from: data)
        else {
            return []
        }
        return value
    }

    func save(_ games: [GameEntry]) {
        guard let data = try? encoder.encode(games) else {
            EmulationLog.shared.write("Game library could not be encoded; existing saved data was left unchanged")
            return
        }
        UserDefaults.standard.set(data, forKey: key)
    }

    func add(_ game: GameEntry) {
        var current = games
        guard !current.contains(where: { $0.id == game.id }) else { return }
        current.append(game)
        save(current)
    }

    func update(_ game: GameEntry) {
        var current = games
        guard let index = current.firstIndex(where: { $0.id == game.id }) else { return }
        current[index] = game
        save(current)
    }

    func remove(id: UUID) {
        save(games.filter { $0.id != id })
    }

    func game(id: UUID) -> GameEntry? {
        games.first { $0.id == id }
    }

    func search(_ query: String, favoritesOnly: Bool = false) -> [GameEntry] {
        let normalized = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return games.filter { game in
            (!favoritesOnly || game.isFavorite) &&
            (normalized.isEmpty ||
             game.name.localizedCaseInsensitiveContains(normalized) ||
             game.tags.contains(where: { $0.localizedCaseInsensitiveContains(normalized) }))
        }.sorted {
            if $0.isFavorite != $1.isFavorite { return $0.isFavorite && !$1.isFavorite }
            return $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }
    }

    func setFavorite(_ favorite: Bool, id: UUID) {
        guard var entry = game(id: id) else { return }
        entry.isFavorite = favorite
        update(entry)
    }

    /// Records a launch attempt; callers must only call this after a backend accepts it.
    func recordLaunchAccepted(id: UUID) {
        guard var entry = game(id: id) else { return }
        entry.lastPlayedAt = Date()
        update(entry)
    }
}
