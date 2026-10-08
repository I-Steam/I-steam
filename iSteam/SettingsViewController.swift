import UIKit
final class SettingsViewController: UITableViewController {
    private let methods = JITMethod.allCases
    override func viewDidLoad() { super.viewDidLoad(); title = "JIT"; tableView.register(UITableViewCell.self, forCellReuseIdentifier: "Setting"); tableView.tableFooterView = UIView() }
    override func numberOfSections(in tableView: UITableView) -> Int { 2 }
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { section == 0 ? methods.count : 2 }
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? { section == 0 ? "JIT Method" : "Runtime" }
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell=tableView.dequeueReusableCell(withIdentifier:"Setting",for:indexPath); var c=cell.defaultContentConfiguration()
        if indexPath.section==0 { let method=methods[indexPath.row]; c.text=method.rawValue; cell.accessoryType=JITCoordinator.shared.selectedMethod == method ? .checkmark : .none }
        else if indexPath.row==0 { c.text="Prepare JIT"; c.secondaryText=JITCoordinator.shared.isRunningInLiveContainer ? "Use LiveContainer's JIT path" : "Open selected JIT method"; cell.accessoryType=.disclosureIndicator }
        else { c.text="Universal Protocol"; c.secondaryText=JITCoordinator.shared.isJITProtocolSupported ? "arm64 / arm64e ready" : "Unsupported architecture" }
        cell.contentConfiguration=c; return cell
    }
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at:indexPath,animated:true)
        if indexPath.section==0 { JITCoordinator.shared.selectedMethod=methods[indexPath.row]; tableView.reloadSections(IndexSet(integer:0),with:.automatic) }
        else if indexPath.row==0 { JITCoordinator.shared.requestJIT(from:self) }
    }
}
