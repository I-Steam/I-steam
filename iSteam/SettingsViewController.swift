import UIKit

final class SettingsViewController: UITableViewController {
    private let methods = JITMethod.allCases

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Runtime"
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "Setting")
        tableView.tableFooterView = UIView()
    }

    override func numberOfSections(in tableView: UITableView) -> Int { 3 }
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { section == 0 ? methods.count : 1 }
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? { ["JIT Method", "JIT", "Diagnostics"][section] }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Setting", for: indexPath)
        var c = cell.defaultContentConfiguration()
        if indexPath.section == 0 {
            let method = methods[indexPath.row]
            c.text = method.rawValue
            cell.accessoryType = JITCoordinator.shared.selectedMethod == method ? .checkmark : .none
        } else if indexPath.section == 1 {
            c.text = "Prepare JIT"
            c.secondaryText = JITCoordinator.shared.isRunningInLiveContainer ? "LiveContainer / StikDebug" : "StikDebug"
            cell.accessoryType = .disclosureIndicator
        } else {
            c.text = "Crash Log"
            c.secondaryText = "View the latest saved crash information"
            cell.accessoryType = .disclosureIndicator
        }
        cell.contentConfiguration = c
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if indexPath.section == 0 {
            JITCoordinator.shared.selectedMethod = methods[indexPath.row]
            tableView.reloadSections(IndexSet(integer: 0), with: .automatic)
        } else if indexPath.section == 1 {
            JITCoordinator.shared.requestJIT(from: self)
        } else {
            navigationController?.pushViewController(CrashLogViewController(), animated: true)
        }
    }
}
