import Foundation
import FirebaseFirestore

struct Player {
    var name: String
    var position: String
    var photoURL: String?

    init?(from doc: DocumentSnapshot) {
        let data = doc.data() ?? [:]
        guard let name = data["name"] as? String,
              let position = data["position"] as? String else { return nil }
        self.name = name
        self.position = position
        self.photoURL = data["photoURL"] as? String
    }
}

