import UIKit
import UniformTypeIdentifiers

/// Full-page launch configuration. Saved settings are restored, but this screen remains
/// a launch scaffold until a bootable QEMU runtime is bundled and connected.
final class LaunchSetupViewController: UIViewController, UIDocumentPickerDelegate {
    private let guestControl = UISegmentedControl(items: ["Ubuntu", "SteamOS", "Windows 10"])
    private let runtimeControl = UISegmentedControl(items: ["Full VM", "EXE library"])
    private let vrSwitch = UISwitch()
    private let persistSwitch = UISwitch()
    private let slotField = UITextField()
    private let statusLabel = UILabel()
    private let diskLabel = UILabel()
    private var selectedDiskURL: URL?
    private var loadedConfiguration: VMConfiguration?

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Launch Setup"
        view.backgroundColor = .systemGroupedBackground
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Save Slot", style: .done, target: self, action: #selector(saveSlot))
        buildForm()
        let lastGuest = UserDefaults.standard.string(forKey: "iSteam.lastGuest") ?? "Ubuntu"
        guestControl.selectedSegmentIndex = lastGuest == "Windows 10" ? 2 : (lastGuest == "SteamOS" ? 1 : 0)
        runtimeControl.selectedSegmentIndex = 0
        vrSwitch.isOn = VRSettings.shared.mode == .cardboard
        persistSwitch.isOn = UserDefaults.standard.bool(forKey: "iSteam.persistSessionData")
        slotField.text = "My VM"
    }

    private func buildForm() {
        let scroll = UIScrollView()
        let stack = UIStackView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.spacing = 18
        stack.isLayoutMarginsRelativeArrangement = true
        stack.layoutMargins = UIEdgeInsets(top: 24, left: 20, bottom: 32, right: 20)
        view.addSubview(scroll)
        scroll.addSubview(stack)
        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            stack.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor),
            stack.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor),
            stack.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor)
        ])

        let heading = UILabel()
        heading.text = "Configure your session"
        heading.font = .systemFont(ofSize: 30, weight: .bold)
        stack.addArrangedSubview(heading)
        let intro = UILabel()
        intro.text = "Choose Ubuntu, SteamOS Gaming Mode, or Windows 10. SteamOS mode applies a game-focused Linux VM profile (8 GB RAM, 4 CPUs, 1280×800 at 60 FPS); it is not Valve’s Steam Deck OS image. Supply a compatible bootable Linux/SteamOS image. Guest boot still requires the bundled QEMU runtime and suitable UEFI firmware."
        intro.font = .preferredFont(forTextStyle: .subheadline)
        intro.textColor = .secondaryLabel
        intro.numberOfLines = 0
        stack.addArrangedSubview(intro)

        addSection("Operating system", control: guestControl, to: stack)
        addSection("Launch target", control: runtimeControl, to: stack)
        addSwitchRow("Cardboard / VR-style layout", detail: "Display-layout prototype only; not true stereo VR.", control: vrSwitch, to: stack)
        addSwitchRow("Keep session data", detail: "Stores the complete VM configuration for Continue from Last Session. It does not save guest RAM or in-game saves.", control: persistSwitch, to: stack)

        let slotLabel = UILabel()
        slotLabel.text = "VM configuration slot name"
        slotLabel.font = .systemFont(ofSize: 17, weight: .semibold)
        stack.addArrangedSubview(slotLabel)
        slotField.borderStyle = .roundedRect
        slotField.placeholder = "My VM"
        slotField.autocorrectionType = .no
        stack.addArrangedSubview(slotField)

        let slotsButton = UIButton(type: .system)
        slotsButton.setTitle("Load a saved configuration…", for: .normal)
        slotsButton.contentHorizontalAlignment = .leading
        slotsButton.addTarget(self, action: #selector(loadSlot), for: .touchUpInside)
        stack.addArrangedSubview(slotsButton)

        diskLabel.text = "Guest image: not selected"
        diskLabel.font = .preferredFont(forTextStyle: .footnote)
        diskLabel.textColor = .secondaryLabel
        diskLabel.numberOfLines = 0
        stack.addArrangedSubview(diskLabel)

        let chooseDiskButton = UIButton(type: .system)
        chooseDiskButton.setTitle("Choose guest disk / ISO…", for: .normal)
        chooseDiskButton.contentHorizontalAlignment = .leading
        chooseDiskButton.addTarget(self, action: #selector(chooseGuestImage), for: .touchUpInside)
        stack.addArrangedSubview(chooseDiskButton)

        statusLabel.numberOfLines = 0
        statusLabel.font = .preferredFont(forTextStyle: .footnote)
        statusLabel.textColor = .secondaryLabel
        stack.addArrangedSubview(statusLabel)

        var config = UIButton.Configuration.filled()
        config.title = "Launch"
        config.image = UIImage(systemName: "play.fill")
        config.imagePadding = 8
        config.cornerStyle = .large
        let launch = UIButton(configuration: config)
        launch.heightAnchor.constraint(equalToConstant: 56).isActive = true
        launch.addTarget(self, action: #selector(launchSession), for: .touchUpInside)
        stack.addArrangedSubview(launch)
    }

    private func addSection(_ title: String, control: UISegmentedControl, to stack: UIStackView) {
        let label = UILabel()
        label.text = title
        label.font = .systemFont(ofSize: 17, weight: .semibold)
        stack.addArrangedSubview(label)
        control.selectedSegmentIndex = 0
        stack.addArrangedSubview(control)
    }

    private func addSwitchRow(_ title: String, detail: String, control: UISwitch, to stack: UIStackView) {
        let row = UIStackView()
        row.axis = .horizontal
        row.alignment = .center
        row.spacing = 12
        let labels = UIStackView()
        labels.axis = .vertical
        labels.spacing = 4
        let heading = UILabel()
        heading.text = title
        heading.font = .systemFont(ofSize: 16, weight: .medium)
        let subtitle = UILabel()
        subtitle.text = detail
        subtitle.textColor = .secondaryLabel
        subtitle.font = .preferredFont(forTextStyle: .footnote)
        subtitle.numberOfLines = 0
        labels.addArrangedSubview(heading)
        labels.addArrangedSubview(subtitle)
        row.addArrangedSubview(labels)
        row.addArrangedSubview(control)
        stack.addArrangedSubview(row)
    }

    private func makeConfiguration() -> VMConfiguration {
        let selectedGuest = guestControl.selectedSegmentIndex
        let isWindows = selectedGuest == 2
        let isSteamOS = selectedGuest == 1
        let expectedName = isWindows ? "Windows 10" : (isSteamOS ? "SteamOS Gaming Mode" : "Ubuntu")
        var config = loadedConfiguration.flatMap { $0.name == expectedName ? $0 : nil }
            ?? (isWindows ? VMConfiguration.defaultWindows : (isSteamOS ? VMConfiguration.defaultSteamOS : VMConfiguration.defaultLinux))
        config.name = expectedName
        config.bootWindows = isWindows
        config.displayWidth = isSteamOS ? 1280 : RuntimeSettings.shared.renderResolution.width
        config.displayHeight = isSteamOS ? 800 : RuntimeSettings.shared.renderResolution.height
        config.displayFPS = isSteamOS ? 60 : RuntimeSettings.shared.frameRate.value
        if isSteamOS {
            config.memoryMB = max(config.memoryMB, 8192)
            config.cpuCount = max(config.cpuCount, 4)
            config.accelerator = .jit
            config.gpu = .virtioGPU
        }
        return config
    }

    @objc private func saveSlot() {
        let name = (slotField.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            statusLabel.text = "Enter a name for this configuration slot."
            return
        }
        do {
            try VMSaveSlotStore.shared.saveConfiguration(makeConfiguration(), name: name)
            statusLabel.text = "Saved configuration slot: \(name)"
        } catch {
            statusLabel.text = "Could not save slot: \(error.localizedDescription)"
        }
    }

    @objc private func loadSlot() {
        let slots = VMSaveSlotStore.shared.configurationNames
        guard !slots.isEmpty else {
            statusLabel.text = "No saved configuration slots yet. Save one first."
            return
        }
        let alert = UIAlertController(title: "Load Configuration", message: nil, preferredStyle: .actionSheet)
        for name in slots {
            alert.addAction(UIAlertAction(title: name, style: .default) { [weak self] _ in
                guard let self, let config = VMSaveSlotStore.shared.configuration(named: name) else { return }
                self.loadedConfiguration = config
                self.guestControl.selectedSegmentIndex = config.bootWindows ? 2 : (config.name == "SteamOS Gaming Mode" ? 1 : 0)
                self.slotField.text = name
                self.statusLabel.text = "Loaded \(name): \(config.memoryMB) MB RAM, \(config.cpuCount) CPUs, \(config.displayWidth) × \(config.displayHeight) at \(config.displayFPS) FPS. Current display preferences override resolution and FPS on launch."
            })
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        if let pop = alert.popoverPresentationController {
            pop.sourceView = view
            pop.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 1, height: 1)
        }
        present(alert, animated: true)
    }

    @objc private func launchSession() {
        let config = makeConfiguration()
        VRSettings.shared.mode = vrSwitch.isOn ? .cardboard : .flat
        UserDefaults.standard.set(persistSwitch.isOn, forKey: "iSteam.persistSessionData")
        UserDefaults.standard.set(config.bootWindows ? "Windows 10" : (config.name == "SteamOS Gaming Mode" ? "SteamOS" : "Ubuntu"), forKey: "iSteam.lastGuest")
        UserDefaults.standard.set(config.bootWindows ? "Windows VM" : (config.name == "SteamOS Gaming Mode" ? "SteamOS Gaming Mode" : "Linux VM"), forKey: "iSteam.lastVMMode")
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "iSteam.lastLaunchDate")

        if persistSwitch.isOn {
            do {
                try VMSaveSlotStore.shared.saveSessionMetadata(configuration: config)
            } catch {
                statusLabel.text = "Could not save session: \(error.localizedDescription)"
            }
        }
        let name = (slotField.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if !name.isEmpty {
            do { try VMSaveSlotStore.shared.saveConfiguration(config, name: name) }
            catch { statusLabel.text = "Could not save configuration slot: \(error.localizedDescription)" }
        }

        if runtimeControl.selectedSegmentIndex == 1 {
            navigationController?.pushViewController(LibraryViewController(), animated: true)
            return
        }

        guard let diskURL = selectedDiskURL else {
            statusLabel.text = "Choose a guest disk image or bootable ISO before launching. The engine cannot start without an image."
            chooseGuestImage()
            return
        }
        navigationController?.pushViewController(
            VMDisplayViewController(configuration: config, diskImage: diskURL),
            animated: true
        )
    }

    @objc private func chooseGuestImage() {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.item], asCopy: false)
        picker.delegate = self
        picker.allowsMultipleSelection = false
        present(picker, animated: true)
    }

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first else { return }
        selectedDiskURL = url
        diskLabel.text = "Guest image: \(url.lastPathComponent)"
        statusLabel.text = "Image selected. Tap Launch to start the VM. SteamOS Gaming Mode needs a compatible bootable image, suitable UEFI firmware, and the bundled QEMU runtime; selecting this mode does not install or provide SteamOS."
    }

    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        statusLabel.text = "No guest image selected; the VM was not started."
    }
}