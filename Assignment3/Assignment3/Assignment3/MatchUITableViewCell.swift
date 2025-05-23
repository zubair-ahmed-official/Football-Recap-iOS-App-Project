//
//  MatchUITableViewCell.swift
//  Assignment3
//
//  Created by mobiledev on 5/5/2025.
//

import UIKit

class MatchUITableViewCell: UITableViewCell {

    
    @IBOutlet var timeLabel: UILabel!
    @IBOutlet var team2Label: UILabel!
    @IBOutlet var team1Label: UILabel!
    @IBOutlet var statusLabel: UILabel!
    @IBOutlet var locationLabel: UILabel!
    @IBOutlet var dateLabel: UILabel!
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

}
