//
//  ViewController.swift
//  Traffic Buddy
//
//  Created by Brian Williams on 10/1/17.
//  Copyright © 2017 Brian Williams. All rights reserved.
//

import AudioToolbox
import CoreLocation
import MapKit
import Particle_SDK
import Realm
import RealmSwift
import UIKit
import HCKalmanFilter
import LoginWithAmazon


class ViewController: UIViewController, CLLocationManagerDelegate, MKMapViewDelegate {
    var nearIntersection = false
    let locationManager = CLLocationManager()
    let distanceThreshold = 200.0 // 1320.0 == quarter mile
    let metersPerSecToMilesPerHour = 2.23694
    let realm = try! Realm()
    var intersections: Results<Intersection>!
    var locationRealm: Realm?
    var token: String?
    var hcKalmanFilter: HCKalmanAlgorithm?
    var resetKalmanFilter: Bool = false
    var polling: Bool = false
    var nearestIntersection: CLLocation?
    var lastLocation: CLLocation?
    
    @IBOutlet var mainBackground: UIView!
    @IBOutlet weak var infoLabel: UILabel!
    @IBOutlet weak var locationLabel: UILabel!
    @IBOutlet weak var nearestIntersectionLabel: UILabel!
    @IBOutlet weak var speedInstantLabel: UILabel!
    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var startButton: UIButton!
    @IBOutlet weak var relayStateView: UIView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.relayStateView.layer.borderColor = UIColor.black.cgColor
        self.relayStateView.layer.borderWidth = 1.0
        self.locationManager.requestAlwaysAuthorization()
        self.locationManager.requestWhenInUseAuthorization()
        
        if let path = Bundle.main.path(forResource: "particle", ofType: "conf") {
            do {
                token = try String(contentsOfFile: path, encoding: String.Encoding.utf8)
                token = token!.trimmingCharacters(in: NSCharacterSet.newlines)
            } catch {
                print("Failed to read text from particle.conf")
            }
        } else {
            print("Failed to load file from app bundle particle.conf")
        }
        
        if CLLocationManager.locationServicesEnabled() {
            locationManager.allowsBackgroundLocationUpdates = true
            locationManager.delegate = self
            locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
            locationManager.distanceFilter = 0.5
            // locationManager.showsBackgroundLocationIndicator = true
            locationManager.startUpdatingLocation()
        }

        if locationManager.location != nil {
            centerMapOnLocation(location: locationManager.location!)
        }
        initRealm()
        setupMapView()
        
        if ParticleCloud.sharedInstance().injectSessionAccessToken(token!) {
            infoLabel.text = "session active"
            getDevices()
        } else {
            infoLabel.text = "bad token"
        }
    }
    
    let regionRadius: CLLocationDistance = 1000
    func centerMapOnLocation(location: CLLocation) {
        let coordinateRegion = MKCoordinateRegionMakeWithDistance(location.coordinate,
                                                                  regionRadius, regionRadius)
        mapView.setRegion(coordinateRegion, animated: true)
    }
    
    var myPhoton : ParticleDevice?
    func getDevices() {
        ParticleCloud.sharedInstance().getDevices {
            (devices:[ParticleDevice]?, error:Error?) -> Void in
            if let _ = error {
                self.infoLabel.text = "check your internet connectivity"
            }
            else {
                if let d = devices {
                    for device in d {
                        if device.name == "beacon_2" {
                            self.myPhoton = device
                            self.infoLabel.text = "found beacon_2"
                        }
                    }
                }
            }
        }
    }
    
    func setupMapView() {
        mapView.delegate = self
        mapView.layer.borderColor = UIColor.black.cgColor
        mapView.layer.borderWidth = 1.0
        for i in self.intersections {
            // draw a circle to indicate intersection
            let circle = MKCircle(center: i.getLocation().coordinate, radius: 10 as CLLocationDistance)
            mapView.add(circle)
        }
    }
    
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        if overlay is MKCircle {
            let circle = MKCircleRenderer(overlay: overlay)
            circle.strokeColor = UIColor.red
            circle.fillColor = UIColor(red: 255, green: 0, blue: 0, alpha: 0.1)
            circle.lineWidth = 1
            return circle
        }
        return MKOverlayRenderer()
    }

    func initRealm() {
        self.intersections = realm.objects(Intersection.self)

        if self.intersections.count == 0 {
            try! realm.write {
                realm.add(Intersection(latitude: 44.040030, longitude: -123.080198, title: "18th & Alder"))
                #if DEBUG
                realm.add(Intersection(latitude: 44.084221, longitude: -123.061607, title: "Cambridge Oaks Dr"))
                realm.add(Intersection(latitude: 44.080277, longitude: -123.067722, title: "Coburg & Willakenzie"))
                realm.add(Intersection(latitude: 44.045489, longitude: -123.070931, title: "13th Ave Kiosk"))
                realm.add(Intersection(latitude: 44.045689, longitude: -123.066324, title: "13th & Franklin"))
                realm.add(Intersection(latitude: 44.056741, longitude: -123.024210, title: "Centennial & Pioneer Pkwy W"))
                realm.add(Intersection(latitude: 44.056656, longitude: -123.023835, title: "Centennial & Pioneer Pkwy E"))
                #endif
            }
        }
        
        infoLabel.text = "# intersections: \(intersections.count)"
        /*let config = Realm.Configuration(
            fileURL: Bundle.main.url(forResource: "locationhistory", withExtension: "realm"),
            readOnly: false)
        locationRealm = try! Realm(configuration: config)*/
    }
    
    func metersToFeet(from: Double) -> Double {
        return from * 3.28084
    }

    func closestLocation(locations: [CLLocation], closestToLocation location: CLLocation) -> CLLocation? {
        if let closestLocation = locations.min(by: { location.distance(from: $0) < location.distance(from: $1) }) {
            return closestLocation
        } else {
            nearestIntersectionLabel.text = "locations is empty"
            return nil
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    //this method will be called each time when a user change his location access preference.
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        if status == .authorizedWhenInUse {
            print("User allowed us to access location")
            //do whatever init activities here.
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let myLocation: CLLocation = locations.first!

        if hcKalmanFilter == nil {
            self.hcKalmanFilter = HCKalmanAlgorithm(initialLocation: myLocation)
        }
        else {
            if let hcKalmanFilter = self.hcKalmanFilter {
                if resetKalmanFilter == true {
                    hcKalmanFilter.resetKalman(newStartLocation: myLocation)
                    resetKalmanFilter = false
                }
                else {
                    //print(myLocation.coordinate)
                    //let kalmanLocation = hcKalmanFilter.processState(currentLocation: myLocation)
                    //print(kalmanLocation.coordinate)
                    let locValue:CLLocationCoordinate2D = myLocation.coordinate
                    var latString = "0°"
                    var longString = "0°"

                    if locValue.latitude > 0 {
                        // north of equator
                        latString = "\(locValue.latitude)° N"
                    }
                    else {
                        // south of equator
                        latString = "\(-locValue.latitude)° S"
                    }
                    
                    if locValue.longitude > 0 {
                        // east of prime meridian
                        longString = "\(locValue.longitude)° E"
                    }
                    else {
                        // west of prime meridian
                        longString = "\(-locValue.longitude)° W"
                    }

                    locationLabel.text = "\(latString) \(longString)"
                }
            }
        }
        var instantSpeed = myLocation.speed
        instantSpeed = max(instantSpeed, 0.0)
        speedInstantLabel.text = String(format: "Instant Speed: %.2f mph", (instantSpeed * metersPerSecToMilesPerHour))

        /*
        var calculatedSpeed = 0.0
        if lastLocation != nil {
            calculatedSpeed = lastLocation!.distance(from: myLocation) / (myLocation.timestamp.timeIntervalSince(lastLocation!.timestamp))
            speedCalculatedLabel.text = String(format: "Calculated Speed: %.2f mph", (calculatedSpeed * metersPerSecToMilesPerHour))
        }
        */
        lastLocation = myLocation
        
        displayClosestIntersection()
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Did location updates is called but failed getting location \(error)")
    }
    
    func displayClosestIntersection()
    {
        if CLLocationManager.locationServicesEnabled() {
            locationManager.requestLocation()
            //let kalmanLocation = self.hcKalmanFilter?.processState(currentLocation: locationManager.location!)
            
            // make CLLocation array from intersections
            var coords = [CLLocation]()
            for i in (0...intersections.count-1) {
                coords.append(intersections[i].getLocation())
            }
            
            let nearest = closestLocation(locations: coords, closestToLocation: locationManager.location!)
            if nearest != nil {
                let dist = metersToFeet(from: nearest!.distance(from: locationManager.location!))
                
                if dist < distanceThreshold && polling {
                    // auto-poll server within quarter mile
                    //pollServer()
                    if myPhoton != nil {
                        //readLedState()
                        readLoopState()
                    }
                    
                    // if the user is not already near an intersection, vibrate to notify
                    if dist < 50.0 && !nearIntersection {
                        nearIntersection = true
                        AudioServicesPlayAlertSound(SystemSoundID(kSystemSoundID_Vibrate))
                    }
                    
                    // if the user was previously near an intersection, vibrate to notify
                    if dist > 50.0 && nearIntersection {
                        nearIntersection = false
                        AudioServicesPlayAlertSound(SystemSoundID(kSystemSoundID_Vibrate))
                    }
                } else {
                    polling = false
                    mainBackground.backgroundColor = UIColor.white
                }

                for i in (0...intersections.count-1) {
                    if intersections[i].latitude == nearest!.coordinate.latitude &&
                            intersections[i].longitude == nearest!.coordinate.longitude {
                        nearestIntersectionLabel.text = String(format: "%.0f feet from \(intersections[i].title)", dist)
                        break
                    }
                }
            }
        }
    }
    
    func readLedState() {
        myPhoton!.getVariable("led_state", completion: { (result:Any?, error:Error?) -> Void in
            if let _ = error {
                self.relayStateView.backgroundColor = UIColor.gray
                self.infoLabel.text = "failed reading led status from device"
            }
            else {
                if let status = result as? String {
                    if status == "on" {
                        self.relayStateView.backgroundColor = UIColor.green
                    }
                    else {
                        self.relayStateView.backgroundColor = UIColor.red
                    }
                    self.infoLabel.text = "led is \(status)"
                }
            }
        })
    }
    
    func readLoopState() {
        myPhoton!.getVariable("loop_state", completion: { (result:Any?, error:Error?) -> Void in
            if let _ = error {
                self.infoLabel.text = "failed reading loop status from device"
            }
            else {
                if let status = result as? Int { //String {
                    if status == 1 { //"on" {
                        self.relayStateView.backgroundColor = UIColor.green
                    }
                    else {
                        self.relayStateView.backgroundColor = UIColor.red
                    }
                    self.infoLabel.text = "loop is \(status)"
                }
            }
        })
    }
    
    func toggleLedState() {
        let task = myPhoton!.callFunction("toggle_led", withArguments: nil) { (resultCode : NSNumber?, error : Error?) -> Void in
            if (error == nil) {
                self.infoLabel.text = "toggle led successful"
            }
        }
        let bytes : Int64 = task.countOfBytesExpectedToReceive
        if bytes > 0 {
            // ..do something with bytesToReceive
        }
    }

    @IBAction func pollServerButton(_ sender: Any) {
        //readLedState()
        readLoopState()
    }
    
    @IBAction func pushStartButton(_ sender: Any) {
        if startButton.titleLabel?.text == "Start" {
            startButton.setTitle("Stop", for: .normal)
            polling = true
        }
        else if startButton.titleLabel?.text == "Stop" {
            startButton.setTitle("Start", for: .normal)
            //mainBackground.backgroundColor = UIColor.white
            polling = false
        }
    }
    
    @IBAction func triggerRelayButton(_ sender: Any) {
        let relay_number = "1"
        let task = myPhoton!.callFunction("relay_on", withArguments: [relay_number]) { (resultCode : NSNumber?, error : Error?) -> Void in
            if (error == nil) {
                self.infoLabel.text = "relay \(relay_number) on"
            }
        }
        let bytes : Int64 = task.countOfBytesExpectedToReceive
        if bytes > 0 {
            // ..do something with bytesToReceive
        }
    }
}

