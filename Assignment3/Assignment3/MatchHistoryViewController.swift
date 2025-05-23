import UIKit
import FirebaseFirestore

struct MatchHistory {
    var id: String
    var team1: String
    var team2: String
    var score: [String: Int]
    var winner: String
    var actions: [[String: Any]]
}

class MatchHistoryViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {

    @IBOutlet weak var tableView: UITableView!

    var matches: [MatchHistory] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.rowHeight = 100.0
        tableView.dataSource = self
        tableView.delegate = self
        fetchHistory()
    }

    func fetchHistory() {
        Firestore.firestore().collection("match_history").getDocuments { snapshot, error in
            guard let documents = snapshot?.documents else { return }

            self.matches = documents.compactMap { doc in
                let data = doc.data()
                let team1 = data["team1"] as? String ?? ""
                let team2 = data["team2"] as? String ?? ""
                let score = data["score"] as? [String: Int] ?? [:]
                let actions = data["actions"] as? [[String: Any]] ?? []

                let t1Score = score[team1] ?? 0
                let t2Score = score[team2] ?? 0
                let winner = t1Score > t2Score ? team1 : (t2Score > t1Score ? team2 : "Draw")

                return MatchHistory(id: doc.documentID, team1: team1, team2: team2, score: score, winner: winner, actions: actions)
            }

            DispatchQueue.main.async {
                self.tableView.reloadData()
            }
        }
    }

    // MARK: - Table View

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return matches.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let match = matches[indexPath.row]
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: "historyCell")

        let t1Score = match.score[match.team1] ?? 0
        let t2Score = match.score[match.team2] ?? 0

        cell.textLabel?.text = "\(match.team1) vs \(match.team2)"
        cell.detailTextLabel?.text = "Score: \(t1Score) - \(t2Score) | Winner: \(match.winner)"
        cell.detailTextLabel?.textColor = (match.winner == "Draw") ? .gray : .systemGreen
        cell.detailTextLabel?.font = UIFont.boldSystemFont(ofSize: 13)

        // Add View Details button
        let detailsButton = UIButton(type: .system)
        detailsButton.setTitle("View Details", for: .normal)
        detailsButton.tag = indexPath.row
        detailsButton.addTarget(self, action: #selector(viewDetailsTapped(_:)), for: .touchUpInside)
        detailsButton.frame = CGRect(x: cell.contentView.frame.width - 130, y: 10, width: 110, height: 30)
        detailsButton.autoresizingMask = [.flexibleLeftMargin]
        cell.contentView.addSubview(detailsButton)
        
        let wormButton = UIButton(type: .system)
        wormButton.setTitle("Worm Graph", for: .normal)
        wormButton.tag = indexPath.row
        wormButton.addTarget(self, action: #selector(viewWormGraphTapped(_:)), for: .touchUpInside)
        wormButton.frame = CGRect(x: cell.contentView.frame.width - 130, y: 45, width: 110, height: 30)
        wormButton.autoresizingMask = [.flexibleLeftMargin]
        cell.contentView.addSubview(wormButton)


        return cell
    }
    
    @objc func viewWormGraphTapped(_ sender: UIButton) {
        let match = matches[sender.tag]
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        if let wormVC = storyboard.instantiateViewController(withIdentifier: "WormGraphViewController") as? WormGraphViewController {
            wormVC.actions = match.actions
            wormVC.team1 = match.team1
            wormVC.team2 = match.team2
            navigationController?.pushViewController(wormVC, animated: true)
        }
    }
    
    @objc private func viewDetailsTapped(_ sender: UIButton) {
            let match = matches[sender.tag]
            performSegue(withIdentifier: "ShowMatchDetailsSegue", sender: match)
        }

        override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
            if segue.identifier == "ShowMatchDetailsSegue",
               let detailsVC = segue.destination as? MatchDetailsViewController,
               let match = sender as? MatchHistory {
                detailsVC.match = match
            }
        }


//    @objc func viewDetailsTapped(_ sender: UIButton) {
//            let match = matches[sender.tag]
//            let team1 = match.team1
//            let team2 = match.team2
//            let score1 = match.score[team1] ?? 0
//            let score2 = match.score[team2] ?? 0
//
//            // Separate actions into goals vs others
//            let goals = match.actions.filter { ($0["type"] as? String) == "Goal" }
//            let others = match.actions.filter { ($0["type"] as? String) != "Goal" }
//
//            var message = "\(team1): \(score1)\n\(team2): \(score2)\nWinner: \(match.winner)\n\n"
//
//            message += "Goals:\n"
//            if goals.isEmpty {
//                message += "None\n"
//            } else {
//                for action in goals {
//                    let type = action["type"] as? String ?? "-"
//                    let player = action["player"] as? String ?? "-"
//                    let time = action["matchTime"] as? String ?? "-"
//                    message += "\(time) - \(player)\n"
//                }
//            }
//
//            message += "\nOther Actions:\n"
//            if others.isEmpty {
//                message += "None"
//            } else {
//                for action in others {
//                    let type = action["type"] as? String ?? "-"
//                    let player = action["player"] as? String ?? "-"
//                    let time = action["matchTime"] as? String ?? "-"
//                    message += "\(time) - \(type) by \(player)\n"
//                }
//            }
//
//            showAlert(title: "Match Details", message: message)
//        }


    func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Close", style: .default))
        present(alert, animated: true)
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        // Optional: disable row tap
        tableView.deselectRow(at: indexPath, animated: true)
    }
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let deleteAction = UIContextualAction(style: .destructive, title: "Delete") { (_, _, completionHandler) in
            let match = self.matches[indexPath.row]

            // Delete from Firestore
            Firestore.firestore().collection("match_history").document(match.id).delete { error in
                if let error = error {
                    print("❌ Error deleting match: \(error.localizedDescription)")
                } else {
                    // Remove from local array and update table
                    self.matches.remove(at: indexPath.row)
                    tableView.deleteRows(at: [indexPath], with: .fade)
                }
            }

            completionHandler(true)
        }

        return UISwipeActionsConfiguration(actions: [deleteAction])
    }

}
