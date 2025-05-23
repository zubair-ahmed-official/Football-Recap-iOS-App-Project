import UIKit

class PlayerCell: UITableViewCell {
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var deleteButton: UIButton!

    var deleteAction: (() -> Void)?

    @IBAction func deleteButtonTapped(_ sender: UIButton) {
        deleteAction?()
    }
}
