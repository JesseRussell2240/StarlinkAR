//
//  PassesViewController.swift
//  StarlinkAR
//
//  Created by Jesse Russell on 2025-07-17.
//

import Foundation
import UIKit
import CoreLocation

class PassesViewController: UIViewController, UITableViewDataSource {

    var tableView: UITableView!
    var satId: Int!
    var satName: String!
    var userLocation: CLLocation?
    var passes: [[String: Any]] = []
    let apiKey = "PSRHTV-2KC7KA-VVNLWM-5J5S"
    var selectionHandler: ((Int, String) -> Void)?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = "Upcoming Passes"

        tableView = UITableView(frame: view.bounds)
        tableView.dataSource = self
        view.addSubview(tableView)

        fetchPasses()
    }

    func fetchPasses() {
        guard let userLoc = userLocation else { return }
        let lat = userLoc.coordinate.latitude
        let lon = userLoc.coordinate.longitude
        let alt = userLoc.altitude
        let urlStr = "https://api.n2yo.com/rest/v1/satellite/visualpasses/\(satId!)/\(lat)/\(lon)/\(Int(alt))/7/5&apiKey=\(apiKey)"
        guard let url = URL(string: urlStr) else { return }

        URLSession.shared.dataTask(with: url) { data, _, error in
            guard let data = data else { return }
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let passList = json["passes"] as? [[String: Any]] {
                    self.passes = passList
                    DispatchQueue.main.async {
                        self.tableView.reloadData()
                    }
                }
            } catch {
                print("Failed to fetch passes")
            }
        }.resume()
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return passes.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let pass = passes[indexPath.row]
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil)

        if let startUTC = pass["startUTC"] as? Double,
           let maxEl = pass["maxEl"] as? Double {
            let date = Date(timeIntervalSince1970: startUTC)
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            formatter.dateStyle = .short

            cell.textLabel?.text = formatter.string(from: date)
            cell.detailTextLabel?.text = "Max Elevation: \(Int(maxEl))°"
        }

        return cell
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        if let handler = selectionHandler {
            handler(satId, satName)
        }
    }
}
