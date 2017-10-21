//
//  ViewController.swift
//  Traffic Buddy
//
//  Created by Brian Williams on 10/1/17.
//  Copyright © 2017 Brian Williams. All rights reserved.
//

import CoreLocation
import MapKit
import UIKit

class ViewController: UIViewController, CLLocationManagerDelegate {
    var intersections = [Intersection]()
    let locationManager = CLLocationManager()
    
    @IBOutlet var mainBackground: UIView!
    @IBOutlet weak var countLabel: UILabel!
    @IBOutlet weak var locationLabel: UILabel!
    @IBOutlet weak var nearestIntersectionLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Do any additional setup after loading the view, typically from a nib.
        // Ask for Authorisation from the User.
        self.locationManager.requestAlwaysAuthorization()
        
        // For use in foreground
        self.locationManager.requestWhenInUseAuthorization()
        
        if CLLocationManager.locationServicesEnabled() {
            locationManager.delegate = self
            locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
            locationManager.startUpdatingLocation()
        }
        
        intersections.append(Intersection(lat: 44.080277, long: -123.067722, name: "Coburg & Willakenzie"))
        intersections.append(Intersection(lat: 44.040030, long: -123.080198, name: "18th & Alder"))
        intersections.append(Intersection(lat: 44.045689, long: -123.066324, name: "13th & Franklin"))
        intersections.append(Intersection(lat: 44.056741, long: -123.024210, name: "Centennial & Pioneer Pkwy W"))
        intersections.append(Intersection(lat: 44.056656, long: -123.023835, name: "Centennial & Pioneer Pkwy E"))
        
        countLabel.text = String(intersections.count)
    }
    
    func closestLocation(locations: [CLLocation], closestToLocation location: CLLocation) -> CLLocation? {
        if let closestLocation = locations.min(by: { location.distance(from: $0) < location.distance(from: $1) }) {
//            nearestIntersectionLabel.text = "closest location: \(closestLocation), distance: \(location.distance(from: closestLocation)) meters"
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
        print("locations = \(locValue.latitude) \(locValue.longitude)")
        
        locationLabel.text = "location: \(locValue.latitude) \(locValue.longitude)"
        
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
                coords.append(intersections[i].location)
            }
            
            let nearest = closestLocation(locations: coords, closestToLocation: locationManager.location!)
            for i in (0...intersections.count-1) {
                if intersections[i].location == nearest {
                    nearestIntersectionLabel.text = "closest intersection: \(intersections[i].title), distance: \(String(describing: nearest!.distance(from: locationManager.location!))) meters"
                    break
                }
            }
        }
    }

    @IBAction func pollServerButton(_ sender: Any) {
        displayClosestIntersection()

        if let url = URL(string: "https://dubflask.herokuapp.com") {
            do {
                let contents = try String(contentsOf: url)
                if contents == "yes" {
                    mainBackground.backgroundColor = UIColor.green
                }
                else {
                    mainBackground.backgroundColor = UIColor.red
                }
                countLabel.text = contents
            } catch {
                // contents could not be loaded
                countLabel.text = "couldn't load url"
            }
        } else {
            // the URL was bad!
        }
    }
}

