import UIKit
import UniformTypeIdentifiers

final class LibraryViewController: UIViewController, UIDocumentPickerDelegate {
    private let scrollView = UIScrollView()
    private let stack = UIStackView()
    private let statusLabel = UILabel()
    private var pickerPurpose: PickerPurpose = .game

    private enum PickerPurpose { case game, operatingSystem }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "iSteam"
        view.backgroundColor = .systemGroupedBackground
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Settings", style: .plain, target: self, action: #selector(openSettings))
        buildMenu()
    }

    private func buildMenu() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.spacing = 14
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.isLayoutMarginsRelativeArrangement = true
        stack.layoutMargins = UIEdgeInsets(top: 22, left: 20, bottom: 28, right: 20)
        view.addSubview(scrollView)
        scrollView.addSubview(stack)
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            stack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            stack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            stack.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor)
        ])

        let heading = UILabel()
        heading.text = "Ready to play?"
        heading.font = .systemFont(ofSize: 34, weight: .bold)
        stack.addArrangedSubview(heading)
        let subtitle = UILabel()
        subtitle.text = "Choose a session or set up an operating system."
        subtitle.font = .preferredFont(forTextStyle: .subheadline)
        subtitle.textColor = .secondaryLabel
        subtitle.numberOfLines = 0
        stack.addArrangedSubview(subtitle)

        stack.addArrangedSubview(makeButton("Continue from Last Session", detail: "Restore the last saved VM configuration", symbol: "arrow.clockwise", primary: true) { [weak self] in self?.continueLastSession() })
        stack.addArrangedSubview(makeButton("Launch", detail: "Open the full session setup page", symbol: "play.fill", primary: true) { [weak self] in self?.showLaunchFlow() })
        stack.addArrangedSubview(makeButton("Steam Store", detail: "Browse the official Steam Store", symbol: "cart", primary: false) { [weak self] in self?.openSteamStore() })
        stack.addArrangedSubview(makeButton("Import Custom OS", detail: "Choose an OS image or disk file", symbol: "externaldrive.badge.plus", primary: false) { [weak self] in self?.importOperatingSystem() })
        stack.addArrangedSubview(makeButton("Import Game / Executable", detail: "Add a Windows PE or Linux ELF file", symbol: "plus.rectangle.on.folder", primary: false) { [weak self] in self?.importGame() })
        stack.addArrangedSubview(makeButton("Settings", detail: "Display, VM, input, and diagnostics", symbol: "gearshape", primary: false) { [weak self] in self?.openSettings() })
        statusLabel.textColor = .secondaryLabel
        statusLabel.font = .preferredFont(forTextStyle: .footnote)
        statusLabel.numberOfLines = 0
        stack.addArrangedSubview(statusLabel)
        updateOSStatus()
    }

    private func updateOSStatus() {
        if let os = UserDefaults.standard.string(forKey: "iSteam.customOSPath") {
            statusLabel.text = "Imported OS image: " + URL(fileURLWithPath: os).lastPathComponent + "\nSaved locally; OS boot integration is not yet implemented."
        } else {
            statusLabel.text = "No custom OS image imported."
        }
    }

    private func makeButton(_ title: String, detail: String, symbol: String, primary: Bool, action: @escaping () -> Void) -> UIButton {
        var config = UIButton.Configuration.filled()
        config.title = title
        config.subtitle = detail
        config.image = UIImage(systemName: symbol)
        config.imagePlacement = .leading
        config.imagePadding = 12
        config.titleAlignment = .leading
        config.cornerStyle = .large
        config.contentInsets = NSDirectionalEdgeInsets(top: 18, leading: 18, bottom: 18, trailing: 18)
        config.baseBackgroundColor = primary ? .systemBlue : .secondarySystemGroupedBackground
        config.baseForegroundColor = primary ? .white : .label
        let button = UIButton(configuration: config)
        button.heightAnchor.constraint(greaterThanOrEqualToConstant: 82).isActive = true
        button.contentHorizontalAlignment = .leading
        button.addAction(UIAction { _ in action() }, for: .touchUpInside)
        return button
    }

    @objc private func openSettings() {
        navigationController?.pushViewController(SettingsViewController(), animated: true)
    }

    private func continueLastSession() {
        guard let config = VMSaveSlotStore.shared.lastSessionConfiguration() else {
            let alert = UIAlertController(title: "No saved session", message: "Launch a session with Keep session data enabled to save its configuration for next time.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            alert.addAction(UIAlertAction(title: "Set up a session", style: .default) { [weak self] _ in self?.showLaunchFlow() })
            present(alert, animated: true)
            return
        }
        navigationController?.pushViewController(VMDisplayViewController(configuration: config), animated: true)
    }

    private func showLaunchFlow() {
        navigationController?.pushViewController(LaunchSetupViewController(), animated: true)
    }

    private func openSteamStore() {
        guard let url = URL(string: "https://store.steampowered.com/") else { return }
        UIApplication.shared.open(url)
    }

    private func importGame() {
        pickerPurpose = .game
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.data, .item], asCopy: true)
        picker.delegate = self
        picker.allowsMultipleSelection = false
        present(picker, animated: true)
    }

    private func importOperatingSystem() {
        pickerPurpose = .operatingSystem
        var types: [UTType] = [.data, .diskImage]
        if let iso = UTType(filenameExtension: "iso") { types.append(iso) }
        if let qcow = UTType(filenameExtension: "qcow2") { types.append(qcow) }
        if let img = UTType(filenameExtension: "img") { types.append(img) }
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: types, asCopy: true)
        picker.delegate = self
        picker.allowsMultipleSelection = false
        present(picker, animated: true)
    }

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let source = urls.first else { return }
        if pickerPurpose == .operatingSystem {
            do {
                let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                let dir = support.appendingPathComponent("OperatingSystems", isDirectory: true)
                try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
                let destination = dir.appendingPathComponent(source.lastPathComponent)
                if FileManager.default.fileExists(atPath: destination.path) { try FileManager.default.removeItem(at: destination) }
                try FileManager.default.copyItem(at: source, to: destination)
                UserDefaults.standard.set(destination.path, forKey: "iSteam.customOSPath")
                updateOSStatus()
                showMessage("OS image imported", "Saved " + destination.lastPathComponent + ". The current VM engine does not yet boot imported ISO/disk images.")
            } catch { showMessage("Import failed", error.localizedDescription) }
            return
        }
        do {
            let formatResult = GuestProcessManager.shared.inspect(source)
            guard case let .success(format) = formatResult, format == .windowsPE || format == .linuxELF else {
                throw NSError(domain: "iSteam.Import", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unsupported executable. Import a Windows PE or Linux ELF executable."])
            }
            if format == .windowsPE { _ = try WindowsPELoader().load(source) } else { try ELFValidator.validate(url: source) }
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
            GameStore.shared.add(GameEntry(id: id, name: source.deletingPathExtension().lastPathComponent, executablePath: destination.path, workingDirectory: gameDir.path))
            showMessage("Game imported", source.lastPathComponent + " added to the library.")
        } catch { showMessage("Import failed", error.localizedDescription) }
    }

    private func showMessage(_ title: String, _ message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}