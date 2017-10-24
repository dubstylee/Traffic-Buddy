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
import Realm
import RealmSwift
import UIKit

class ViewController: UIViewController, CLLocationManagerDelegate {
    var nearIntersection = false
    let locationManager = CLLocationManager()
    let distanceThreshold = 1320.0 // quarter mile
    let realm = try! Realm()
    var intersections : Results<Intersection>!
    
    @IBOutlet var mainBackground: UIView!
    @IBOutlet weak var infoLabel: UILabel!
    @IBOutlet weak var locationLabel: UILabel!
    @IBOutlet weak var nearestIntersectionLabel: UILabel!
    @IBOutlet weak var toggleSwitch: UISwitch!
    @IBOutlet weak var mapView: MKMapView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        debugPrint("Path to realm file: " + realm.configuration.fileURL!.absoluteString)
        self.locationManager.requestAlwaysAuthorization()
        self.locationManager.requestWhenInUseAuthorization()
        
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
    }
    
    let regionRadius: CLLocationDistance = 1000
    func centerMapOnLocation(location: CLLocation) {
        let coordinateRegion = MKCoordinateRegionMakeWithDistance(location.coordinate,
                                                                  regionRadius, regionRadius)
        mapView.setRegion(coordinateRegion, animated: true)
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
        let locValue:CLLocationCoordinate2D = manager.location!.coordinate
        
        locationLabel.text = "Current Location:\n  \(locValue.latitude) \(locValue.longitude)"
        
        displayClosestIntersection()
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Did location updates is called but failed getting location \(error)")
    }
    
    func displayClosestIntersection()
    {
        if CLLocationManager.locationServicesEnabled() {
            locationManager.requestLocation()
            
            // make CLLocation array from intersections
            var coords = [CLLocation]()
            for i in (0...intersections.count-1) {
                coords.append(intersections[i].getLocation())
            }
            
            let nearest = closestLocation(locations: coords, closestToLocation: locationManager.location!)
            if nearest != nil {
                let dist = metersToFeet(from: nearest!.distance(from: locationManager.location!))
                
                if dist < distanceThreshold {
                    // auto-poll server within quarter mile
                    pollServer()

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

    @IBAction func pollServerButton(_ sender: Any) {
        pollServer()
    }
}

