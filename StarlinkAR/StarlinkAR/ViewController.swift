import UIKit
import SceneKit
import ARKit
import CoreLocation
import MapKit

class ViewController: UIViewController, ARSCNViewDelegate, CLLocationManagerDelegate {

    @IBOutlet var sceneView: ARSCNView!
    let locationManager = CLLocationManager()
    var userLocation: CLLocation?
    var arrowNode: SCNNode!
    var satelliteLabel: UILabel!
    var mapView: MKMapView!
    var currentSatelliteId: Int?
    let apiKey = "PSRHTV-2KC7KA-VVNLWM-5J5S"

    override func viewDidLoad() {
        super.viewDidLoad()

        sceneView.delegate = self
        sceneView.scene = SCNScene()
        setupArrow()
        setupLabel()
        setupMapView()
        setupSelectButton()

        locationManager.delegate = self
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()

        Timer.scheduledTimer(timeInterval: 10.0, target: self, selector: #selector(trackNearestSatellite), userInfo: nil, repeats: true)
    }

    func setupArrow() {
        let arrow = SCNPyramid(width: 0.1, height: 0.2, length: 0.1)
        arrow.firstMaterial?.diffuse.contents = UIColor.orange
        arrowNode = SCNNode(geometry: arrow)
        arrowNode.position = SCNVector3(0, 0, -0.5)
        sceneView.scene.rootNode.addChildNode(arrowNode)
    }

    func setupLabel() {
        satelliteLabel = UILabel(frame: CGRect(x: 16, y: 60, width: view.frame.width - 32, height: 80))
        satelliteLabel.textColor = .white
        satelliteLabel.numberOfLines = 3
        satelliteLabel.font = UIFont.boldSystemFont(ofSize: 14)
        satelliteLabel.textAlignment = .center
        satelliteLabel.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        satelliteLabel.layer.cornerRadius = 10
        satelliteLabel.clipsToBounds = true
        view.addSubview(satelliteLabel)
    }

    func setupMapView() {
        mapView = MKMapView(frame: CGRect(x: 0, y: view.frame.height - 200, width: view.frame.width, height: 200))
        mapView.mapType = .mutedStandard
        mapView.delegate = self
        view.addSubview(mapView)
    }

    func setupSelectButton() {
        let button = UIButton(type: .system)
        button.setTitle("Select Satellite", for: .normal)
        button.frame = CGRect(x: 16, y: 150, width: 160, height: 40)
        button.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.7)
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 8
        button.addTarget(self, action: #selector(openSatelliteSelector), for: .touchUpInside)
        view.addSubview(button)
    }

    @objc func openSatelliteSelector() {
        let vc = SatelliteSelectionViewController()
        vc.userLocation = self.userLocation
        vc.delegate = self
        present(vc, animated: true)
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        userLocation = locations.last
        if let location = userLocation {
            let region = MKCoordinateRegion(center: location.coordinate, latitudinalMeters: 50000, longitudinalMeters: 50000)
            mapView.setRegion(region, animated: false)
        }
    }

    @objc func trackNearestSatellite() {
        guard let userLoc = userLocation else { return }
        let lat = userLoc.coordinate.latitude
        let lon = userLoc.coordinate.longitude
        let alt = userLoc.altitude

        let urlStr = "https://api.n2yo.com/rest/v1/satellite/above/\(lat)/\(lon)/\(Int(alt))/90/52&apiKey=\(apiKey)"
        guard let url = URL(string: urlStr) else { return }

        URLSession.shared.dataTask(with: url) { data, _, error in
            guard let data = data, error == nil else { return }
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let info = json["above"] as? [[String: Any]],
                   let closest = info.first {
                    if let satId = closest["satid"] as? Int,
                       let satName = closest["satname"] as? String {
                        self.currentSatelliteId = satId
                        self.fetchLiveSatellitePosition(satId: satId, satName: satName)
                    }
                }
            } catch {
                print("Failed to parse visible satellite list")
            }
        }.resume()
    }

    func fetchLiveSatellitePosition(satId: Int, satName: String) {
        guard let userLoc = userLocation else { return }
        let lat = userLoc.coordinate.latitude
        let lon = userLoc.coordinate.longitude
        let alt = userLoc.altitude

        let urlStr = "https://api.n2yo.com/rest/v1/satellite/positions/\(satId)/\(lat)/\(lon)/\(Int(alt))/5&apiKey=\(apiKey)"
        guard let url = URL(string: urlStr) else { return }

        URLSession.shared.dataTask(with: url) { data, _, error in
            guard let data = data, error == nil else { return }
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let positions = json["positions"] as? [[String: Any]] {

                    DispatchQueue.main.async {
                        self.mapView.removeAnnotations(self.mapView.annotations)
                        self.mapView.removeOverlays(self.mapView.overlays)
                    }

                    var satelliteCoordinates: [CLLocationCoordinate2D] = []

                    for (index, pos) in positions.enumerated() {
                        if let satLat = pos["satlatitude"] as? Double,
                           let satLon = pos["satlongitude"] as? Double,
                           let elevation = pos["elevation"] as? Double,
                           let azimuth = pos["azimuth"] as? Double {

                            let satCoord = CLLocationCoordinate2D(latitude: satLat, longitude: satLon)
                            satelliteCoordinates.append(satCoord)

                            if index == 0 {
                                let satLoc = CLLocation(latitude: satLat, longitude: satLon)
                                let dist = self.userLocation?.distance(from: satLoc) ?? 0.0

                                DispatchQueue.main.async {
                                    self.updateArrow(to: satCoord)
                                    self.updateLabel(name: satName, distance: dist, elevation: elevation, azimuth: azimuth)

                                    let annotation = MKPointAnnotation()
                                    annotation.coordinate = satCoord
                                    annotation.title = satName
                                    self.mapView.addAnnotation(annotation)

                                    if let userLoc = self.userLocation {
                                        let userAnnotation = MKPointAnnotation()
                                        userAnnotation.coordinate = userLoc.coordinate
                                        userAnnotation.title = "You"
                                        self.mapView.addAnnotation(userAnnotation)
                                    }
                                }
                            }
                        }
                    }

                    DispatchQueue.main.async {
                        let polyline = MKPolyline(coordinates: satelliteCoordinates, count: satelliteCoordinates.count)
                        self.mapView.addOverlay(polyline)
                    }
                }
            } catch {
                print("Failed to parse satellite position")
            }
        }.resume()
    }

    func updateArrow(to satelliteCoord: CLLocationCoordinate2D) {
        guard let userLoc = userLocation else { return }
        let userCoord = userLoc.coordinate
        let bearing = bearingBetween(start: userCoord, end: satelliteCoord)
        let radians = Float(bearing * .pi / 180)

        SCNTransaction.begin()
        SCNTransaction.animationDuration = 0.5
        arrowNode.eulerAngles.y = -radians
        SCNTransaction.commit()
    }

    func updateLabel(name: String, distance: Double, elevation: Double, azimuth: Double) {
        let kmDistance = String(format: "%.1f", distance / 1000.0)
        let elev = String(format: "%.1f", elevation)
        let azim = String(format: "%.1f", azimuth)
        satelliteLabel.text = "\(name)\n\(kmDistance) km\nElev: \(elev)° Az: \(azim)°"
    }

    func bearingBetween(start: CLLocationCoordinate2D, end: CLLocationCoordinate2D) -> Double {
        let lat1 = start.latitude * .pi / 180
        let lon1 = start.longitude * .pi / 180
        let lat2 = end.latitude * .pi / 180
        let lon2 = end.longitude * .pi / 180

        let dLon = lon2 - lon1
        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        let bearing = atan2(y, x)
        return (bearing * 180 / .pi + 360).truncatingRemainder(dividingBy: 360)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        let configuration = ARWorldTrackingConfiguration()
        configuration.worldAlignment = .gravity
        sceneView.session.run(configuration)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        sceneView.session.pause()
    }
}

extension ViewController: MKMapViewDelegate {
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        if let polyline = overlay as? MKPolyline {
            let renderer = MKPolylineRenderer(overlay: polyline)
            renderer.strokeColor = .cyan
            renderer.lineWidth = 2
            return renderer
        }
        return MKOverlayRenderer()
    }
}

extension ViewController: SatelliteSelectionDelegate {
    func didSelectSatellite(id: Int, name: String) {
        self.currentSatelliteId = id
        self.fetchLiveSatellitePosition(satId: id, satName: name)
    }
}
