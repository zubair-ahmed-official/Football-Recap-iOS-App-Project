import UIKit

/// Shows each team’s individual goal totals
class TeamGoalsViewController: UIViewController {
    @IBOutlet weak var tableView: UITableView!
    var match: MatchHistory!

    // Injected by MatchDetailsVC
    var team1:   String = ""
    var team2:   String = ""
    var actions: [[String:Any]] = []

    // computed:
    private var goalsByTeam = [String: [(player:String, count:Int)]]()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Player Goals by Team"
        tableView.dataSource = self
        tallyGoals()
    }

    private func tallyGoals() {
        // tally goals per player per team
        var tmp = [String:[String:Int]]()
        tmp[team1] = [:]
        tmp[team2] = [:]

        for a in actions {
            guard
              let type   = a["type"]   as? String, type == "Goal",
              let player = a["player"] as? String,
              let team   = a["team"]   as? String
            else { continue }

            tmp[team]?[player, default:0] += 1
        }

        // sort descending
        goalsByTeam[team1] = tmp[team1]!
          .map { ($0.key,$0.value) }
          .sorted { $0.1 > $1.1 }

        goalsByTeam[team2] = tmp[team2]!
          .map { ($0.key,$0.value) }
          .sorted { $0.1 > $1.1 }
    }
}

extension TeamGoalsViewController: UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int { 2 }

    func tableView(_ tableView: UITableView,
                   titleForHeaderInSection section: Int) -> String? {
        return section == 0 ? "\(team1) Scorers" : "\(team2) Scorers"
    }

    func tableView(_ tableView: UITableView,
                   numberOfRowsInSection section: Int) -> Int {
        let team = section == 0 ? team1 : team2
        return goalsByTeam[team]?.count ?? 0
    }

    func tableView(_ tableView: UITableView,
                   cellForRowAt indexPath: IndexPath)
                   -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(
           withIdentifier: "GoalCell", for: indexPath)

        let team = indexPath.section == 0 ? team1 : team2
        let (player, count) = goalsByTeam[team]![indexPath.row]

        cell.textLabel?.text       = player
        cell.detailTextLabel?.text = "Goals: \(count)"
        return cell
    }
}
