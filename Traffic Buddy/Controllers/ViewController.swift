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
    var intersections = [Intersection]()
    var nearIntersection = false
    let locationManager = CLLocationManager()
    let distanceThreshold = 1320.0 // quarter mile
    let realm = try! Realm()
    
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

        /*
        intersections.append(Intersection(lat: 44.084221, long: -123.061607, name: "Cambridge Oaks Dr"))
        intersections.append(Intersection(lat: 44.080277, long: -123.067722, name: "Coburg & Willakenzie"))
        intersections.append(Intersection(lat: 44.040030, long: -123.080198, name: "18th & Alder"))
        intersections.append(Intersection(lat: 44.045489, long: -123.070931, name: "13th Ave Kiosk"))
        intersections.append(Intersection(lat: 44.045689, long: -123.066324, name: "13th & Franklin"))
        intersections.append(Intersection(lat: 44.056741, long: -123.024210, name: "Centennial & Pioneer Pkwy W"))
        intersections.append(Intersection(lat: 44.056656, long: -123.023835, name: "Centennial & Pioneer Pkwy E"))
         */
        initRealm()
    }
    
    func initRealm() {
        let intersection = Intersection()
        intersection.latitude = 44.084221
        intersection.longitude = -123.061607
        intersection.title = "Cambridge Oaks Dr"
        
        try! realm.write {
            realm.add(intersection)
        }
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
        
        let center = CLLocationCoordinate2D(latitude: locValue.latitude, longitude: locValue.longitude)
        let region = MKCoordinateRegion(center: center, span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01))
        mapView.setRegion(region, animated: true)
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
//            var coords = [CLLocation]()
  //          for i in (0...intersections.count-1) {
    //            coords.append(intersections[i].getLocation())
      //      }
            
//            let nearest = closestLocation(locations: coords, closestToLocation: locationManager.location!)
            let nearest = CLLocation(latitude: 120, longitude: -120)
            if nearest != nil {
                let dist = metersToFeet(from: nearest.distance(from: locationManager.location!))
                
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

//                for i in (0...intersections.count-1) {
  //                  if intersections[i].getLocation() == nearest {
    //                    nearestIntersectionLabel.text = "Nearest Intersection:\n  \(intersections[i].title)\nDistance:\n  \(String(describing: dist)) feet"
      //                  break
        //            }
           //     }
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
                infoLabel.text = contents
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

