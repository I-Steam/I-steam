import UIKit
import UniformTypeIdentifiers

final class LibraryViewController: UITableViewController, UIDocumentPickerDelegate {
    private var games: [GameEntry] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "iSteam"
        games = GameStore.shared.games

        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .add,
            target: self,
            action: #selector(importGame)
        )

        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "GameCell")
        tableView.rowHeight = 58
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        games = GameStore.shared.games
        tableView.reloadData()
    }

    @objc private func importGame() {
        let picker = UIDocumentPickerViewController(
            forOpeningContentTypes: [.data, .item],
            asCopy: true
        )
        picker.delegate = self
        picker.allowsMultipleSelection = false
        present(picker, animated: true)
    }

    func documentPicker(
        _ controller: UIDocumentPickerViewController,
        didPickDocumentsAt urls: [URL]
    ) {
        guard let source = urls.first else { return }

        do {
            try ELFValidator.validate(url: source)

            let fileManager = FileManager.default
            let appSupport = fileManager.urls(
                for: .applicationSupportDirectory,
                in: .userDomainMask
            )[0]
            let gamesDirectory = appSupport.appendingPathComponent("Games", isDirectory: true)

            try fileManager.createDirectory(
                at: gamesDirectory,
                withIntermediateDirectories: true
            )

            let id = UUID()
            let destinationDirectory = gamesDirectory.appendingPathComponent(
                id.uuidString,
                isDirectory: true
            )
            try fileManager.createDirectory(
                at: destinationDirectory,
                withIntermediateDirectories: true
            )

            let destination = destinationDirectory.appendingPathComponent(
                source.lastPathComponent
            )
            try fileManager.copyItem(at: source, to: destination)

            let game = GameEntry(
                id: id,
                name: source.deletingPathExtension().lastPathComponent,
                executablePath: destination.path,
                workingDirectory: destinationDirectory.path
            )

            GameStore.shared.add(game)
            games = GameStore.shared.games
            tableView.reloadData()
        } catch {
            let alert = UIAlertController(
                title: "Import failed",
                message: error.localizedDescription,
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
        }
    }

    override func tableView(
        _ tableView: UITableView,
        numberOfRowsInSection section: Int
    ) -> Int {
        games.count
    }

    override func tableView(
        _ tableView: UITableView,
        cellForRowAt indexPath: IndexPath
    ) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(
            withIdentifier: "GameCell",
            for: indexPath
        )

        var content = cell.defaultContentConfiguration()
        content.text = games[indexPath.row].name
        content.secondaryText = "x86-64 Linux executable"
        cell.contentConfiguration = content
        cell.accessoryType = .disclosureIndicator
        return cell
    }

    override func tableView(
        _ tableView: UITableView,
        didSelectRowAt indexPath: IndexPath
    ) {
        tableView.deselectRow(at: indexPath, animated: true)

        navigationController?.pushViewController(
            ConsoleViewController(game: games[indexPath.row]),
            animated: true
        )
    }

    override func tableView(
        _ tableView: UITableView,
        commit editingStyle: UITableViewCell.EditingStyle,
        forRowAt indexPath: IndexPath
    ) {
        guard editingStyle == .delete else { return }

        let game = games[indexPath.row]
        try? FileManager.default.removeItem(atPath: game.executablePath)

        GameStore.shared.remove(id: game.id)
        games = GameStore.shared.games
        tableView.deleteRows(at: [indexPath], with: .automatic)
    }
}
