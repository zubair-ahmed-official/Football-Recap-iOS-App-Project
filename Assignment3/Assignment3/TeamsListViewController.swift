import UIKit
import FirebaseFirestore

class TeamsListViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    @IBOutlet weak var tableView: UITableView!
    private var teams: [String] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "All Teams"
        tableView.dataSource = self
        tableView.delegate = self
        navigationItem.rightBarButtonItem = UIBarButtonItem(
                    title: "Add Team",
                    style: .plain,
                    target: self,
                    action: #selector(addTeamTapped)
                )
        fetchTeams()
    }

    private func fetchTeams() {
        Firestore.firestore().collection("teams").getDocuments { snapshot, error in
            guard let docs = snapshot?.documents else { return }
            self.teams = docs.map { $0.documentID }
            DispatchQueue.main.async {
                self.tableView.reloadData()
            }
        }
    }
    
    @objc private func addTeamTapped() {
            let alert = UIAlertController(title: "Add Team", message: nil, preferredStyle: .alert)
            alert.addTextField { $0.placeholder = "Team Name" }
            alert.addAction(.init(title: "Cancel", style: .cancel))
            alert.addAction(.init(title: "Save", style: .default) { _ in
                guard let name = alert.textFields?.first?.text?.trimmingCharacters(in: .whitespacesAndNewlines),
                      !name.isEmpty,
                      !self.teams.contains(name) else { return }
                
                // create empty document with the team name as ID
                Firestore.firestore().collection("teams").document(name).setData([:]) { error in
                    if let error = error {
                        print("❌ Error adding team: \(error)")
                    } else {
                        self.teams.append(name)
                        DispatchQueue.main.async {
                            self.tableView.reloadData()
                        }
                    }
                }
            })
            present(alert, animated: true)
        }
    

    // MARK: - UITableViewDataSource
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return teams.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "TeamCell", for: indexPath)
        cell.textLabel?.text = teams[indexPath.row]
        return cell
    }

    // MARK: - UITableViewDelegate
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let selectedTeam = teams[indexPath.row]
        guard let membersVC = storyboard?.instantiateViewController(withIdentifier: "TeamMembersViewController") as? TeamMembersViewController else {
            return
        }
        membersVC.teamName = selectedTeam
        navigationController?.pushViewController(membersVC, animated: true)
    }
    
    func tableView(_ tableView: UITableView,
                       trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath)
                       -> UISwipeActionsConfiguration? {
            let delete = UIContextualAction(style: .destructive, title: "Delete") { _, _, completion in
                let teamName = self.teams[indexPath.row]
                Firestore.firestore().collection("teams").document(teamName).delete { error in
                    if let error = error {
                        print("❌ Error deleting team: \(error)")
                    } else {
                        self.teams.remove(at: indexPath.row)
                        DispatchQueue.main.async {
                            tableView.deleteRows(at: [indexPath], with: .automatic)
                        }
                    }
                    completion(true)
                }
            }
            return UISwipeActionsConfiguration(actions: [delete])
        }
}
