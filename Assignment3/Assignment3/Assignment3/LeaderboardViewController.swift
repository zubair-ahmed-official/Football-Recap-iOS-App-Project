//  LeaderboardViewController.swift
//  Displays Top Scorers, Top Foul Makers, and Match Summary Bands

import UIKit

/// Holds each player’s stats
struct PlayerStat {
    let name: String
    let country: String
    let goals: Int
    let fouls: Int
    let gpm: Double  // Goals per minute
    let fpm: Double  // Fouls per minute
}

class LeaderboardViewController: UIViewController {
    // MARK: - IBOutlets
    @IBOutlet weak var highestScoreLabel: UILabel!
    @IBOutlet weak var averageScoreLabel: UILabel!
    @IBOutlet weak var highActionTeamLabel: UILabel!
    @IBOutlet weak var tableView: UITableView!

    /// Passed in from RecordActionsVC
    var actions: [[String: Any]] = []
    var team1: String = ""
    var team2: String = ""
    var playerCountries: [String: String] = [:]

    /// Computed lists
    private var topScorers: [PlayerStat] = []
    private var topFoulers:  [PlayerStat] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Leaderboard"
        tableView.dataSource = self
        computeStats()
    }

    /// Count goals, fouls, compute rates, then populate top lists and summary labels
    private func computeStats() {
        var goalCount = [String: Int]()
        var foulCount = [String: Int]()
        var firstSec = Int.max
        var lastSec  = 0

        // Tally counts and record min/max timestamps
        for action in actions {
            guard let type   = action["type"] as? String,
                  let name   = action["player"] as? String,
                  let tString = action["matchTime"] as? String else { continue }
            let parts = tString.split(separator: ":").map(String.init)
            if parts.count == 2,
               let m = Int(parts[0]), let s = Int(parts[1]) {
                let sec = m * 60 + s
                firstSec = min(firstSec, sec)
                lastSec  = max(lastSec,  sec)
                if type == "Goal" { goalCount[name, default: 0] += 1 }
                if type == "Foul" { foulCount[name, default: 0] += 1 }
            }
        }

        let duration = max(1, lastSec - firstSec)
        let allPlayers = Set(goalCount.keys).union(foulCount.keys)

        // Build full stats, skip players with zero contributions
        let stats = allPlayers.compactMap { name -> PlayerStat? in
            let g = goalCount[name] ?? 0
            let f = foulCount[name] ?? 0
            guard g > 0 || f > 0 else { return nil }
            let c = playerCountries[name] ?? "Unknown"
            let gpm = Double(g) / Double(duration) * 60.0
            let fpm = Double(f) / Double(duration) * 60.0
            return PlayerStat(name: name, country: c, goals: g, fouls: f, gpm: gpm, fpm: fpm)
        }

        // Sort & pick top 3 scorers
        topScorers = stats
            .filter { $0.goals > 0 }
            .sorted { lhs, rhs in
                if lhs.goals != rhs.goals { return lhs.goals > rhs.goals }
                return lhs.gpm > rhs.gpm
            }
        if topScorers.count > 3 { topScorers = Array(topScorers.prefix(3)) }

        // Sort & pick top 3 foul makers
        topFoulers = stats
            .filter { $0.fouls > 0 }
            .sorted { lhs, rhs in
                if lhs.fouls != rhs.fouls { return lhs.fouls > rhs.fouls }
                return lhs.fpm > rhs.fpm
            }
        if topFoulers.count > 3 { topFoulers = Array(topFoulers.prefix(3)) }

        // Compute summary labels
        // Team goals
        let teamGoalCounts = actions
            .filter { ($0["type"] as? String) == "Goal" }
            .reduce(into: [String:Int]()) { counts, action in
                let team = action["team"] as? String ?? ""
                counts[team, default: 0] += 1
            }
        let t1Goals = teamGoalCounts[team1] ?? 0
        let t2Goals = teamGoalCounts[team2] ?? 0
        let highest = max(t1Goals, t2Goals)
        let average = Double(t1Goals + t2Goals) / 2.0

        highestScoreLabel.text = "Highest Score: \(highest)"
        averageScoreLabel.text = String(format: "Average Score: %.1f", average)

        // Team action counts
        let actionCounts = actions.reduce(into: [String:Int]()) { counts, action in
            let team = action["team"] as? String ?? ""
            counts[team, default: 0] += 1
        }
        let a1 = actionCounts[team1] ?? 0
        let a2 = actionCounts[team2] ?? 0
        let highTeam = a1 > a2 ? team1 : (a2 > a1 ? team2 : "Tie")
        highActionTeamLabel.text = "Most Actions: \(highTeam)"

        tableView.reloadData()
    }
}

// MARK: - UITableViewDataSource
extension LeaderboardViewController: UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int { return 2 }
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return section == 0 ? "Top Scorers" : "Top Foul Makers"
    }
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return section == 0 ? topScorers.count : topFoulers.count
    }
    func tableView(_ tableView: UITableView,
                   cellForRowAt indexPath: IndexPath)
                   -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "StatCell", for: indexPath)
        let ps = (indexPath.section == 0 ? topScorers[indexPath.row] : topFoulers[indexPath.row])

        // Player name (country)
        cell.textLabel?.text = "\(ps.name) (\(ps.country))"

        // Detail with per-minute rates
        if indexPath.section == 0 {
            cell.detailTextLabel?.text = String(format: "Goals: %d   G/Min: %.2f", ps.goals, ps.gpm)
        } else {
            cell.detailTextLabel?.text = String(format: "Fouls: %d   F/Min: %.2f", ps.fouls, ps.fpm)
        }

        return cell
    }
}
