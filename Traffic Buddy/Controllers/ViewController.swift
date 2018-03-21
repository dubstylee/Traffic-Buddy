//
//  ViewController.swift
//  Traffic Buddy
//
//  Created by Brian Williams on 10/1/17.
//  Copyright © 2017 Brian Williams. All rights reserved.
//

import AudioToolbox
import CoreLocation
import CoreMotion
import MapKit
import MessageUI
import Particle_SDK
import Realm
import RealmSwift
import UIKit
//import HCKalmanFilter
import LoginWithAmazon


class ViewController: UIViewController, CLLocationManagerDelegate, MKMapViewDelegate, MFMailComposeViewControllerDelegate, AIAuthenticationDelegate {
    


    var nearIntersection = false
    let locationManager = CLLocationManager()
    let distanceThreshold = 200.0 // 1320.0 == quarter mile
    let metersPerSecToMilesPerHour = 2.23694
    //let realm = try! Realm()
    var realm: Realm?
    var intersections: Results<Intersection>!
    //var locationRealm: Realm?
    var token: String?
    //var hcKalmanFilter: HCKalmanAlgorithm?
    //var resetKalmanFilter: Bool = false
    var polling: Bool = false
    var nearestIntersection: CLLocation?
    var lastLocation: CLLocation?
    fileprivate let motionManager = CMMotionManager()
    let formatter = DateFormatter()
    var pause: Bool = false
    var autoPollTimer: Timer?
    var locationTimer: Timer?
    var pollServerTimer: Timer?
    var initialAttitude: CMAttitude?
    let lwa = LoginWithAmazonProxy.sharedInstance
    var electron : ParticleDevice?
    
    @IBOutlet weak var triggerRelayButton: UIButton!
    @IBOutlet weak var pollServerButton: UIButton!
    @IBOutlet var mainBackground: UIView!
    @IBOutlet weak var infoLabel: UILabel!
    @IBOutlet weak var locationLabel: UILabel!
    @IBOutlet weak var nearestIntersectionLabel: UILabel!
    @IBOutlet weak var speedInstantLabel: UILabel!
    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var recordSensors: UIButton!
    @IBOutlet weak var startButton: UIButton!
    @IBOutlet weak var relayStateView: UIView!
    @IBOutlet weak var textView: UITextView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        var config = Realm.Configuration(readOnly: false, schemaVersion: 3,
                                         migrationBlock: { migration, oldSchemaVersion in
                                            if (oldSchemaVersion < 2) {
                                                // Nothing to do!
                                                // Realm will automatically detect new properties and removed properties
                                                // And will update the schema on disk automatically
                                            }
        })
        config.deleteRealmIfMigrationNeeded = true
        
        Realm.Configuration.defaultConfiguration = config
        realm = try! Realm()
        
        self.becomeFirstResponder()
        self.formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSSS"
        self.locationManager.requestAlwaysAuthorization()
        self.locationManager.requestWhenInUseAuthorization()
        self.relayStateView.layer.borderColor = UIColor.black.cgColor
        self.relayStateView.layer.borderWidth = 1.0
        self.textView.layoutManager.allowsNonContiguousLayout = false
        self.textView.text = ""

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
            locationManager.activityType = CLActivityType.fitness
            locationManager.allowsBackgroundLocationUpdates = true
            locationManager.delegate = self
            locationManager.desiredAccuracy = kCLLocationAccuracyBest
            locationManager.distanceFilter = 0.5
            locationManager.pausesLocationUpdatesAutomatically = true
            //locationManager.showsBackgroundLocationIndicator = true
            //locationManager.startUpdatingLocation()

            locationTimer = Timer.scheduledTimer(timeInterval: 2,
                                                 target: self,
                                                 selector: #selector(self.updateLocation),
                                                 userInfo: nil,
                                                 repeats: true)
        }

        if locationManager.location != nil {
            MapHelper.centerMapOnLocation(mapView: self.mapView, location: locationManager.location!)
        }
        initRealm()
        //setupMapView()
        MapHelper.setupMapView(mapView: mapView, delegate: self, markers: Array(self.intersections))
        print(Realm.Configuration.defaultConfiguration.fileURL!)
        
        if ParticleCloud.sharedInstance().injectSessionAccessToken(token!) {
            infoLabel.text = "session active"
            getDevices()
        } else {
            infoLabel.text = "bad token"
        }
        
        self.updateTextView(text: "application loaded successfully")
    }
    
    override var canBecomeFirstResponder: Bool {
        get { return true }
    }
    
    @objc func updateAutoPollPause() {
        pause = false
    }

    @objc func updateLocation() {
        locationManager.startUpdatingLocation()
    }
    
    @objc func updatePollServerButton() {
        pollServerButton.isEnabled = true
    }

    override func motionEnded(_ motion: UIEventSubtype, with event: UIEvent?) {
        if motion == .motionShake {
            self.infoLabel.text = "shake gesture detected"
        }
    }
    
    /**
     Append the text to the textView, with the current date/time.
     */
    internal func updateTextView(text: String) {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSSS"

        textView.text = textView.text + "[\(formatter.string(from: NSDate() as Date))] \(text)\n"
        
        let bottom = NSMakeRange(textView.text.count - 1, 1)
        textView.scrollRangeToVisible(bottom)
    }

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
                            self.electron = device
                            self.updateTextView(text: "found \(device.name!)")
                            self.pollServerButton.isEnabled = true
                            self.triggerRelayButton.isEnabled = true
                        }
                    }
                }
            }
        }
    }
    
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        return MapHelper.mapView(mapView: mapView, overlay: overlay)
    }

    func initRealm() {
        self.intersections = realm?.objects(Intersection.self)

        if self.intersections.count == 0 {
            try! realm?.write {
                //realm?.add(Intersection(latitude: 44.040030, longitude: -123.080198, title: "18th & Alder"))
                let intersection = Intersection(latitude: 44.040030, longitude: -123.080198, title: "18th & Alder")
                intersection.headings.append(0.1783)   //   0° 10' 42"
                intersection.headings.append(180.1783) // 180° 10' 42"
                realm?.add(intersection)
                #if DEBUG
                realm?.add(Intersection(latitude: 44.084221, longitude: -123.061607, title: "Cambridge Oaks Dr"))
                realm?.add(Intersection(latitude: 44.080277, longitude: -123.067722, title: "Coburg & Willakenzie"))
                realm?.add(Intersection(latitude: 44.045489, longitude: -123.070931, title: "13th Ave Kiosk"))
                realm?.add(Intersection(latitude: 44.045689, longitude: -123.066324, title: "13th & Franklin"))
                realm?.add(Intersection(latitude: 44.056741, longitude: -123.024210, title: "Centennial & Pioneer Pkwy W"))
                realm?.add(Intersection(latitude: 44.056656, longitude: -123.023835, title: "Centennial & Pioneer Pkwy E"))
                #endif
            }
        }
        
        //infoLabel.text = "# intersections: \(intersections.count)"
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

        //if hcKalmanFilter == nil {
        //    self.hcKalmanFilter = HCKalmanAlgorithm(initialLocation: myLocation)
        //}
        //else {
        //    if let hcKalmanFilter = self.hcKalmanFilter {
        //        if resetKalmanFilter == true {
        //            hcKalmanFilter.resetKalman(newStartLocation: myLocation)
        //            resetKalmanFilter = false
        //        }
        //        else {
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
        //        }
        //    }
        //}
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
        
        if polling {
            MapHelper.centerMapOnLocation(mapView: self.mapView, location: myLocation)
        }
        if !pause {
            displayClosestIntersection()
        }
        // stop updating location until next locationTimer tick
        locationManager.stopUpdatingLocation()
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
                    if electron != nil && !pause {
                        //readLedState()
                        readLoopState(silent: true)
                        // only auto-poll at most every 3 seconds
                        autoPollTimer = Timer.scheduledTimer(timeInterval: 3,
                                                             target: self,
                                                             selector: #selector(self.updateAutoPollPause),
                                                             userInfo: nil,
                                                             repeats: false)
                        pause = true
                    }
                    
                    // if the user is not already near an intersection, vibrate to notify
                    if dist < 50.0 && !nearIntersection {
                        nearIntersection = true
                        triggerRelay(relayNumber: "1")
                        AudioServicesPlayAlertSound(SystemSoundID(kSystemSoundID_Vibrate))
                        
                    }
                    
                    // if the user was previously near an intersection, vibrate to notify
                    if dist > 50.0 && nearIntersection {
                        nearIntersection = false
                        AudioServicesPlayAlertSound(SystemSoundID(kSystemSoundID_Vibrate))
                    }
                } else {
                    // polling = false
                    self.relayStateView.backgroundColor = UIColor.white
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
        electron!.getVariable("led_state", completion: { (result:Any?, error:Error?) -> Void in
            if let _ = error {
                // self.relayStateView.backgroundColor = UIColor.gray
                self.updateTextView(text: "failed reading led status from device")
            }
            else {
                if let status = result as? String {
                    if status == "on" {
                        self.relayStateView.backgroundColor = UIColor.green
                    }
                    else {
                        self.relayStateView.backgroundColor = UIColor.red
                    }
                    self.updateTextView(text: "led is \(status)")
                }
            }
        })
    }
    
    func readLoopState(silent: Bool) {
        electron!.getVariable("loop_state", completion: { (result:Any?, error:Error?) -> Void in
            if let _ = error {
                if (!silent) {
                    self.updateTextView(text: "failed reading loop state from device")
                }
            }
            else {
                if let status = result as? Int {
                    if status == 1 {
                        self.relayStateView.backgroundColor = UIColor.green
                    }
                    else {
                        self.relayStateView.backgroundColor = UIColor.red
                    }
                    
                    if (!silent) {
                        self.updateTextView(text: "loop is \(status)")
                    }
                }
            }
        })
    }
    
    func toggleLedState() {
        let task = electron!.callFunction("toggle_led", withArguments: nil) { (resultCode : NSNumber?, error : Error?) -> Void in
            if (error == nil) {
                self.updateTextView(text: "toggle led successful")
            }
        }
        let bytes : Int64 = task.countOfBytesExpectedToReceive
        if bytes > 0 {
            // ..do something with bytesToReceive
        }
    }

    @IBAction func pollServerButtonClick(_ sender: Any) {
        //readLedState()
        updateTextView(text: "polling server")
        readLoopState(silent: false)
        pollServerButton.isEnabled = false
        pollServerTimer = Timer.scheduledTimer(timeInterval: 5,
                                               target: self,
                                               selector: #selector(self.updatePollServerButton),
                                               userInfo: nil,
                                               repeats: false)
    }
    
    @IBAction func pushStartButton(_ sender: Any) {
        if startButton.titleLabel?.text == "Start Trip" {
            startButton.setTitle("Stop Trip", for: .normal)
            polling = true
            self.updateTextView(text: "starting bicycle trip")
        }
        else if startButton.titleLabel?.text == "Stop Trip" {
            startButton.setTitle("Start Trip", for: .normal)
            relayStateView.backgroundColor = UIColor.white
            autoPollTimer?.invalidate()
            locationTimer?.invalidate()
            pollServerTimer?.invalidate()
            pause = false
            polling = false
            self.updateTextView(text: "stopping bicycle trip")
        }
    }
    
    func exportCsv() {
        let fileName = "accelerometer.csv"
        let path = NSURL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(fileName)
        
        var csvText = "Date,Type,x,y,z\n"
        if motionManager.isDeviceMotionAvailable {
            let count = MotionHelper.motionReadings.count
            
            if count > 0 {
                for reading in MotionHelper.motionReadings {
                    let newLine = "\(reading)\n"
                    csvText.append(newLine)
                }
            } else {
                //showErrorAlert("Error", msg: "There is no data to export")
            }
        }
        else {
            let count = MotionHelper.accelerometerReadings.count
            
            if count > 0 {
                for reading in MotionHelper.accelerometerReadings {
                    let newLine = "\(reading)\n"
                    csvText.append(newLine)
                }
                
                for reading in MotionHelper.gyroscopeReadings {
                    let newLine = "\(reading)\n"
                    csvText.append(newLine)
                }
            } else {
                //showErrorAlert("Error", msg: "There is no data to export")
            }
        }

        do {
            try csvText.write(to: path!, atomically: true, encoding: String.Encoding.utf8)
            
            /*let vc = UIActivityViewController(activityItems: [path!], applicationActivities: [])
             vc.excludedActivityTypes = [
             UIActivityType.assignToContact,
             UIActivityType.saveToCameraRoll,
             UIActivityType.postToFlickr,
             UIActivityType.postToVimeo,
             UIActivityType.postToTencentWeibo,
             UIActivityType.postToTwitter,
             UIActivityType.postToFacebook,
             UIActivityType.openInIBooks
             ]*/
            
            if MFMailComposeViewController.canSendMail() {
                let emailController = MFMailComposeViewController()
                emailController.mailComposeDelegate = self
                emailController.setToRecipients(["bwilli11@uoregon.edu"])
                emailController.setSubject("Accelerometer data")
                emailController.setMessageBody("readings from accelerometer and gyro", isHTML: false)
                
                if let data = NSData(contentsOfFile: "\(NSTemporaryDirectory())\(fileName)") {
                    emailController.addAttachmentData(data as Data, mimeType: "text/csv", fileName: fileName)
                    
                }
                
                present(emailController, animated: true, completion: nil)
            }
            
            //present(vc, animated: true, completion: nil)
        } catch {
            print("Failed to create file")
            print("\(error)")
        }
    }
    
    func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith: MFMailComposeResult, error: Error?) {
        controller.dismiss(animated: true, completion: nil)
    }
    
    func triggerRelay(relayNumber: String) {
        self.updateTextView(text: "triggering relay #\(relayNumber)")
        
        let task = electron!.callFunction("relay_on", withArguments: [relayNumber]) { (resultCode : NSNumber?, error : Error?) -> Void in
            if (error == nil) {
                self.readLoopState(silent: false)
            }
            else {
                self.updateTextView(text: "error triggering relay")
            }
        }
        let bytes : Int64 = task.countOfBytesExpectedToReceive
        if bytes > 0 {
            // ..do something with bytesToReceive
        }
    }
    
    func requestDidSucceed(_ apiResult: APIResult) {
        switch(apiResult.api) {
        case API.authorizeUser:
            print("Authorized")
            lwa.getAccessToken(delegate: self)
        case API.getAccessToken:
            print("Login successfully!")
            LoginWithAmazonToken.sharedInstance.loginWithAmazonToken = apiResult.result as! String?
            let storyboard = UIStoryboard(name: "Main", bundle: nil)
            let controller = storyboard.instantiateViewController(withIdentifier: "AlexaViewController") as! AlexaViewController
            controller.electron = self.electron
            controller.intersections = self.intersections
            self.present(controller, animated: true, completion: nil)
        case API.clearAuthorizationState:
            print("Logout successfully!")
        default:
            return
        }
    }
    
    func requestDidFail(_ errorResponse: APIError) {
        print("Error: \(errorResponse.error.message)")
    }
    
    @IBAction func recordButton(_ sender: Any) {
        if recordSensors.title(for: .normal) == "record" {
            MotionHelper.startMotionUpdates(motionManager: self.motionManager)
            recordSensors.setImage(UIImage(named: "stop-30px.png"), for: .normal)
            recordSensors.setTitle("stop", for: .normal)
        } else if recordSensors.title(for: .normal) == "stop" {
            MotionHelper.stopMotionUpdates(motionManager: self.motionManager)
            recordSensors.setImage(UIImage(named: "email-30px.png"), for: .normal)
            recordSensors.setTitle("send", for: .normal)
        } else {
            // e-mail csv file
            exportCsv()
            recordSensors.setImage(UIImage(named: "record-30px.png"), for: .normal)
            recordSensors.setTitle("record", for: .normal)
        }
    }
    
    @IBAction func triggerRelayButtonClick(_ sender: Any) {
        let number = "1"
        triggerRelay(relayNumber: number)
    }
    
    @IBAction func loginWithAmazonButtonClick(_ sender: Any) {
        lwa.login(delegate: self)
    }
}

