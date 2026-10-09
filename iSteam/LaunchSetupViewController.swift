import UIKit

/// Full-page launch configuration. This persists selections and VM configuration slots;
/// it does not claim to boot an OS until a real QEMU runtime is integrated.
final class LaunchSetupViewController: UIViewController {
    private let guestControl = UISegmentedControl(items: ["Ubuntu", "Windows 10"])
    private let runtimeControl = UISegmentedControl(items: ["Full VM", "EXE library"])
    private let vrSwitch = UISwitch()
    private let persistSwitch = UISwitch()
    private let slotField = UITextField()
    private let statusLabel = UILabel()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Launch Setup"
        view.backgroundColor = .systemGroupedBackground
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Save Slot", style: .done, target: self, action: #selector(saveSlot))
        buildForm()
        guestControl.selectedSegmentIndex = UserDefaults.standard.string(forKey: "iSteam.lastGuest") == "Windows 10" ? 1 : 0
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
        intro.text = "Choose an operating system, display mode and a save slot. Ubuntu is the default. Windows 10 requires a user-provided installation ISO and a working VM runtime."
        intro.font = .preferredFont(forTextStyle: .subheadline)
        intro.textColor = .secondaryLabel
        intro.numberOfLines = 0
        stack.addArrangedSubview(intro)

        addSection("Operating system", control: guestControl, to: stack)
        addSection("Launch target", control: runtimeControl, to: stack)
        addSwitchRow("Cardboard / VR-style layout", detail: "Display-layout prototype only; not true stereo VR.", control: vrSwitch, to: stack)
        addSwitchRow("Keep session data", detail: "Saves session metadata and VM configuration. Actual in-game save data requires a running guest disk.", control: persistSwitch, to: stack)

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
        var config = guestControl.selectedSegmentIndex == 1 ? VMConfiguration.defaultWindows : VMConfiguration.defaultLinux
        config.name = guestControl.selectedSegmentIndex == 1 ? "Windows 10" : "Ubuntu"
        config.bootWindows = guestControl.selectedSegmentIndex == 1
        config.displayWidth = RuntimeSettings.shared.renderResolution.width
        config.displayHeight = RuntimeSettings.shared.renderResolution.height
        config.displayFPS = RuntimeSettings.shared.frameRate.value
        return config
    }

    @objc private func saveSlot() {
        let name = (slotField.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            statusLabel.text = "Enter a name for this configuration slot."
            return
        }
        let config = makeConfiguration()
        do {
            try VMSaveSlotStore.shared.saveConfiguration(config, name: name)
            UserDefaults.standard.set(guestControl.selectedSegmentIndex == 1 ? "Windows 10" : "Ubuntu", forKey: "iSteam.lastGuest")
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
                self.guestControl.selectedSegmentIndex = config.bootWindows ? 1 : 0
                self.slotField.text = name
                self.statusLabel.text = "Loaded \(name). Settings will be used on launch."
            })
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        if let pop = alert.popoverPresentationController { pop.sourceView = view; pop.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 1, height: 1) }
        present(alert, animated: true)
    }

    @objc private func launchSession() {
        let config = makeConfiguration()
        VRSettings.shared.mode = vrSwitch.isOn ? .cardboard : .flat
        UserDefaults.standard.set(persistSwitch.isOn, forKey: "iSteam.persistSessionData")
        UserDefaults.standard.set(guestControl.selectedSegmentIndex == 1 ? "Windows 10" : "Ubuntu", forKey: "iSteam.lastGuest")
        UserDefaults.standard.set(config.bootWindows ? "Windows VM" : "Linux VM", forKey: "iSteam.lastVMMode")
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "iSteam.lastLaunchDate")
        let name = (slotField.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if !name.isEmpty { try? VMSaveSlotStore.shared.saveConfiguration(config, name: name) }

        if runtimeControl.selectedSegmentIndex == 1 {
            let library = LibraryViewController()
            navigationController?.pushViewController(library, animated: true)
            return
        }

        if config.bootWindows && UserDefaults.standard.string(forKey: "iSteam.customOSPath") == nil {
            let alert = UIAlertController(
                title: "Windows 10 installation media required",
                message: "Import a legitimate full Windows 10 ISO first. A PE executable is not a Windows operating system. This prototype currently stores ISO files but does not yet boot them, so this launch will only show the VM scaffold.",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "Continue to VM preview", style: .default) { [weak self] _ in
                self?.navigationController?.pushViewController(VMDisplayViewController(configuration: config), animated: true)
            })
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
            present(alert, animated: true)
            return
        }
        navigationController?.pushViewController(VMDisplayViewController(configuration: config), animated: true)
    }
}
