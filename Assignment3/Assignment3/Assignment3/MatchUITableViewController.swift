import UIKit
import Firebase
import FirebaseFirestore

class MatchUITableViewController: UITableViewController, UIPickerViewDelegate, UIPickerViewDataSource {

    var matches = [Match]()
    var teamList: [String] = []
    var selectedTeam1: String = ""
    var selectedTeam2: String = ""
    
//    @IBAction func showHistoryTapped(_ sender: UIButton) {
//        performSegue(withIdentifier: "showMatchHistory", sender: self)
//    }


    override func viewDidLoad() {
        super.viewDidLoad()

        let createMatchItem = UIBarButtonItem(
                title: "Create a Match",
                style: .plain,
                target: self,
                action: #selector(addMatchTapped)
            )

            // new “Teams” button
            let teamsItem = UIBarButtonItem(
                title: "Teams",
                style: .plain,
                target: self,
                action: #selector(showTeamsTapped)
            )

            navigationItem.rightBarButtonItems = [createMatchItem]
            navigationItem.leftBarButtonItems = [teamsItem]
        

        fetchTeamNames()

        let db = Firestore.firestore()
        db.collection("matches").getDocuments { (result, err) in
            if let err = err {
                print("Error getting documents: \(err)")
            } else {
                self.matches.removeAll()
                for document in result!.documents {
                    let conversionResult = Result {
                        try document.data(as: Match.self)
                    }
                    switch conversionResult {
                    case .success(let match):
                        self.matches.append(match)
                    case .failure(let error):
                        print("Error decoding match: \(error)")
                    }
                }
                self.tableView.reloadData()
            }
        }
    }
    
    @objc func showTeamsTapped() {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        guard let teamsVC = storyboard
            .instantiateViewController(withIdentifier: "TeamsListViewController")
            as? TeamsListViewController
        else { return }

        navigationController?.pushViewController(teamsVC, animated: true)
    }


    func fetchTeamNames() {
        Firestore.firestore().collection("teams").getDocuments { snapshot, error in
            if let error = error {
                print("❌ Error fetching teams: \(error)")
                return
            }
            self.teamList = snapshot?.documents.map { $0.documentID } ?? []
            self.selectedTeam1 = self.teamList.first ?? ""
            self.selectedTeam2 = self.teamList.count > 1 ? self.teamList[1] : self.selectedTeam1
        }
    }

    @objc func addMatchTapped() {
        let alert = UIAlertController(title: "Create Match", message: "Select Teams \n\n\n\n\n\n\n\n ", preferredStyle: .alert)

        let team1Picker = UIPickerView()
        let team2Picker = UIPickerView()
        team1Picker.tag = 1
        team2Picker.tag = 2
        team1Picker.delegate = self
        team1Picker.dataSource = self
        team2Picker.delegate = self
        team2Picker.dataSource = self

        alert.view.addSubview(team1Picker)
        alert.view.addSubview(team2Picker)
        team1Picker.frame = CGRect(x: 5, y: 50, width: alert.view.bounds.width - 20, height: 80)
        team2Picker.frame = CGRect(x: 5, y: 130, width: alert.view.bounds.width - 20, height: 80)

        alert.addTextField { $0.placeholder = "Date (e.g. 28/4/2025)" }
        alert.addTextField { $0.placeholder = "Time (e.g. 21:21)" }
        alert.addTextField { $0.placeholder = "Location" }

        let saveAction = UIAlertAction(title: "Save", style: .default) { _ in
            guard let date = alert.textFields?[0].text, !date.isEmpty,
                  let time = alert.textFields?[1].text, !time.isEmpty,
                  let location = alert.textFields?[2].text, !location.isEmpty else {
                self.showError("Please fill in all fields.")
                return
            }

            if self.selectedTeam1.lowercased() == self.selectedTeam2.lowercased() {
                self.showError("Team 1 and Team 2 must be different.")
                return
            }

            let newMatch = Match(date: date, location: location, status: "Upcoming", team1: self.selectedTeam1, team2: self.selectedTeam2, time: time)

            do {
                try Firestore.firestore().collection("matches").addDocument(from: newMatch) { error in
                    if let error = error {
                        self.showError("Failed to save match: \(error.localizedDescription)")
                    } else {
                        print("✅ Match added: \(newMatch)")
                        self.viewDidLoad()
                    }
                }
            } catch {
                self.showError("Encoding error: \(error.localizedDescription)")
            }
        }

        alert.addAction(saveAction)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }

    func showError(_ message: String) {
        let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    // MARK: - UIPickerView

    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }

    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return teamList.count
    }

    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        return teamList[row]
    }

    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        if pickerView.tag == 1 {
            selectedTeam1 = teamList[row]
        } else {
            selectedTeam2 = teamList[row]
        }
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return matches.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "MatchUITableViewCell", for: indexPath)

        let match = matches[indexPath.row]
        if let matchCell = cell as? MatchUITableViewCell {
            matchCell.dateLabel.text = match.date
            matchCell.locationLabel.text = match.location
            matchCell.statusLabel.text = match.status
            matchCell.team1Label.text = match.team1
            matchCell.team2Label.text = match.team2
            matchCell.timeLabel.text = match.time
        }

        return cell
    }
    
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            let matchToDelete = matches[indexPath.row]

            guard let documentID = matchToDelete.documentID else {
                print("❌ Cannot delete: match has no documentID")
                return
            }

            let db = Firestore.firestore()
            db.collection("matches").document(documentID).delete { error in
                if let error = error {
                    print("❌ Error deleting match: \(error.localizedDescription)")
                } else {
                    print("🗑️ Match deleted: \(documentID)")
                    self.matches.remove(at: indexPath.row)
                    tableView.deleteRows(at: [indexPath], with: .fade)
                }
            }
        }
    }


    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "ShowMatchDetailSegue" {
            guard let detailVC = segue.destination as? DetailViewController,
                  let selectedCell = sender as? MatchUITableViewCell,
                  let indexPath = tableView.indexPath(for: selectedCell) else {
                return
            }
            detailVC.match = matches[indexPath.row]
            detailVC.matchIndex = indexPath.row
        }
    }

    @IBAction func unwindToMatchList(sender: UIStoryboardSegue) {
        if let detailScreen = sender.source as? DetailViewController {
            matches[detailScreen.matchIndex!] = detailScreen.match!
            tableView.reloadData()
        }
    }

    @IBAction func unwindToMatchListWithCancel(sender: UIStoryboardSegue) {
        print("cancelled")
    }
}
