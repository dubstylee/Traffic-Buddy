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

class ViewController: UIViewController, CLLocationManagerDelegate {
    var nearIntersection = false
    let locationManager = CLLocationManager()
    let distanceThreshold = 1320.0 // quarter mile
    let realm = try! Realm()
    var intersections: Results<Intersection>!
    var locationRealm: Realm?
    var token: String?
    var hcKalmanFilter: HCKalmanAlgorithm?
    var resetKalmanFilter: Bool = false
    var polling: Bool = false
    
    @IBOutlet var mainBackground: UIView!
    @IBOutlet weak var infoLabel: UILabel!
    @IBOutlet weak var locationLabel: UILabel!
    @IBOutlet weak var nearestIntersectionLabel: UILabel!
    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var startButton: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
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

    func initRealm() {
        intersections = realm.objects(Intersection.self)

        if intersections.count == 0 {
            try! realm.write {
                realm.add(Intersection(latitude: 44.084221, longitude: -123.061607, title: "Cambridge Oaks Dr"))
                realm.add(Intersection(latitude: 44.080277, longitude: -123.067722, title: "Coburg & Willakenzie"))
                realm.add(Intersection(latitude: 44.040030, longitude: -123.080198, title: "18th & Alder"))
                realm.add(Intersection(latitude: 44.045489, longitude: -123.070931, title: "13th Ave Kiosk"))
                realm.add(Intersection(latitude: 44.045689, longitude: -123.066324, title: "13th & Franklin"))
                realm.add(Intersection(latitude: 44.056741, longitude: -123.024210, title: "Centennial & Pioneer Pkwy W"))
                realm.add(Intersection(latitude: 44.056656, longitude: -123.023835, title: "Centennial & Pioneer Pkwy E"))
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
                    
                    locationLabel.text = "Current Location:\n  \(locValue.latitude) \(locValue.longitude)"
                }
            }
        }
        
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
                        readLedState()
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
                        nearestIntersectionLabel.text = "Nearest Intersection:\n  \(intersections[i].title)\nDistance:\n  \(String(describing: dist)) feet"
                        break
                    }
                }
            }
        }
    }
    
    /*
    func pollServer() {
        if let url = URL(string: "https://dubflask.herokuapp.com") {
            do {
                let contents = try String(contentsOf: url)
                if contents == "yes" {
                    mainBackground.backgroundColor = UIColor.green
                }
                else {
                    mainBackground.backgroundColor = UIColor.red
                }
                //infoLabel.text = contents
            } catch {
                // contents could not be loaded
                infoLabel.text = "couldn't load url"
            }
        } else {
            // the URL was bad!
        }
    }
    */
    
    func readLedState() {
        myPhoton!.getVariable("led_state", completion: { (result:Any?, error:Error?) -> Void in
            if let _ = error {
                self.infoLabel.text = "failed reading led status from device"
            }
            else {
                if let status = result as? String {
                    if status == "on" {
                        self.mainBackground.backgroundColor = UIColor.green
                    }
                    else {
                        self.mainBackground.backgroundColor = UIColor.red
                    }
                    self.infoLabel.text = "led is \(status)"
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
        readLedState()
    }
    
    @IBAction func toggleLedButton(_ sender: Any) {
        toggleLedState()
    }
    
    @IBAction func pushStartButton(_ sender: Any) {
        if startButton.titleLabel?.text == "Start" {
            startButton.setTitle("Stop", for: .normal)
            polling = true
        }
        else if startButton.titleLabel?.text == "Stop" {
            startButton.setTitle("Start", for: .normal)
            mainBackground.backgroundColor = UIColor.white
            polling = false
        }
    }
}

