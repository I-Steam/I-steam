import UIKit

final class SettingsViewController: UITableViewController {
    private let jitMethods = JITMethod.allCases
    private let vmModes = VMExecutionMode.allCases
    private let accelerators = VMAccelerationBackend.allCases
    private let frameRates = DisplayFrameRate.allCases

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Settings"
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "Setting")
        tableView.tableFooterView = UIView()
    }

    override func numberOfSections(in tableView: UITableView) -> Int { 6 }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 0: return vmModes.count
        case 1: return accelerators.count
        case 2: return frameRates.count
        case 3: return jitMethods.count
        default: return 1
        }
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        ["Windows Runtime", "VM / Hypervisor", "Display", "JIT", "Diagnostics", "Performance"][section]
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Setting", for: indexPath)
        var c = cell.defaultContentConfiguration()
        cell.accessoryType = .none

        switch indexPath.section {
        case 0:
            let mode = vmModes[indexPath.row]
            c.text = mode.rawValue
            c.secondaryText = mode.detail
            cell.accessoryType = RuntimeSettings.shared.vmMode == mode ? .checkmark : .none
        case 1:
            let backend = accelerators[indexPath.row]
            c.text = backend.rawValue
            c.secondaryText = backend.detail
            cell.accessoryType = RuntimeSettings.shared.acceleration == backend ? .checkmark : .none
        case 2:
            let rate = frameRates[indexPath.row]
            c.text = rate.rawValue
            c.secondaryText = rate.detail
            cell.accessoryType = RuntimeSettings.shared.frameRate == rate ? .checkmark : .none
        case 3:
            let method = jitMethods[indexPath.row]
            c.text = method.rawValue
            cell.accessoryType = JITCoordinator.shared.selectedMethod == method ? .checkmark : .none
        case 4:
            c.text = "Crash Log"
            c.secondaryText = "View saved crash information"
            cell.accessoryType = .disclosureIndicator
        default:
            c.text = "Performance Diagnostics"
            c.secondaryText = PerformanceManager.shared.summary
            cell.accessoryType = .disclosureIndicator
        }

        cell.contentConfiguration = c
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        switch indexPath.section {
        case 0:
            RuntimeSettings.shared.vmMode = vmModes[indexPath.row]
            tableView.reloadSections(IndexSet(integer: 0), with: .automatic)
        case 1:
            RuntimeSettings.shared.acceleration = accelerators[indexPath.row]
            tableView.reloadSections(IndexSet(integer: 1), with: .automatic)
        case 2:
            RuntimeSettings.shared.frameRate = frameRates[indexPath.row]
            tableView.reloadSections(IndexSet(integer: 2), with: .automatic)
        case 3:
            JITCoordinator.shared.selectedMethod = jitMethods[indexPath.row]
            tableView.reloadSections(IndexSet(integer: 3), with: .automatic)
        case 4:
            navigationController?.pushViewController(CrashLogViewController(), animated: true)
        default:
            let alert = UIAlertController(title: "Performance", message: PerformanceManager.shared.detailedSummary, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
        }
    }
}
