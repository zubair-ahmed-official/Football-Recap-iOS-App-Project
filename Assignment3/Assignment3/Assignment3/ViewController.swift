//
//  ViewController.swift
//  Assignment3
//
//  Created by mobiledev on 5/5/2025.
//

import UIKit
import Firebase
import FirebaseFirestore
//import FirebaseFirestoreSwift



class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = "Matches"

        // Initialize Firestore
        let db = Firestore.firestore()
        print("\n✅ INITIALIZED FIRESTORE APP: \(db.app.name)\n")
        
        fetchMatches()
    }
   
    // 🔄 Fetch matches from Firestore
    func fetchMatches() {
        let db = Firestore.firestore()
        db.collection("matches").getDocuments { snapshot, error in
            if let error = error {
                print("❌ Error getting matches: \(error.localizedDescription)")
                return
            }

            guard let documents = snapshot?.documents else {
                print("⚠️ No matches found")
                return
            }

            for document in documents {
                let result = Result {
                    try document.data(as: Match.self)
                }

                switch result {
                case .success(let match):
                    print("📄 Match: \(match)")
                case .failure(let error):
                    print("❌ Failed to decode match: \(error)")
                }
            }
        }
    }
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let destination = segue.destination as? StatisticsViewController {
            if segue.identifier == "showCompareTeams" {
                destination.comparisonMode = .team
            } else if segue.identifier == "showComparePlayers" {
                destination.comparisonMode = .player
            }
        }
    }


    
}
