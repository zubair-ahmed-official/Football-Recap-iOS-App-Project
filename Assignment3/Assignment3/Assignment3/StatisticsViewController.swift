//  StatisticsViewController.swift
//  Team and Player Comparison

import UIKit
import FirebaseFirestore

struct TeamActionStat {
    var team: String
    var actionType: String
    var count: Int
}

struct PlayerActionStat {
    var player: String
    var actionType: String
    var count: Int
}

class StatisticsViewController: UIViewController, UIPickerViewDelegate, UIPickerViewDataSource, UITableViewDataSource {

    // MARK: - IBOutlets
    @IBOutlet weak var team1Picker: UIPickerView!
    @IBOutlet weak var team2Picker: UIPickerView!
    @IBOutlet weak var player1Picker: UIPickerView!
    @IBOutlet weak var player2Picker: UIPickerView!
    @IBOutlet weak var teamStatsTable: UITableView!
    @IBOutlet weak var playerStatsTable: UITableView!

    // MARK: - Properties
    var teamList: [String] = ["Select Team"]
    var playerList1: [String] = []
    var playerList2: [String] = []

    var selectedTeam1: String = ""
    var selectedTeam2: String = ""
    var selectedPlayer1: String = ""
    var selectedPlayer2: String = ""

    var teamStats: [TeamActionStat] = []
    var playerStats: [PlayerActionStat] = []

    enum ComparisonMode {
        case team, player
    }

    var comparisonMode: ComparisonMode = .team

    override func viewDidLoad() {
        super.viewDidLoad()

        team1Picker.delegate = self
        team2Picker.delegate = self
        player1Picker.delegate = self
        player2Picker.delegate = self

        team1Picker.dataSource = self
        team2Picker.dataSource = self
        player1Picker.dataSource = self
        player2Picker.dataSource = self
        teamStatsTable.dataSource = self
        playerStatsTable.dataSource = self

        fetchTeams()
    }

    func fetchTeams() {
        Firestore.firestore().collection("teams").getDocuments { snapshot, error in
            guard let docs = snapshot?.documents else { return }
            let names = docs.map { $0.documentID }
            self.teamList.append(contentsOf: names)
            DispatchQueue.main.async {
                self.team1Picker.reloadAllComponents()
                self.team2Picker.reloadAllComponents()
            }
        }
    }

    func fetchPlayers(for team: String, completion: @escaping ([String]) -> Void) {
        Firestore.firestore().collection("teams").document(team).collection("players").getDocuments { snapshot, error in
            guard let documents = snapshot?.documents else {
                completion(["Select Player"]) // fallback
                return
            }
            var names = documents.compactMap { $0.data()["name"] as? String }
            names.insert("Select Player", at: 0)
            completion(names)
        }
    }


    @IBAction func compareTeamsTapped(_ sender: UIButton) {
        guard selectedTeam1 != "" && selectedTeam2 != "" && selectedTeam1 != "Select Team" && selectedTeam2 != "Select Team" else { return }

        compareTeamStats(team1: selectedTeam1, team2: selectedTeam2)
        fetchPlayers(for: selectedTeam1) { players in
            self.playerList1 = players
            self.selectedPlayer1 = "" // Reset selection
            DispatchQueue.main.async { self.player1Picker.reloadAllComponents() }
        }

        fetchPlayers(for: selectedTeam2) { players in
            self.playerList2 = players
            self.selectedPlayer2 = "" // Reset selection
            DispatchQueue.main.async { self.player2Picker.reloadAllComponents() }
        }

    }

    @IBAction func comparePlayersTapped(_ sender: UIButton) {
        guard selectedPlayer1 != "", selectedPlayer2 != "" else { return }
        comparePlayerStats(player1: selectedPlayer1, player2: selectedPlayer2)
    }

    func compareTeamStats(team1: String, team2: String) {
        let db = Firestore.firestore()
        teamStats = []
        let teams = [team1, team2]
        let collections = ["match_history", "live_matches"]

        var tempStats: [String: [String: Int]] = [:]

        let group = DispatchGroup()
        for collection in collections {
            group.enter()
            db.collection(collection).getDocuments { snapshot, error in
                if let documents = snapshot?.documents {
                    for doc in documents {
                        if let actions = doc.data()["actions"] as? [[String: Any]] {
                            for action in actions {
                                guard let team = action["team"] as? String, teams.contains(team),
                                      let type = action["type"] as? String else { continue }
                                tempStats[team, default: [:]][type, default: 0] += 1
                            }
                        }
                    }
                }
                group.leave()
            }
        }

        group.notify(queue: .main) {
            self.teamStats = []
            for (team, types) in tempStats {
                for (type, count) in types {
                    self.teamStats.append(TeamActionStat(team: team, actionType: type, count: count))
                }
            }
            self.teamStatsTable.reloadData()
        }
    }

    func comparePlayerStats(player1: String, player2: String) {
        let db = Firestore.firestore()
        playerStats = []
        let players = [player1, player2]
        let collections = ["match_history", "live_matches"]
        
        var tempStats: [String: [String: Int]] = [:]
        let group = DispatchGroup()
        
        for collection in collections {
            group.enter()
            db.collection(collection).getDocuments { snapshot, error in
                if let documents = snapshot?.documents {
                    for doc in documents {
                        if let actions = doc.data()["actions"] as? [[String: Any]] {
                            for action in actions {
                                guard let player = action["player"] as? String, players.contains(player),
                                      let type = action["type"] as? String else { continue }
                                tempStats[player, default: [:]][type, default: 0] += 1
                            }
                        }
                    }
                }
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            if tempStats.isEmpty {
                let alert = UIAlertController(
                    title: "No Data",
                    message: "There are no actions to compare for the selected players.",
                    preferredStyle: .alert)
                alert.addAction(.init(title: "OK", style: .default))
                self.present(alert, animated: true)
            } else {
                // Build your PlayerActionStat array as before
                self.playerStats = []
                for (player, types) in tempStats {
                    for (type, count) in types {
                        self.playerStats.append(PlayerActionStat(player: player, actionType: type, count: count))
                    }
                }
                self.playerStatsTable.reloadData()
            }
        }
    }

    // MARK: - PickerView
    func numberOfComponents(in pickerView: UIPickerView) -> Int { return 1 }

    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        switch pickerView {
        case team1Picker, team2Picker: return teamList.count
        case player1Picker: return playerList1.count
        case player2Picker: return playerList2.count
        default: return 0
        }
    }

    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        switch pickerView {
        case team1Picker, team2Picker: return teamList[row]
        case player1Picker: return playerList1[row]
        case player2Picker: return playerList2[row]
        default: return nil
        }
    }

    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        switch pickerView {
        case player1Picker:
            selectedPlayer1 = row == 0 ? "" : playerList1[row]
        case player2Picker:
            selectedPlayer2 = row == 0 ? "" : playerList2[row]
        case team1Picker:
            selectedTeam1 = teamList[row]
        case team2Picker:
            selectedTeam2 = teamList[row]
        default:
            break
        }
    }


    // MARK: - TableView
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if tableView == teamStatsTable {
            let allActionTypes = Set(teamStats.map { $0.actionType })
            return allActionTypes.count
        } else {
            let allActionTypes = Set(playerStats.map { $0.actionType })
            return allActionTypes.count
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: "statCell")
        cell.textLabel?.numberOfLines = 1
        cell.detailTextLabel?.numberOfLines = 2

        if tableView == teamStatsTable {
            let allActionTypes = Set(teamStats.map { $0.actionType })
            let actionType = Array(allActionTypes.sorted())[indexPath.row]
            let count1 = teamStats.first(where: { $0.team == selectedTeam1 && $0.actionType == actionType })?.count ?? 0
            let count2 = teamStats.first(where: { $0.team == selectedTeam2 && $0.actionType == actionType })?.count ?? 0

            cell.textLabel?.text = actionType
            cell.detailTextLabel?.text = "\(selectedTeam1): \(count1)\n\(selectedTeam2): \(count2)"
        } else {
            let allActionTypes = Set(playerStats.map { $0.actionType })
            let actionType = Array(allActionTypes.sorted())[indexPath.row]
            let count1 = playerStats.first(where: { $0.player == selectedPlayer1 && $0.actionType == actionType })?.count ?? 0
            let count2 = playerStats.first(where: { $0.player == selectedPlayer2 && $0.actionType == actionType })?.count ?? 0

            cell.textLabel?.text = actionType
            cell.detailTextLabel?.text = "\(selectedPlayer1): \(count1)\n\(selectedPlayer2): \(count2)"
        }

        return cell
    }

}
