import UIKit
import DGCharts
import Charts

class WormGraphViewController: UIViewController, ChartViewDelegate {
    @IBOutlet weak var lineChartView: LineChartView!

    // MARK: - Properties to be set from previous screen
    var team1: String = ""
    var team2: String = ""
    var team1Score: Int = 0
    var team2Score: Int = 0
    var actions: [[String: Any]] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        lineChartView.delegate = self
        drawWormGraph()
    }
    
    func chartValueSelected(_ chartView: ChartViewBase, entry: ChartDataEntry, highlight: Highlight) {
        // Get the x and y tapped
        let timeInSeconds = Int(entry.x)
        let margin = Int(entry.y)

        // Recompute scores at that time
        var teamAScore = 0
        var teamBScore = 0

        for action in actions {
            if let type = action["type"] as? String, type == "Goal",
               let team = action["team"] as? String,
               let time = action["matchTime"] as? String {
                
                let components = time.split(separator: ":")
                if components.count == 2,
                   let min = Int(components[0]),
                   let sec = Int(components[1]) {
                    
                    let actionTime = min * 60 + sec
                    if actionTime <= timeInSeconds {
                        if team == team1 {
                            teamAScore += 1
                        } else if team == team2 {
                            teamBScore += 1
                        }
                    }
                }
            }
        }

        // Show alert
        let alert = UIAlertController(
            title: "At \(timeInSeconds)s",
            message: "\(team1): \(teamAScore)\n\(team2): \(teamBScore)\nMargin: \(margin)",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }



    func drawWormGraph() {
        var marginOverTime: [(x: Double, y: Double)] = []
        var score = [team1: 0, team2: 0]

        // ⏱ Step 1: Collect worm data
        for action in actions {
            if let type = action["type"] as? String, type == "Goal",
               let team = action["team"] as? String,
               let time = action["matchTime"] as? String {
                let components = time.split(separator: ":")
                if components.count == 2, let min = Int(components[0]), let sec = Int(components[1]) {
                    score[team, default: 0] += 1
                    let margin = Double(score[team1, default: 0] - score[team2, default: 0])
                    let totalSeconds = Double(min * 60 + sec)
                    
                    if let last = marginOverTime.last {
                        // Step line behavior: flat segment
                        marginOverTime.append((x: totalSeconds, y: last.y))
                    }
                    marginOverTime.append((x: totalSeconds, y: margin))
                }
            }
        }

        // 🔴 Worm Graph
        let wormEntries = marginOverTime.map { ChartDataEntry(x: $0.x, y: $0.y) }
        let wormSet = LineChartDataSet(entries: wormEntries, label: "Score Margin")
        wormSet.setColor(.systemRed)
        wormSet.drawCirclesEnabled = false
        wormSet.drawValuesEnabled = false
        wormSet.lineWidth = 2.0
        wormSet.mode = .stepped

        // 🔺 Team A Intro Bar (Red, Y = +9)
        let teamASet = LineChartDataSet(entries: [
            ChartDataEntry(x: 0.0, y: 0.0),
            ChartDataEntry(x: 0.0, y: 9.0)
        ], label: team1)
        teamASet.setColor(.systemRed)
        teamASet.lineWidth = 6
        teamASet.drawCirclesEnabled = false
        teamASet.drawValuesEnabled = false

        // 🔵 Team B Intro Bar (Blue, Y = -9)
        let teamBSet = LineChartDataSet(entries: [
            ChartDataEntry(x: 0.0, y: 0.0),
            ChartDataEntry(x: 0.0, y: -9.0)
        ], label: team2)
        teamBSet.setColor(.systemBlue)
        teamBSet.lineWidth = 6
        teamBSet.drawCirclesEnabled = false
        teamBSet.drawValuesEnabled = false

        // 📊 Combine data
        let chartData = LineChartData(dataSets: [teamASet, teamBSet, wormSet])
        lineChartView.data = chartData

        // 📈 Configure Chart
        lineChartView.chartDescription.enabled = true
        lineChartView.chartDescription.text = "\(team1) vs \(team2)"
        lineChartView.legend.enabled = true

        // 🕓 X-axis (Time)
        let xAxis = lineChartView.xAxis
        xAxis.labelPosition = .bottom
        xAxis.drawGridLinesEnabled = true
        xAxis.labelTextColor = .black
        xAxis.labelFont = .boldSystemFont(ofSize: 10)
        xAxis.axisMinimum = 0

        // 🧮 Y-axis (Score Margin)
        let leftAxis = lineChartView.leftAxis
        leftAxis.drawZeroLineEnabled = true
        leftAxis.zeroLineColor = .darkGray
        leftAxis.axisMinimum = -10
        leftAxis.axisMaximum = 10
        leftAxis.labelFont = .boldSystemFont(ofSize: 10)
        leftAxis.labelTextColor = .black

        lineChartView.rightAxis.enabled = false
        lineChartView.setScaleEnabled(false)
        lineChartView.animate(xAxisDuration: 1.0, yAxisDuration: 1.0)
    }


}
