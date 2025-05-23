//  RecordActionsViewController.swift
//  Updated with goal tracking and match control enhancements

import UIKit
import FirebaseFirestore
import MessageUI
import Charts
import DGCharts

class RecordActionsViewController: UIViewController, UITableViewDataSource,ChartViewDelegate, UIPickerViewDelegate, UIPickerViewDataSource, UINavigationControllerDelegate, MFMessageComposeViewControllerDelegate, MFMailComposeViewControllerDelegate {

    // MARK: - IBOutlets
    @IBOutlet weak var teamSelector: UISegmentedControl!
    @IBOutlet weak var actionSegment1: UISegmentedControl!
    @IBOutlet weak var actionSegment2: UISegmentedControl!
    @IBOutlet weak var playerPicker: UIPickerView!
    @IBOutlet weak var team1ScoreLabel: UILabel!
    @IBOutlet weak var team2ScoreLabel: UILabel!
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var timerLabel: UILabel!
    @IBOutlet weak var startMatchButton: UIButton!
    @IBOutlet weak var stopMatchButton: UIButton!
    @IBOutlet weak var lineChartView: LineChartView!
    

    // MARK: - Properties
    var matchID: String?
    var matchData: [String: Any] = [:]
    var actions: [[String: Any]] = []
    
    var playerCountries: [String: String] = [:]

    var team1: String = ""
    var team2: String = ""
    var selectedTeam = ""
    var players: [Player] = []
    var playerNames: [String] = []
    var selectedPlayer: String = ""
    var selectedActionType: String = "Goal"

    var matchTimer: Timer?
    var secondsElapsed: Int = 0
    var matchDocumentID: String?
    var viewIsReady: Bool = false
    var isMatchActive: Bool = false
    var hasHadHalfTime: Bool = false


    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        self.navigationItem.hidesBackButton = true
        let customBackButton = UIBarButtonItem(title: "Save", style: .plain, target: self, action: #selector(backButtonTapped))
        self.navigationItem.leftBarButtonItem = customBackButton

        playerPicker.delegate = self
        playerPicker.dataSource = self
        tableView.dataSource = self
        lineChartView.delegate = self
        
        stopMatchButton.isEnabled = false
        startMatchButton.isEnabled = true

        teamSelector.setTitle(team1, forSegmentAt: 0)
        teamSelector.setTitle(team2, forSegmentAt: 1)
        teamSelector.selectedSegmentIndex = 0
        selectedTeam = team1

        fetchPlayers(for: selectedTeam)
        viewIsReady = true
        lineChartView.isHidden = true
        
        fetchPlayerCountries {
                print("player → country map:", self.playerCountries)
            }
        
        let leaderboardButton = UIBarButtonItem(
                title: "Leaderboard",
                style: .plain,
                target: self,
                action: #selector(showLeaderboardScreen)
            )
            if var items = navigationItem.rightBarButtonItems {
                items.append(leaderboardButton)
                navigationItem.rightBarButtonItems = items
            } else {
                navigationItem.rightBarButtonItem = leaderboardButton
            }
    }
    
    @objc func showLeaderboardScreen() {
        performSegue(withIdentifier: "ShowLeaderboard", sender: self)
    }

    
    // Update worm chart
    func updateWormChart() {
        var score = [team1: 0, team2: 0]
        var marginOverTime: [ChartDataEntry] = []

        // Set constant height for team intro bars
        let barHeight = 9.0

        // Add starting vertical bars (just to indicate team colors)
        let teamAStart = ChartDataEntry(x: 0.0, y: barHeight)
        let teamBStart = ChartDataEntry(x: 0.0, y: -barHeight)

        // Build the worm graph data entries
        for action in actions {
            if let type = action["type"] as? String, type == "Goal",
               let team = action["team"] as? String,
               let time = action["matchTime"] as? String {
                
                let components = time.split(separator: ":")
                if components.count == 2, let min = Int(components[0]), let sec = Int(components[1]) {
                    score[team, default: 0] += 1
                    let margin = Double(score[team1, default: 0] - score[team2, default: 0])
                    let totalSeconds = Double(min * 60 + sec)
                    
                    // Make the line "step" horizontally before rising/falling
                    if let last = marginOverTime.last {
                        marginOverTime.append(ChartDataEntry(x: totalSeconds, y: last.y))
                    }
                    marginOverTime.append(ChartDataEntry(x: totalSeconds, y: margin))
                }
            }
        }

        // Team A entry
        let teamASet = LineChartDataSet(entries: [
            ChartDataEntry(x: 0.0, y: 0.0),
            teamAStart
        ], label: team1)
        teamASet.setColor(.systemRed)
        teamASet.lineWidth = 6
        teamASet.drawCirclesEnabled = false
        teamASet.drawValuesEnabled = false
        teamASet.mode = .horizontalBezier

        // Team B entry
        let teamBSet = LineChartDataSet(entries: [
            ChartDataEntry(x: 0.0, y: 0.0),
            teamBStart
        ], label: team2)
        teamBSet.setColor(.systemBlue)
        teamBSet.lineWidth = 6
        teamBSet.drawCirclesEnabled = false
        teamBSet.drawValuesEnabled = false
        teamBSet.mode = .horizontalBezier

        // Margin worm line
        let wormSet = LineChartDataSet(entries: marginOverTime, label: "Score Margin")
        wormSet.setColor(.systemRed)
        wormSet.lineWidth = 2
        wormSet.drawCirclesEnabled = false
        wormSet.drawValuesEnabled = false
        wormSet.mode = .stepped

        // Combine into one chart
        let data = LineChartData(dataSets: [teamASet, teamBSet, wormSet])
        lineChartView.data = data

        // Chart styling
        lineChartView.chartDescription.text = "Score Margin (Worm Graph)"
        lineChartView.xAxis.labelPosition = .bottom
        lineChartView.leftAxis.axisMinimum = -10
        lineChartView.leftAxis.axisMaximum = 10
        lineChartView.rightAxis.enabled = false
        lineChartView.legend.enabled = true
        lineChartView.notifyDataSetChanged()
        lineChartView.isHidden = false
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
      if segue.identifier == "ShowLeaderboard",
         let vc = segue.destination as? LeaderboardViewController {
        // pass along the raw actions array, current teams, etc.
        vc.actions         = self.actions
        vc.team1           = self.team1
        vc.team2           = self.team2
        vc.playerCountries = self.playerCountries
      }
    }
    
//    @objc func showLeaderboard() {
//            var goalCount = [String: Int]()
//            var foulCount = [String: Int]()
//            for action in actions {
//                let type = action["type"] as? String ?? ""
//                let player = action["player"] as? String ?? ""
//                if type == "Goal" {
//                    goalCount[player, default: 0] += 1
//                } else if type == "Foul" {
//                    foulCount[player, default: 0] += 1
//                }
//            }
//            let topGoals = goalCount.sorted { $0.value > $1.value }.prefix(3)
//            let topFouls = foulCount.sorted { $0.value > $1.value }.prefix(3)
//            var msg = "Top Scorers:\n"
//            topGoals.forEach { player, count in
//                let country = playerCountries[player] ?? "Unknown"
//                msg += "\(player) (\(country)): \(count)\n"
//            }
//            msg += "\nTop Foul Makers:\n"
//            topFouls.forEach { player, count in
//                let country = playerCountries[player] ?? "Unknown"
//                msg += "\(player) (\(country)): \(count)\n"
//            }
//            let alert = UIAlertController(title: "Leaderboard", message: msg, preferredStyle: .alert)
//            alert.addAction(UIAlertAction(title: "OK", style: .default))
//            present(alert, animated: true)
//        }
    
    @objc func chartValueSelected(_ chartView: ChartViewBase, entry: ChartDataEntry, highlight: Highlight) {
            let timeSec = Int(entry.x)
            let margin = Int(entry.y)
            var aScore = 0, bScore = 0
            for action in actions {
                if let type = action["type"] as? String, type == "Goal",
                   let team = action["team"] as? String,
                   let t = action["matchTime"] as? String {
                    let parts = t.split(separator: ":")
                    if parts.count == 2, let m = Int(parts[0]), let s = Int(parts[1]) {
                        let tSecA = m * 60 + s
                        if tSecA <= timeSec {
                            if team == team1 { aScore += 1 } else if team == team2 { bScore += 1 }
                        }
                    }
                }
            }
            let mins = timeSec / 60, secs = timeSec % 60
            let title = String(format: "%02d:%02d", mins, secs)
            let msg = "\(team1): \(aScore)\n\(team2): \(bScore)\nMargin: \(margin)"
            let alert = UIAlertController(title: title, message: msg, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
        }



    // MARK: - Match Controls
    @objc func backButtonTapped() {
        let alert = UIAlertController(title: "Save the record?", message: "Do you want to stop and save the match record before leaving?", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Yes", style: .default) { _ in
            self.stopMatchTapped(UIButton())
            self.navigationController?.popViewController(animated: true)
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }

    func showMatchNotStartedAlert() {
        let alert = UIAlertController(title: "Start the Match", message: "You must start the match before performing this action.", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    @IBAction func startMatchTapped(_ sender: UIButton) {
        let db = Firestore.firestore()
        

        if let existingID = matchID {
            guard matchTimer == nil else { return }
            db.collection("live_matches").document(existingID).getDocument { snapshot, error in
                if let doc = snapshot, let data = doc.data() {
                    let savedScore = data["score"] as? [String: Int] ?? [self.team1: 0, self.team2: 0]
                    self.matchData["score"] = savedScore
                    self.updateScoreLabels(with: savedScore)
                    self.isMatchActive = true

                    self.matchTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                        self.secondsElapsed += 1
                        self.updateTimerLabel()
                        if self.secondsElapsed >= 50 {
                            self.endMatchDueToTimeout()
                        }
                    }

                    self.startMatchButton.isEnabled = false
                    self.stopMatchButton.isEnabled = true
                }
            }
            return
        }

        let ref = db.collection("live_matches").document()
        matchID = ref.documentID

        let now = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yyyy HH:mm"
        let dateTime = formatter.string(from: now).components(separatedBy: " ")

        let match: [String: Any] = [
            "date": dateTime[0],
            "time": dateTime[1],
            "team1": team1,
            "team2": team2,
            "score": [team1: 0, team2: 0],
            "location": "Melbourne",
            "isActive": true,
            "actions": []
        ]

        matchData = match
        ref.setData(match)

        secondsElapsed = 0
        timerLabel.text = "00:00"
        isMatchActive = true
        matchTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            self.secondsElapsed += 1
            self.updateTimerLabel()

            // Half-time at 25s
            if self.secondsElapsed == 25 && !self.hasHadHalfTime {
                self.hasHadHalfTime = true
                self.matchTimer?.invalidate()
                self.matchTimer = nil
                self.isMatchActive = false
                self.showHalfTimeAlert()
                return
            }

            // Full-time at 50s
            if self.secondsElapsed >= 50 {
                self.endMatchDueToTimeout()
            }
        }


        startMatchButton.isEnabled = false
        stopMatchButton.isEnabled = true
        actions.removeAll()
        tableView.reloadData()
    }
    
    func showHalfTimeAlert() {
        self.isMatchActive = false
        let alert = UIAlertController(title: "Half Time", message: "Half time is over. Press Start Match to resume the second half.", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)

        startMatchButton.isEnabled = true
        stopMatchButton.isEnabled = false
    }


    func endMatchDueToTimeout() {
        matchTimer?.invalidate()
        matchTimer = nil
        isMatchActive = false
        startMatchButton.isEnabled = false
        stopMatchButton.isEnabled = false
        showMatchEndedAlert()
        stopMatchTapped(UIButton())
    }

    func showMatchEndedAlert() {
        let alert = UIAlertController(title: "Full Time", message: "90 minutes game is over.", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    @IBAction func stopMatchTapped(_ sender: UIButton) {
        guard let matchID = matchID, !matchID.isEmpty else { return }

        startMatchButton.isEnabled = true
        stopMatchButton.isEnabled = false
        matchTimer?.invalidate()
        matchTimer = nil

        let db = Firestore.firestore()
        if let docID = matchDocumentID, !docID.isEmpty {
            db.collection("matches").document(docID).updateData(["status": "Match Done"])
        }

        db.collection("live_matches").document(matchID).getDocument { snapshot, error in
            if let data = snapshot?.data() {
                db.collection("match_history").document(matchID).setData(data) { err in
                    if err == nil {
                        db.collection("live_matches").document(matchID).updateData(["isActive": false])
                        // ✅ Now mark match as inactive
                        self.isMatchActive = false
                    }
                }
            } else {
                self.isMatchActive = false
            }
        }
    }


    @IBAction func recordActionTapped(_ sender: UIButton) {
        guard let matchID = matchID, !matchID.isEmpty else {
            showMatchNotStartedAlert()
            return
        }

        guard isMatchActive else {
            showInvalidActionAlert("You cannot record actions after the match has been stopped.")
            return
        }

        // Validate game logic based on previous action
        if let lastAction = actions.last {
            let lastType = lastAction["type"] as? String ?? ""
            let lastTeam = lastAction["team"] as? String ?? ""

            // ✅ Goal must follow Kick AND be by same team
            if selectedActionType == "Goal" {
                if lastType != "Kick" {
                    showInvalidActionAlert("A goal must follow a Kick.")
                    return
                }
                if lastTeam != selectedTeam {
                    showInvalidActionAlert("Goal must be scored by the same team that kicked.")
                    return
                }
                let lastPlayer = lastAction["player"] as? String ?? ""
                    if lastPlayer != selectedPlayer {
                        showInvalidActionAlert("Only the player who last kicked can score the goal. Others must kick first.")
                        return
                    }
            }

            // ✅ Penalty or Free Kick must follow Foul
            if selectedActionType == "Penalty" || selectedActionType == "Free Kick" || selectedActionType == "Yellow Card" || selectedActionType == "Red Card" {
                if lastType != "Foul" {
                    showInvalidActionAlert("Penalty and Free Kick must follow a Foul.")
                    return
                }
            }
        } else {
            // First action can't be Goal, Penalty or Free Kick
            if ["Goal", "Penalty", "Free Kick"].contains(selectedActionType) {
                showInvalidActionAlert("The first action must be a Kick.")
                return
            }
        }

        // Get current match time
        let minutes = self.secondsElapsed / 60
        let seconds = self.secondsElapsed % 60
        let matchTime = String(format: "%02d:%02d", minutes, seconds)

        // Create and append action
        let action: [String: Any] = [
            "type": selectedActionType,
            "player": selectedPlayer,
            "team": selectedTeam,
            "timestamp": Timestamp(date: Date()),
            "matchTime": matchTime
        ]

        actions.append(action)
        tableView.reloadData()

        let db = Firestore.firestore()
        db.collection("live_matches").document(matchID).updateData([
            "actions": FieldValue.arrayUnion([action])
        ])

        // Update score if action is a goal
        if selectedActionType == "Goal" {
            if var score = matchData["score"] as? [String: Int] {
                score[selectedTeam, default: 0] += 1
                matchData["score"] = score
                updateScoreLabels(with: score)
                db.collection("live_matches").document(matchID).updateData(["score": score])
            }
        }

        updateWormChart()
    }

    
    func showInvalidActionAlert(_ message: String) {
        let alert = UIAlertController(title: "Invalid Action", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }


    @IBAction func shareActionsTapped(_ sender: UIButton) {
        // Prepare JSON-safe actions array
        let safeActions = actions.map { action -> [String: Any] in
            [
                "type": action["type"] as? String ?? "",
                "player": action["player"] as? String ?? "",
                "team": action["team"] as? String ?? "",
                "matchTime": action["matchTime"] as? String ?? ""
            ]
        }

        // Gather match info
        let score = matchData["score"] as? [String: Int] ?? [:]
        let team1Score = score[team1] ?? 0
        let team2Score = score[team2] ?? 0
        let winner = team1Score > team2Score
            ? team1
            : (team2Score > team1Score ? team2 : "Draw")
        let date = matchData["date"] as? String ?? "Unknown"
        let time = matchData["time"] as? String ?? "Unknown"
        let location = matchData["location"] as? String ?? "Unknown"

        // Build JSON payload
        let payload: [String: Any] = [
            "summary": [
                "date": date,
                "sending time": time,
                "sent from": location,
                "scores": [team1: team1Score, team2: team2Score],
                "winner": winner
            ],
            "actions": safeActions
        ]

        // Serialize to JSON string
        let jsonString: String
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted])
            jsonString = String(data: jsonData, encoding: .utf8) ?? "{}"
        } catch {
            print("JSON serialization error: \(error)")
            jsonString = "{}"
        }

        // Share via Messages, Mail, or Activity
        if MFMessageComposeViewController.canSendText() {
            let messageVC = MFMessageComposeViewController()
            messageVC.body = jsonString
            messageVC.messageComposeDelegate = self
            present(messageVC, animated: true)
        } else if MFMailComposeViewController.canSendMail() {
            let mailVC = MFMailComposeViewController()
            mailVC.setSubject("Match Summary JSON")
            mailVC.setMessageBody(jsonString, isHTML: false)
            mailVC.mailComposeDelegate = self
            present(mailVC, animated: true)
        } else {
            let activityVC = UIActivityViewController(activityItems: [jsonString], applicationActivities: nil)
            present(activityVC, animated: true)
        }
    }


        // MARK: - Delegate methods
        func messageComposeViewController(_ controller: MFMessageComposeViewController, didFinishWith result: MessageComposeResult) {
            controller.dismiss(animated: true)
        }

        func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
            controller.dismiss(animated: true)
        }

    // MARK: - Helpers
    func updateScoreLabels(with score: [String: Int]) {
        team1ScoreLabel.text = "\(score[team1] ?? 0)"
        team2ScoreLabel.text = "\(score[team2] ?? 0)"
    }

    func updateTimerLabel() {
        let minutes = secondsElapsed / 60
        let seconds = secondsElapsed % 60
        timerLabel.text = String(format: "%02d:%02d", minutes, seconds)
    }

    func fetchPlayers(for team: String) {
        let db = Firestore.firestore()
        db.collection("teams").document(team).collection("players").getDocuments { snapshot, error in
            if let documents = snapshot?.documents {
                self.players = documents.compactMap { Player(from: $0) }
                self.playerNames = self.players.map { $0.name }
                self.selectedPlayer = self.playerNames.first ?? ""
                DispatchQueue.main.async {
                    self.playerPicker.reloadAllComponents()
                }
            }
        }
    }
    
    func fetchPlayerCountries(completion: @escaping () -> Void) {
        let db = Firestore.firestore()
        let teams = [team1, team2]
        let group = DispatchGroup()

        teams.forEach { team in
            group.enter()
            db.collection("teams")
              .document(team)
              .collection("players")
              .getDocuments { snapshot, error in
                if let docs = snapshot?.documents {
                    for doc in docs {
                        if let name = doc.data()["name"] as? String {
                            // country = the parent "team" doc ID
                            self.playerCountries[name] = team
                        }
                    }
                } else if let error = error {
                    print("❌ Failed to fetch players for team \(team): \(error)")
                }
                group.leave()
            }
        }

        group.notify(queue: .main) {
            completion()
        }
    }

                  
    
    // MARK: - UI Actions
    @IBAction func teamChanged(_ sender: UISegmentedControl) {
        guard viewIsReady else { return }
        guard let matchID = matchID, !matchID.isEmpty else {
            sender.selectedSegmentIndex = selectedTeam == team1 ? 0 : 1
            showMatchNotStartedAlert()
            return
        }
        selectedTeam = sender.selectedSegmentIndex == 0 ? team1 : team2
        fetchPlayers(for: selectedTeam)
    }

    @IBAction func actionSegment1Changed(_ sender: UISegmentedControl) {
        actionSegment2.selectedSegmentIndex = UISegmentedControl.noSegment
        selectedActionType = sender.titleForSegment(at: sender.selectedSegmentIndex) ?? "Unknown"
    }

    @IBAction func actionSegment2Changed(_ sender: UISegmentedControl) {
        actionSegment1.selectedSegmentIndex = UISegmentedControl.noSegment
        selectedActionType = sender.titleForSegment(at: sender.selectedSegmentIndex) ?? "Unknown"
    }

    // MARK: - TableView
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return actions.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell()
        let action = actions[indexPath.row]
        let type = action["type"] as? String ?? ""
        let player = action["player"] as? String ?? ""
        let team = action["team"] as? String ?? ""
        let time = action["matchTime"] as? String ?? ""
        cell.textLabel?.text = "\(time) - \(type) - \(player) (\(team))"
        return cell
    }

    // MARK: - PickerView
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }

    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return playerNames.count
    }

    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        return playerNames[row]
    }

    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        selectedPlayer = playerNames[row]
    }
}
