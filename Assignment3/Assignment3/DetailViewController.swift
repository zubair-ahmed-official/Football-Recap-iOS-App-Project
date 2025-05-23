//
//  DetailViewController.swift
//  Assignment3
//
//  Created by mobiledev on 5/5/2025.
//

import UIKit
import FirebaseFirestore



class DetailViewController: UIViewController {
    @IBOutlet var dateLabel: UITextField!
    
    @IBOutlet var team1Label: UITextField!
    @IBOutlet var team2Label: UITextField!
    
    let team1Picker = UIPickerView()
    let team2Picker = UIPickerView()
    var teamList: [String] = []
    
    @IBOutlet var timeLabel: UITextField!
    @IBOutlet var locationLabel: UITextField!
    @IBOutlet var statusLabel: UITextField!
    var match : Match?
    var matchIndex : Int?

    override func viewDidLoad() {
        super.viewDidLoad()
        
        if let displayMatch = match {
            self.navigationItem.title = "\(displayMatch.team1) vs \(displayMatch.team2)"
            
            team1Label.text = displayMatch.team1
            team2Label.text = displayMatch.team2
            dateLabel.text = displayMatch.date
            timeLabel.text = displayMatch.time
            locationLabel.text = displayMatch.location
            statusLabel.text = displayMatch.status
        }
        
    }
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        reloadMatchStatus()
    }
    func reloadMatchStatus() {
        guard let docID = match?.documentID else { return }
        Firestore.firestore().collection("matches").document(docID).getDocument { snapshot, error in
            if let data = snapshot?.data(), let updatedStatus = data["status"] as? String {
                DispatchQueue.main.async {
                    self.statusLabel.text = updatedStatus
                    self.match?.status = updatedStatus
                }
            }
        }
    }

    
    @IBAction func onSave(_ sender: Any)
    {
        //(sender as! UIBarButtonItem).title = "Loading..."

        let db = Firestore.firestore()

        match!.date = dateLabel.text!
        match!.location = locationLabel.text!
        match!.status = statusLabel.text!
        
        guard let team1 = team1Label.text, !team1.isEmpty,
              let team2 = team2Label.text, !team2.isEmpty else {
            showAlert("Please enter both Team 1 and Team 2.")
            return
        }

        if team1.lowercased() == team2.lowercased() {
            showAlert("Team 1 and Team 2 must be different.")
            return
        }

        match!.team1 = team1
        match!.team2 = team2

        
        match!.time = timeLabel.text!
        //good code would check this is a float
        do
        {
            //update the database (code from lectures)
            try db.collection("matches").document(match!.documentID!).setData(from: match!){ err in
                if let err = err {
                    print("Error updating document: \(err)")
                } else {
                    print("Document successfully updated")
                    //this code triggers the unwind segue manually
                    self.performSegue(withIdentifier: "saveSegue", sender: sender)
                }
            }
        } catch { print("Error updating document \(error)") } //note "error" is a magic variable
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let destinationVC = segue.destination as? TeamMembersViewController,
           let match = match {
            if segue.identifier == "showTeam1Members" {
                destinationVC.teamName = match.team1
            } else if segue.identifier == "showTeam2Members" {
                destinationVC.teamName = match.team2
            }
        }
        
        if segue.identifier == "showRecordActions",
               let destinationVC = segue.destination as? RecordActionsViewController {

                destinationVC.team1 = team1Label.text ?? "Unknown"
                destinationVC.team2 = team2Label.text ?? "Unknown"
            destinationVC.matchDocumentID = match?.documentID
            }
    }
    
    
    
    func showAlert(_ message: String) {
        let alert = UIAlertController(title: "Invalid Input", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }






    

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}
