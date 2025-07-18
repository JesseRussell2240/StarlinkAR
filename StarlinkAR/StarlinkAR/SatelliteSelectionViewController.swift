//
//  SatelliteSelectionViewController.swift
//  StarlinkAR
//
//  Created by Jesse Russell on 2025-07-17.
//

import Foundation
import UIKit
import CoreLocation

protocol SatelliteSelectionDelegate: AnyObject {
    func didSelectSatellite(id: Int, name: String)
}

class SatelliteSelectionViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {

    var tableView: UITableView!
    var satellites: [(id: Int, name: String)] = []
    var userLocation: CLLocation?
    weak var delegate: SatelliteSelectionDelegate?
    let apiKey = "PSRHTV-2KC7KA-VVNLWM-5J5S"

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = "Visible Starlink Satellites"

        tableView = UITableView(frame: view.bounds)
        tableView.dataSource = self
        tableView.delegate = self
        view.addSubview(tableView)

        fetchSatellites()
    }

    func fetchSatellites() {
        guard let userLoc = userLocation else { return }
        let lat = userLoc.coordinate.latitude
        let lon = userLoc.coordinate.longitude
        let alt = userLoc.altitude
        let urlStr = "https://api.n2yo.com/rest/v1/satellite/above/\(lat)/\(lon)/\(Int(alt))/90/52&apiKey=\(apiKey)"
        guard let url = URL(string: urlStr) else { return }

        URLSession.shared.dataTask(with: url) { data, _, error in
            guard let data = data else { return }
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let info = json["above"] as? [[String: Any]] {
                    for sat in info {
                        if let id = sat["satid"] as? Int,
                           let name = sat["satname"] as? String {
                            self.satellites.append((id, name))
                        }
                    }
                    DispatchQueue.main.async {
                        self.tableView.reloadData()
                    }
                }
            } catch {
                print("Failed to fetch satellites")
            }
        }.resume()
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return satellites.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let sat = satellites[indexPath.row]
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
        cell.textLabel?.text = sat.name
        cell.detailTextLabel?.text = "ID: \(sat.id)"
        cell.accessoryType = .disclosureIndicator
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let sat = satellites[indexPath.row]
        let passVC = PassesViewController()
        passVC.satId = sat.id
        passVC.satName = sat.name
        passVC.userLocation = self.userLocation
        passVC.selectionHandler = { id, name in
            self.delegate?.didSelectSatellite(id: id, name: name)
            self.dismiss(animated: true)
        }
        present(passVC, animated: true)
    }
}
