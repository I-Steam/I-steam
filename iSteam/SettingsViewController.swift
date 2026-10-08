import UIKit

final class SettingsViewController: UITableViewController {
    private let jitMethods = JITMethod.allCases
    private let vmModes = VMExecutionMode.allCases
    private let accelerators = VMAccelerationBackend.allCases
    private let resolutions = DisplayResolution.allCases
    private let frameRates = DisplayFrameRate.allCases
    private let vrModes = VRDisplayMode.allCases

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Settings"
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "Setting")
        tableView.tableFooterView = UIView()
    }

    override func numberOfSections(in tableView: UITableView) -> Int { 8 }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 0: return vmModes.count
        case 1: return accelerators.count
        case 2: return resolutions.count
        case 3: return frameRates.count
        case 4: return vrModes.count + 2
        case 5: return jitMethods.count
        default: return 1
        }
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        ["Windows Runtime", "VM / Hypervisor", "Resolution", "Display / FPS", "VR / Input", "JIT", "Diagnostics", "Performance"][section]
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Setting", for: indexPath)
        var c = cell.defaultContentConfiguration()
        cell.accessoryType = .none
        switch indexPath.section {
        case 0:
            let mode = vmModes[indexPath.row]; c.text = mode.rawValue; c.secondaryText = mode.detail
            cell.accessoryType = RuntimeSettings.shared.vmMode == mode ? .checkmark : .none
        case 1:
            let mode = accelerators[indexPath.row]; c.text = mode.rawValue; c.secondaryText = mode.detail
            cell.accessoryType = RuntimeSettings.shared.acceleration == mode ? .checkmark : .none
        case 2:
            let mode = resolutions[indexPath.row]
            c.text = mode == .custom ? "Custom (\(RuntimeSettings.shared.customWidth) × \(RuntimeSettings.shared.customHeight))" : mode.rawValue
            c.secondaryText = mode.detail
            cell.accessoryType = RuntimeSettings.shared.resolution == mode ? .checkmark : .none
        case 3:
            let rate = frameRates[indexPath.row]; c.text = rate.rawValue; c.secondaryText = rate.detail
            cell.accessoryType = RuntimeSettings.shared.frameRate == rate ? .checkmark : .none
        case 4:
            if indexPath.row < vrModes.count {
                let mode = vrModes[indexPath.row]; c.text = mode.rawValue; c.secondaryText = mode.detail
                cell.accessoryType = VRSettings.shared.mode == mode ? .checkmark : .none
            } else if indexPath.row == vrModes.count {
                c.text = "Pointer lock / relative look"
                c.secondaryText = VRSettings.shared.pointerLockEnabled ? "Enabled for touch/controller look input" : "Disabled"
                cell.accessoryType = VRSettings.shared.pointerLockEnabled ? .checkmark : .none
            } else {
                c.text = "Virtual touchscreen gamepad"
                c.secondaryText = VRSettings.shared.touchGamepadEnabled ? "Shown in display" : "Hidden"
                cell.accessoryType = VRSettings.shared.touchGamepadEnabled ? .checkmark : .none
            }
        case 5:
            let method = jitMethods[indexPath.row]; c.text = method.rawValue
            cell.accessoryType = JITCoordinator.shared.selectedMethod == method ? .checkmark : .none
        case 6:
            c.text = "Crash Log"; c.secondaryText = "View saved crash information"; cell.accessoryType = .disclosureIndicator
        default:
            c.text = "Performance Diagnostics"; c.secondaryText = PerformanceManager.shared.summary; cell.accessoryType = .disclosureIndicator
        }
        cell.contentConfiguration = c
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        switch indexPath.section {
        case 0:
            RuntimeSettings.shared.vmMode = vmModes[indexPath.row]; tableView.reloadSections(IndexSet(integer: 0), with: .automatic)
        case 1:
            RuntimeSettings.shared.acceleration = accelerators[indexPath.row]; tableView.reloadSections(IndexSet(integer: 1), with: .automatic)
        case 2:
            let mode = resolutions[indexPath.row]
            if mode == .custom { showCustomResolutionEditor() }
            else { RuntimeSettings.shared.resolution = mode; tableView.reloadSections(IndexSet(integer: 2), with: .automatic) }
        case 3:
            let mode = frameRates[indexPath.row]
            if mode == .custom { showCustomFPSEditor() }
            else { RuntimeSettings.shared.frameRate = mode; tableView.reloadSections(IndexSet(integer: 3), with: .automatic) }
        case 4:
            if indexPath.row < vrModes.count {
                VRSettings.shared.mode = vrModes[indexPath.row]
            } else if indexPath.row == vrModes.count {
                VRSettings.shared.pointerLockEnabled.toggle()
            } else {
                VRSettings.shared.touchGamepadEnabled.toggle()
            }
            tableView.reloadSections(IndexSet(integer: 4), with: .automatic)
        case 5:
            JITCoordinator.shared.selectedMethod = jitMethods[indexPath.row]; tableView.reloadSections(IndexSet(integer: 5), with: .automatic)
        case 6:
            navigationController?.pushViewController(CrashLogViewController(), animated: true)
        default:
            let alert = UIAlertController(title: "Performance", message: PerformanceManager.shared.detailedSummary, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default)); present(alert, animated: true)
        }
    }

    private func showCustomFPSEditor() {
        let alert = UIAlertController(title: "Custom FPS", message: "Choose a target between 24 and 120 FPS. Actual frame rate depends on the iPad display, game, thermal limits and renderer.", preferredStyle: .alert)
        alert.addTextField { field in field.placeholder = "FPS (24–120)"; field.keyboardType = .numberPad; field.text = "\(RuntimeSettings.shared.customFPS)" }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Apply", style: .default) { [weak self, weak alert] _ in
            guard let text = alert?.textFields?.first?.text, let value = Int(text), (24...120).contains(value) else {
                let error = UIAlertController(title: "Invalid FPS", message: "Enter a whole number from 24 to 120.", preferredStyle: .alert)
                error.addAction(UIAlertAction(title: "OK", style: .default)); self?.present(error, animated: true); return
            }
            RuntimeSettings.shared.customFPS = value
            RuntimeSettings.shared.frameRate = .custom
            self?.tableView.reloadSections(IndexSet(integer: 3), with: .automatic)
        })
        present(alert, animated: true)
    }

    private func showCustomResolutionEditor() {
        let alert = UIAlertController(title: "Custom Resolution", message: "Internal render size. Width 320–8192; height 240–8192.", preferredStyle: .alert)
        alert.addTextField { $0.placeholder = "Width"; $0.keyboardType = .numberPad; $0.text = "\(RuntimeSettings.shared.customWidth)" }
        alert.addTextField { $0.placeholder = "Height"; $0.keyboardType = .numberPad; $0.text = "\(RuntimeSettings.shared.customHeight)" }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Apply", style: .default) { [weak self, weak alert] _ in
            guard let self, let alert,
                  let w = Int(alert.textFields?[0].text ?? ""), let h = Int(alert.textFields?[1].text ?? ""),
                  (320...8192).contains(w), (240...8192).contains(h) else {
                self?.showInvalidResolutionAlert(); return
            }
            RuntimeSettings.shared.customWidth = w
            RuntimeSettings.shared.customHeight = h
            RuntimeSettings.shared.resolution = .custom
            self.tableView.reloadSections(IndexSet(integer: 2), with: .automatic)
        })
        present(alert, animated: true)
    }

    private func showInvalidResolutionAlert() {
        let alert = UIAlertController(title: "Invalid Resolution", message: "Use width 320–8192 and height 240–8192.", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default)); present(alert, animated: true)
    }
}
