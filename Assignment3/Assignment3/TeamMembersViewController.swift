import UIKit
import FirebaseFirestore
import FirebaseStorage

class TeamMembersViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, UISearchBarDelegate {

    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var searchBar: UISearchBar!
    @IBOutlet weak var continueButton: UIButton!

    var teamName: String?
    var players: [Player] = []
    var playerDocs: [DocumentSnapshot] = []
    var allPlayers: [Player] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = "\(teamName ?? "Team")"
        tableView.delegate = self
        tableView.dataSource = self
        searchBar.delegate = self

        self.navigationItem.hidesBackButton = true
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Save", style: .plain, target: self, action: #selector(customBackTapped))
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Add Member", style: .plain, target: self, action: #selector(addPlayerTapped))

        fetchPlayers()
    }

    @objc func customBackTapped() {
        if players.count < 2 {
            showError("You must have at least 2 players before going back.")
        } else {
            self.navigationController?.popViewController(animated: true)
        }
    }

    @objc func addPlayerTapped() {
        performSegue(withIdentifier: "addPlayer", sender: nil)
    }

    func fetchPlayers() {
        guard let teamName = teamName else { return }

        let db = Firestore.firestore()
        let playersRef = db.collection("teams").document(teamName).collection("players")

        playersRef.addSnapshotListener { snapshot, error in
            if let error = error {
                print("Error fetching players: \(error)")
                return
            }

            guard let documents = snapshot?.documents else {
                print("No player documents found")
                return
            }

            self.playerDocs = documents
            self.allPlayers = documents.compactMap { Player(from: $0) }
            self.players = self.allPlayers

            DispatchQueue.main.async {
                self.tableView.reloadData()
            }
        }
    }


    // MARK: - TableView

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return players.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "PlayerCell", for: indexPath)
        let player = players[indexPath.row]
        cell.textLabel?.text = "\(player.name) - \(player.position)"
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        performSegue(withIdentifier: "editPlayer", sender: indexPath)
    }

    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            let player = players[indexPath.row]
            let docID = playerDocs[indexPath.row].documentID

            let alert = UIAlertController(title: "Delete \(player.name)?", message: nil, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Delete", style: .destructive) { _ in
                Firestore.firestore().collection("teams").document(self.teamName!).collection("players").document(docID).delete { error in
                    if let error = error {
                        self.showError("Delete failed: \(error.localizedDescription)")
                    } else {
                        self.fetchPlayers()
                    }
                }
            })
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
            present(alert, animated: true)
        }
    }

    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        players = searchText.isEmpty ? allPlayers :
            allPlayers.filter { $0.name.lowercased().contains(searchText.lowercased()) || $0.position.lowercased().contains(searchText.lowercased()) }
        tableView.reloadData()
    }

    // MARK: - Navigation

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "editPlayer",
           let destinationVC = segue.destination as? EditPlayerViewController,
           let indexPath = sender as? IndexPath {
            destinationVC.player = players[indexPath.row]
            destinationVC.teamName = teamName
            destinationVC.documentID = playerDocs[indexPath.row].documentID
        } else if segue.identifier == "addPlayer",
                  let destinationVC = segue.destination as? AddPlayerViewController {
            destinationVC.teamName = teamName
        }
    }

    func showError(_ message: String) {
        let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}
