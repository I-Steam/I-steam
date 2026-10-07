import Foundation

struct GameEntry: Codable, Identifiable, Equatable {
    let id: UUID
    var name: String
    var executablePath: String
    var workingDirectory: String
}

final class GameStore {
    static let shared = GameStore()

    private let key = "iSteam.games"

    private init() {}

    var games: [GameEntry] {
        guard
            let data = UserDefaults.standard.data(forKey: key),
            let value = try? JSONDecoder().decode([GameEntry].self, from: data)
        else {
            return []
        }
        return value
    }

    func save(_ games: [GameEntry]) {
        if let data = try? JSONEncoder().encode(games) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    func add(_ game: GameEntry) {
        var current = games
        current.append(game)
        save(current)
    }

    func remove(id: UUID) {
        save(games.filter { $0.id != id })
    }
}
