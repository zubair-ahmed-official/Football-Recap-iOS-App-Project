//
//  Matches.swift
//  Assignment3
//
//  Created by mobiledev on 5/5/2025.
//

import Foundation
import Firebase
import FirebaseFirestore
//import FirebaseFirestoreSwift

public struct Match : Codable
{
    @DocumentID var documentID:String?
    var date:String
    var location:String
    var status:String
    var team1:String
    var team2:String
    var time:String
    
}
