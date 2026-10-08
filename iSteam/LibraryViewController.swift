import UIKit
import UniformTypeIdentifiers

final class LibraryViewController: UITableViewController, UIDocumentPickerDelegate {
    private var games: [GameEntry] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "iSteam"
        games = GameStore.shared.games

        navigationItem.rightBarButtonItems = [
            UIBarButtonItem(title: "Settings", style: .plain, target: self, action: #selector(openSettings)),
            UIBarButtonItem(title: "VM", style: .plain, target: self, action: #selector(openVM)),
            UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(importGame))
        ]

        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "GameCell")
        tableView.rowHeight = 58
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        games = GameStore.shared.games
        tableView.reloadData()
    }

    @objc private func openSettings() {
        navigationController?.pushViewController(SettingsViewController(), animated: true)
    }

    @objc private func openVM() {
        navigationController?.pushViewController(
            VMDisplayViewController(configuration: .defaultWindows),
            animated: true
        )
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

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let source = urls.first else { return }

        do {
            let formatResult = GuestProcessManager.shared.inspect(source)
            guard case let .success(format) = formatResult,
                  format == .windowsPE || format == .linuxELF else {
                throw NSError(
                    domain: "iSteam.Import",
                    code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "Unsupported executable. Import a Windows .exe/.dll or Linux ELF executable."]
                )
            }

            if format == .windowsPE {
                _ = try WindowsPELoader().load(source)
            } else {
                try ELFValidator.validate(url: source)
            }

            let fm = FileManager.default
            let support = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            let dir = support.appendingPathComponent("Games", isDirectory: true)
            try fm.createDirectory(at: dir, withIntermediateDirectories: true)

            let id = UUID()
            let gameDir = dir.appendingPathComponent(id.uuidString, isDirectory: true)
            try fm.createDirectory(at: gameDir, withIntermediateDirectories: true)

            let destination = gameDir.appendingPathComponent(source.lastPathComponent)
            try fm.copyItem(at: source, to: destination)
            try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: destination.path)

            GameStore.shared.add(GameEntry(
                id: id,
                name: source.deletingPathExtension().lastPathComponent,
                executablePath: destination.path,
                workingDirectory: gameDir.path
            ))
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

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        games.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "GameCell", for: indexPath)
        let game = games[indexPath.row]
        let format = GuestProcessManager.shared.inspect(URL(fileURLWithPath: game.executablePath))
        var c = cell.defaultContentConfiguration()
        c.text = game.name
        if case let .success(type) = format {
            c.secondaryText = type.rawValue
        } else {
            c.secondaryText = "Guest executable"
        }
        cell.contentConfiguration = c
        cell.accessoryType = .disclosureIndicator
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
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
