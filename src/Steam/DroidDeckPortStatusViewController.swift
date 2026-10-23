import UIKit

/// Honest, in-app inventory of the DroidDeck features that have been ported.
/// Readiness comes from the same registry used by runtime diagnostics.
final class DroidDeckPortStatusViewController: UITableViewController {
    private let features = DroidDeckPortFeature.allCases

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "DroidDeck Port Status"
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "Feature")
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 76
        tableView.tableFooterView = UIView()
    }

    override func numberOfSections(in tableView: UITableView) -> Int { 1 }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        features.count
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        "Feature readiness — not a claim that a guest OS boots"
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Feature", for: indexPath)
        let feature = features[indexPath.row]
        var content = cell.defaultContentConfiguration()
        content.text = Self.title(for: feature)
        content.secondaryText = feature.explanation
        content.secondaryTextProperties.numberOfLines = 0
        switch feature.readiness {
        case .implemented:
            content.image = UIImage(systemName: "checkmark.circle.fill")
            content.imageProperties.tintColor = .systemGreen
        case .partial:
            content.image = UIImage(systemName: "minus.circle.fill")
            content.imageProperties.tintColor = .systemOrange
        case .unavailable:
            content.image = UIImage(systemName: "xmark.circle.fill")
            content.imageProperties.tintColor = .systemRed
        }
        cell.contentConfiguration = content
        cell.selectionStyle = .none
        return cell
    }

    private static func title(for feature: DroidDeckPortFeature) -> String {
        switch feature {
        case .libraryManagement: return "Game library management"
        case .perGameProfiles: return "Per-game profiles"
        case .libraryBackup: return "Library backup / restore"
        case .documentPickerImport: return "Files import"
        case .controllerInput: return "Controller input"
        case .touchGamepad: return "Touch gamepad"
        case .performanceTargets: return "Resolution / FPS targets"
        case .externalStorageBookmarks: return "External storage bookmarks"
        case .linuxDesktop: return "Linux desktop"
        case .flatpakAndAppImage: return "Flatpak / AppImage"
        case .windowsProton: return "Windows games / Proton"
        case .fexTranslation: return "FEX CPU translation"
        case .turnipVulkan: return "Turnip / Vulkan"
        case .frameGeneration: return "Frame generation"
        case .steamVR: return "SteamVR"
        case .glassesPoseTracking: return "XR glasses / pose tracking"
        case .rawUSBBlockDevices: return "Raw USB block devices"
        case .fullSystemQEMU: return "Full-system QEMU"
        }
    }
}
