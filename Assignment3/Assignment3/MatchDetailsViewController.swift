import UIKit

class MatchDetailsViewController: UIViewController {
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var scoreLabel: UILabel!
    @IBOutlet weak var winnerLabel: UILabel!
    @IBOutlet weak var actionsTableView: UITableView!
    
    @IBAction func viewTeamGoalsTapped(_ sender: Any) {
            guard let vc = storyboard?
                    .instantiateViewController(identifier: "TeamGoalsViewController")
                    as? TeamGoalsViewController else { return }

            // pass along the two team names + the actions array
            vc.team1   = match.team1
            vc.team2   = match.team2
            vc.actions = match.actions

            navigationController?.pushViewController(vc, animated: true)
        }

    var match: MatchHistory!
    private var goals: [[String:String]] = []
    private var others: [[String:String]] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        titleLabel.text = "\(match.team1) vs \(match.team2)"
        let s1 = match.score[match.team1] ?? 0
        let s2 = match.score[match.team2] ?? 0
        scoreLabel.text = "Score: \(s1) - \(s2)"
        winnerLabel.text = "Winner: \(match.winner)"

        categorizeActions()
        actionsTableView.dataSource = self
    }
    
//    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
//      if segue.identifier == "showTeamGoals",
//         let dest = segue.destination as? TeamGoalsViewController {
//        dest.match = self.match
//      }
//    }


    private func categorizeActions() {
        goals.removeAll()
        others.removeAll()

        for action in match.actions {
            let type   = action["type"]      as? String ?? ""
            let player = action["player"]    as? String ?? ""
            let time   = action["matchTime"] as? String ?? ""
            let team   = action["team"]      as? String ?? ""

            // stash the team so we can show it behind the player
            let entry = [
              "type":  type,
              "player": player,
              "time":   time,
              "team":   team
            ]

            if type == "Goal" {
                goals.append(entry)
            } else {
                others.append(entry)
            }
        }
    }
}

extension MatchDetailsViewController: UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int { return 2 }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return section == 0 ? "Goals" : "Other Actions"
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return section == 0 ? goals.count : others.count
    }

    func tableView(_ tableView: UITableView,
                   cellForRowAt indexPath: IndexPath) -> UITableViewCell {

        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: "detailCell")
        let data = (indexPath.section == 0 ? goals : others)[indexPath.row]

        let time   = data["time"]!
        let type   = data["type"]!
        let player = data["player"]!
        let team   = data["team"]!

        // e.g. "00:22 - Goal"
        cell.textLabel?.text = "\(time) - \(type)"

        // now show "Player Name (Team)"
        cell.detailTextLabel?.text = "\(player) (\(team))"

        return cell
    }
}
