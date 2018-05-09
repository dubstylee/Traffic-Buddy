//
//  ViewController.swift
//  Traffic Buddy
//
//  Created by Brian Williams on 10/1/17.
//  Copyright © 2017-18 Brian Williams. All rights reserved.
//

import AVFoundation
import AWSS3
import CoreLocation
import CoreMotion
import LoginWithAmazon
import MessageUI
import Particle_SDK
import Realm
import RealmSwift
import UIKit

class ViewController: UIViewController, CLLocationManagerDelegate, AVAudioPlayerDelegate, AVAudioRecorderDelegate, MFMailComposeViewControllerDelegate, AIAuthenticationDelegate {
    
    let formatter = DateFormatter()
    let kNumReportSteps = 3
    let locationManager = CLLocationManager()
    let lwa = LoginWithAmazonProxy.sharedInstance
    let metersPerSecToMilesPerHour = 2.23694
    let motionManager = CMMotionManager()
    let realm = RealmHelper.sharedInstance

    /* appState
     * 1: trip off
     * 2: trip on, but outside of 200 ft threshold
     * 3: trip on, within 200 ft threshold
     * 4: trip on, within 50 ft, triggering relay
     */
    var appState = 1
    var autoPollDistance = 200.0
    var autoTriggerDistance = 100.0
    var dist = 9999999.9 // default to far away from particle box
    var electron : ParticleDevice?
    var heading: CLHeading?
    var isLoggedIn = false
    var isNearIntersection = false
    var isOnTrip = false
    var isPaused = false
    var isRecordingReport = false
    var lastLocation: CLLocation?
    var lastSpeed = 0.0
    var nearestIntersection: CLLocation?
    var particleToken: String?
    var reportStep = 1
    var useSpeedTrigger = false

    var autoPollTimer: Timer?
    var locationTimer: Timer?
    var pollServerTimer: Timer?

    // Alexa-related variables
    private let audioSession = AVAudioSession.sharedInstance()
    private var audioRecorder: AVAudioRecorder!
    private var audioPlayer: AVAudioPlayer!
    private var avsClient = AlexaVoiceServiceClient()
    private var avsToken: String?
    private var isRecording = false
    
    @IBOutlet weak var alexaButton: UIButton!
    @IBOutlet weak var infoLabel: UILabel!
//    @IBOutlet weak var lightCheckbox: CheckBox!
    @IBOutlet weak var locationLabel: UILabel!
    @IBOutlet weak var loginButton: UIButton!
    @IBOutlet weak var mainBackground: UIView!
    @IBOutlet weak var nearestIntersectionLabel: UILabel!
//    @IBOutlet weak var otherInfoCheckbox: CheckBox!
    @IBOutlet weak var pollServerButton: UIButton!
    @IBOutlet weak var recordReportButton: UIButton!
    @IBOutlet weak var recordSensorsButton: UIButton!
    @IBOutlet weak var relayStateLabel: UITextView!
    @IBOutlet weak var relayStateView: UIView!
    @IBOutlet weak var speedLabel: UILabel!
    @IBOutlet weak var startButton: UIButton!
    @IBOutlet weak var textView: UITextView!
    @IBOutlet weak var triggerRelayButton: UIButton!
//    @IBOutlet weak var weatherCheckbox: CheckBox!
    
    // MARK: UIViewController methods
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSSS"
        locationManager.requestAlwaysAuthorization()
        locationManager.requestWhenInUseAuthorization()
        relayStateView.layer.borderColor = UIColor.black.cgColor
        relayStateView.layer.borderWidth = 1.0
        textView.layoutManager.allowsNonContiguousLayout = false
        textView.text = ""
        
        // setup Alexa Voice Services client
        avsClient.pingHandler = self.pingHandler
        avsClient.syncHandler = self.syncHandler
        avsClient.directiveHandler = self.directiveHandler
        avsClient.downchannelHandler = self.downchannelHandler
        
        if let path = Bundle.main.path(forResource: "particle", ofType: "conf") {
            do {
                particleToken = try String(contentsOfFile: path, encoding: String.Encoding.utf8)
                particleToken = particleToken!.trimmingCharacters(in: NSCharacterSet.newlines)
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
            locationManager.headingFilter = 5.0
            locationManager.startUpdatingHeading()
            
            locationTimer = Timer.scheduledTimer(timeInterval: 1,
                                                 target: self,
                                                 selector: #selector(self.updateLocation),
                                                 userInfo: nil,
                                                 repeats: true)
        }

        if ParticleCloud.sharedInstance().injectSessionAccessToken(particleToken!) {
            infoLabel.text = "session active"
            getParticleDevices()
        } else {
            infoLabel.text = "bad token"
        }

        if let speedTrigger = realm.getObjects(type: ConfigItem.self)?.filter("key = 'UseSpeedTrigger'").first as? ConfigItem {
            useSpeedTrigger = Bool(speedTrigger.value)!
        }

        updateTextView(text: "application loaded successfully")
    }
    
    override func viewWillAppear(_ animated: Bool) {
        navigationController?.setNavigationBarHidden(true, animated: animated)
        super.viewWillAppear(animated)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        navigationController?.setNavigationBarHidden(false, animated: animated)
        super.viewWillDisappear(animated)
    }
    
    // MARK: Objective-C delegate methods
    @objc func updateAutoPollPause() {
        isPaused = false
    }
    
    @objc func updateLocation() {
        locationManager.startUpdatingLocation()
    }
    
    @objc func updatePollServerButton() {
        pollServerButton.isEnabled = true
    }
    
    // MARK: AIAuthenticationDelegate methods
    /**
     The API request to LoginWithAmazon failed.
     
     - parameter errorResponse: An `APIError` describing the response of the request.
     */
    func requestDidFail(_ errorResponse: APIError) {
        print("Error: \(errorResponse.error.message)")
    }
    
    /**
     The API request to LoginWithAmazon was successful.
     
     - parameter apiResult: The `APIResult` of the request.
     */
    func requestDidSucceed(_ apiResult: APIResult) {
        switch(apiResult.api) {
        case API.authorizeUser:
            print("Authorized")
            lwa.getAccessToken(delegate: self)
        case API.getAccessToken:
            print("Login successfully!")
            LoginWithAmazonToken.sharedInstance.loginWithAmazonToken = apiResult.result as! String?
            loginButton.setImage(UIImage(named: "logout-30px.png"), for: .normal)
            isLoggedIn = true
            alexaButton.isHidden = false
            recordReportButton.isHidden = false
        case API.clearAuthorizationState:
            print("Logout successfully!")
            loginButton.setImage(UIImage(named: "amazon-30px.png"), for: .normal)
            isLoggedIn = false
            alexaButton.isHidden = true
            recordReportButton.isHidden = true
        default:
            return
        }
    }

    // MARK: AVAudioPlayerDelegate methods
    /**
     An error occurred during audio decoding.
     
     - parameter player: The `AVAudioPlayer` instance.
     - parameter error: The `Error` that occurred.
     */
    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        print("Audio player has an error: \(String(describing: error?.localizedDescription))")
    }
    
    /**
     The audio player finished playing.
     
     - parameter player: The `AVAudioPlayer` instance.
     - parameter flag: Whether or not the audio player finished successfully.
     */
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        print("Audio player is finished playing")
        infoLabel.text = "Cycle Buddy"
        
        avsClient.sendEvent(namespace: "SpeechSynthesizer", name: "SpeechFinished", token: avsToken!)
        if isRecordingReport {
            startRecordingNextStep()
        }
    }
    
    // MARK: AVAudioRecorderDelegate methods
    /**
     The audio recorder finished recording.
     
     - parameter recorder: The `AVAudioRecorder` instance.
     - parameter flag: Whether or not the audio recorder finished successfully.
     */
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        print("Audio recorder is finished recording")
    }
    
    /**
     An error occurred during audio encoding.
     
     - parameter recorder: The `AVAudioRecorder` instance.
     - parameter error: The `Error` that occurred.
     */
    func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        print("Audio recorder has an error: \(String(describing: error?.localizedDescription))")
    }
    
    // MARK: CLLocationManagerDelegate methods
    /**
     Called each time a user changes location access preference.
     
     - parameter manager: The `CLLocationManager` instance.
     - parameter status: The new `CLAuthorizationStatus` after the change.
     */
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        if status == .authorizedWhenInUse {
            print("User allowed us to access location")
        }
    }
    
    /**
     Called whenever the location manager fails to update the location.
     
     - parameter manager: The `CLLocationManager` instance.
     - parameter error: The `Error` that occurred.
     */
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Did location updates is called but failed getting location \(error)")
    }
    
    /**
     Called each time the location manager reports a change in the current heading.
     
     - parameter manager: The `CLLocationManager` instance.
     - parameter newHeading: The new `CLHeading` after the change.
     */
    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        self.heading = newHeading
    }
    
    /**
     Called each time the location manager reports a change in location.
     
     - parameter manager: The `CLLocationManager` instance.
     - parameter locations: An array of `CLLocation` objects that have been updated.
     */
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let myLocation = locations.first!
        let locValue = myLocation.coordinate
        var instantSpeed = myLocation.speed
        
        let latString = locValue.latitude > 0 ? "\(locValue.latitude)° N" : "\(-locValue.latitude)° S"
        let longString = locValue.longitude > 0 ? "\(locValue.longitude)° E" : "\(-locValue.longitude)° W"
        
        locationLabel.text = "\(latString) \(longString)"
        
        instantSpeed = max(instantSpeed, 0.0)
        speedLabel.text = String(format: "Current Speed: %.1f mph", (instantSpeed * metersPerSecToMilesPerHour))
        
        if !isPaused {
            displayClosestIntersection()
        }
        
        if MotionHelper.accidentDetected {
            MotionHelper.accidentDetected = false
            
            updateTextView(text: "sensor threshold reached (crash detected)")
            wakeAlexa()
        }
        
        lastLocation = myLocation
        lastSpeed = instantSpeed
        locationManager.stopUpdatingLocation()
    }
    
    // MARK: MFMailComposeViewControllerDelegate functions
    /**
     Called after sending or cancel composed e-mail.
     
     - parameters controller: The `MFMailComposeViewController` instance.
     - parameters didFinishWith: The `MFMailComposeResults` of the action.
     - parameters error: If an error occurred, the `Error` instance.
     */
    func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith: MFMailComposeResult, error: Error?) {
        controller.dismiss(animated: true, completion: nil)
    }
    
    
    // MARK: AVS delegates
    /**
     A directive handler function for Alexa Voice Services.
     
     - parameter directives: An array of `DirectiveData` received back from AVS.
     */
    func directiveHandler(directives: [DirectiveData]) {
        for directive in directives {
            if (directive.contentType == "application/json") {
                do {
                    let jsonData = try JSONSerialization.jsonObject(with: directive.data) as! [String:Any]
                    let directiveJson = jsonData["directive"] as! [String:Any]
                    let header = directiveJson["header"] as! [String:String]
                    
                    // store the token for the Speak directive
                    if (header["name"] == "Speak") {
                        let payload = directiveJson["payload"] as! [String:String]
                        avsToken = payload["token"]!
                    }
                } catch let ex {
                    print("Directive data has an error: \(ex.localizedDescription)")
                }
            }
        }
        
        for directive in directives {
            // play the received audio
            if (directive.contentType == "application/octet-stream") {
                DispatchQueue.main.async {
                    () -> Void in
                    self.infoLabel.text = "Alexa is speaking"
                }
                do {
                    avsClient.sendEvent(namespace: "SpeechSynthesizer", name: "SpeechStarted", token: avsToken!)
                    
                    try audioSession.setCategory(AVAudioSessionCategoryPlayAndRecord, with:[AVAudioSessionCategoryOptions.allowBluetooth, AVAudioSessionCategoryOptions.allowBluetoothA2DP, AVAudioSessionCategoryOptions.defaultToSpeaker])
                    try audioPlayer = AVAudioPlayer(data: directive.data)
                    audioPlayer.delegate = self
                    audioPlayer.prepareToPlay()
                    audioPlayer.volume = 1.0
                    audioPlayer.play()
                } catch let ex {
                    print("Audio player has an error: \(ex.localizedDescription)")
                }
            }
        }
    }
    
    /**
     A downchannel handler function for Alexa Voice Services.
     
     - parameter directive: The directive to be sent to AVS.
     */
    func downchannelHandler(directive: String) {
        // data being sent to Alexa
        do {
            let jsonData = try JSONSerialization.jsonObject(with: directive.data(using: String.Encoding.utf8)!) as! [String:Any]
            let directiveJson = jsonData["directive"] as! [String:Any]
            let header = directiveJson["header"] as! [String:String]
            if (header["name"] == "StopCapture") {
                // Handle StopCapture
            } else if (header["name"] == "SetAlert") {
                // Handle SetAlert
            }
        } catch let ex {
            print("Downchannel error: \(ex.localizedDescription)")
        }
    }
    
    /**
     A ping handler function for Alexa Voice Services.
     
     - parameter success: Whether or not the ping was successful.
     */
    func pingHandler(success: Bool) {
        DispatchQueue.main.async {
            () -> Void in
            if (success) {
                self.infoLabel.text = "Ping success!"
            } else {
                self.infoLabel.text = "Ping failure!"
            }
        }
    }
    
    /**
     A sync handler function for Alexa Voice Services.
     
     - parameter success: Whether or not the sync was successful.
     */
    func syncHandler(success: Bool) {
        DispatchQueue.main.async {
            () -> Void in
            if (success) {
                self.infoLabel.text = "Sync success!"
            } else {
                self.infoLabel.text = "Sync failure!"
            }
        }
    }
    
    // MARK: Other methods and functions
    /**
     Update the display with the distance and name of the nearest intersection.
     */
    func displayClosestIntersection()
    {
        if CLLocationManager.locationServicesEnabled() {
            // set up array of intersections
            var intersections = [Intersection]()
            if let dbObjs = realm.getObjects(type: Intersection.self) {
                for obj in dbObjs {
                    if let intersection = obj as? Intersection {
                        intersections.append(intersection)
                    }
                }
            }
            if let distanceThreshold = realm.getObjects(type: ConfigItem.self)?.filter("key = 'AutoPollDistance'").first as? ConfigItem {
                autoPollDistance = Double(distanceThreshold.value)!
            }

            // calculate the auto trigger distance based on speed
            if useSpeedTrigger {
                if let triggerThreshold = realm.getObjects(type: ConfigItem.self)?.filter("key = 'DistanceThresholdSeconds'").first as? ConfigItem {
                    autoTriggerDistance = Double(triggerThreshold.value)! * lastSpeed * 3.28 // speed is measured in meters per second
                }
            }
            else {
                if let triggerThreshold = realm.getObjects(type: ConfigItem.self)?.filter("key = 'DistanceThresholdFeet'").first as? ConfigItem {
                    autoTriggerDistance = Double(triggerThreshold.value)!
                }
            }

            let currentLocation = locationManager.location!
            let nearestIntersection = getClosestIntersection(intersections: intersections, closestToLocation: currentLocation)
            
            if nearestIntersection != nil {
                let intersectionLocation = nearestIntersection!.getLocation()
                
                dist = metersToFeet(from: intersectionLocation.distance(from: currentLocation))
                if dist < autoPollDistance && isOnTrip {
                    appState = 2
                    
                    // auto-poll server within distance threshold
                    if electron != nil && !isPaused {
                        isPaused = true
                        readLoopState(silent: true)
                        
                        // only auto-poll at most every 3 seconds
                        autoPollTimer = Timer.scheduledTimer(timeInterval: 3,
                                                             target: self,
                                                             selector: #selector(self.updateAutoPollPause),
                                                             userInfo: nil,
                                                             repeats: false)
                    }
                    
                    // if the user was previously near an intersection, vibrate to notify
                    if dist > 200 && isNearIntersection {
                        isNearIntersection = false
                        appState = 3
                        
                        AudioServicesPlayAlertSound(SystemSoundID(kSystemSoundID_Vibrate))
                    }
                    
                    // if the user is not already near an intersection, vibrate to notify
                    if dist < autoTriggerDistance && !isNearIntersection {
                        var headingThreshold = 10.0
                        if let dbValue = realm.getObjects(type: ConfigItem.self)?.filter("key = 'HeadingThreshold'").first as? ConfigItem {
                            if let val = Double(dbValue.value) {
                                headingThreshold = val
                            }
                        }
                        
                        // check if we are heading within an acceptable degree of the intersection's headings
                        for h in nearestIntersection!.headings {
                            if abs((heading?.trueHeading)! - h) < headingThreshold {
                                isNearIntersection = true
                                appState = 4
                                
                                triggerRelay(relayNumber: "1", manual: false)
                                AudioServicesPlayAlertSound(SystemSoundID(kSystemSoundID_Vibrate))
                                break
                            }
                        }
                    }
                } else {
                    // either we are not on a trip, or not within distance threshold
                    // self.relayStateView.backgroundColor = UIColor.lightGray
                }
                
                nearestIntersectionLabel.text = String(format: "%.0f feet from \(nearestIntersection!.title)", dist)
            } else {
                nearestIntersectionLabel.text = "Unable to determine nearest intersection."
            }
        }
        
        switch self.appState {
        case 1: self.relayStateView.backgroundColor = UIColor.lightGray
            break
        case 2: self.relayStateView.backgroundColor = UIColor.red
            break
        case 3: self.relayStateView.backgroundColor = UIColor.yellow
            break
        case 4: self.relayStateView.backgroundColor = UIColor.green
            break
        default: break
        }
    }
    
    /**
     Export a CSV file of sensor data and send via e-mail.
     */
    func exportAndSendCsv() {
        formatter.dateFormat = "yyyyMMddHHmmss"
        
        let dateString = formatter.string(from: Date())
        let fileName = "sensor\(dateString).csv"
        let path = NSURL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(fileName)
        
        var csvText = "Date,Type,val\n"
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
        } else {
            let count = MotionHelper.accelerometerReadings.count
            csvText = "Date,Type,x,y,z\n"
            
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
        } catch {
            print("Failed to create file")
            print("\(error)")
        }
    }
    
    /**
     Get the closest intersection to the current location or return nil.
     
     - parameter intersections: An array of `Intersection` objects to compare with the current location.
     - parameter location: The current `CLLocation` to find the nearest intersection to.
     */
    func getClosestIntersection(intersections: [Intersection], closestToLocation location: CLLocation) -> Intersection? {
        if let closestIntersection = intersections.min(by: { location.distance(from: $0.getLocation()) < location.distance(from: $1.getLocation()) }) {
            return closestIntersection
        } else {
            nearestIntersectionLabel.text = "locations is empty"
            return nil
        }
    }
    
    /**
     Get a list of devices from the Particle cloud.
     */
    func getParticleDevices() {
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
    
    /**
     Convert a value from meters to feet.
     
     - parameter from: The number of meters to convert.
     */
    func metersToFeet(from: Double) -> Double {
        return from * 3.28084
    }
    
    /**
     Prepare an audio session for recording.
     */
    func prepareAudioSession() {
        do {
            let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            let fileURL = directory.appendingPathComponent(Settings.Audio.TEMP_FILE_NAME)
            try audioRecorder = AVAudioRecorder(url: fileURL, settings: Settings.Audio.RECORDING_SETTING as [String : AnyObject])
            try audioSession.setCategory(AVAudioSessionCategoryPlayAndRecord, with:[AVAudioSessionCategoryOptions.allowBluetooth, AVAudioSessionCategoryOptions.allowBluetoothA2DP, AVAudioSessionCategoryOptions.defaultToSpeaker])
        } catch let ex {
            print("Audio session has an error: \(ex.localizedDescription)")
        }
    }
    
    /**
     Poll the Electron device for the current loop state.
     
     - parameter silent: Whether or not the result should be displayed in the textView.
     */
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
                        self.relayStateLabel.text = "Relay State\nOn";
                    }
                    else {
                        self.relayStateLabel.text = "Relay State\nOff";
                    }
                    
                    if (!silent) {
                        self.updateTextView(text: "loop is \(status == 0 ? "off" : "on")")
                    }
                }
            }
        })
    }
    
    /**
     Upload a file to Amazon S3 storage.
     
     - parameter url: The `URL` of the file to upload.
     */
    internal func s3Upload(url: URL) {
        let credentialsProvider = AWSStaticCredentialsProvider(accessKey: Settings.S3.S3_ACCESS_KEY, secretKey: Settings.S3.S3_SECRET_KEY)
        let configuration = AWSServiceConfiguration(region:.USEast1, credentialsProvider:credentialsProvider)
        
        formatter.dateFormat = "yyyyMMdd HHmmss.SSSS"
        let dateString = formatter.string(from: NSDate() as Date)
        
        AWSServiceManager.default().defaultServiceConfiguration = configuration
        let transferManager = AWSS3TransferManager.default()
        let uploadRequest = AWSS3TransferManagerUploadRequest()!
        
        uploadRequest.bucket = "cycle-buddy-reports"
        uploadRequest.key = "\(dateString).wav"
        uploadRequest.body = url
        
        // upload the initial file
        transferManager.upload(uploadRequest).continueWith(executor: AWSExecutor.mainThread(), block: {
            (task:AWSTask<AnyObject>) -> Any? in
            
            if let error = task.error as NSError? {
                if error.domain == AWSS3TransferManagerErrorDomain, let code = AWSS3TransferManagerErrorType(rawValue: error.code) {
                    switch code {
                    case .cancelled, .paused:
                        break
                    default:
                        print("Error uploading: \(String(describing: uploadRequest.key)) Error: \(error)")
                    }
                } else {
                    print("Error uploading: \(String(describing: uploadRequest.key)) Error: \(error)")
                }
                self.updateTextView(text: "file upload failed")
                return nil
            }
            
            _ = task.result
            print("Upload complete for: \(String(describing: uploadRequest.key))")
            self.updateTextView(text: "file uploaded successfully")
            return nil
        })
        
        // now upload the companion text file
        do {
            var locationString = "string of gps coords or whatever location info"
            let textUrl = NSURL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("location.txt")
            
            if lastLocation != nil {
                locationString = String(describing: lastLocation!.coordinate)
            }
            try locationString.write(to: textUrl!, atomically: true, encoding: String.Encoding.utf8)
            
            uploadRequest.bucket = "cycle-buddy-reports"
            uploadRequest.key = "\(dateString).txt"
            uploadRequest.body = textUrl!
            
            transferManager.upload(uploadRequest).continueWith(executor: AWSExecutor.mainThread(), block: {
                (task:AWSTask<AnyObject>) -> Any? in
                
                if let error = task.error as NSError? {
                    if error.domain == AWSS3TransferManagerErrorDomain, let code = AWSS3TransferManagerErrorType(rawValue: error.code) {
                        switch code {
                        case .cancelled, .paused:
                            break
                        default:
                            print("Error uploading: \(String(describing: uploadRequest.key)) Error: \(error)")
                        }
                    } else {
                        print("Error uploading: \(String(describing: uploadRequest.key)) Error: \(error)")
                    }
                    return nil
                }
                
                _ = task.result
                print("Upload complete for: \(String(describing: uploadRequest.key))")
                return nil
            })
        } catch let ex {
            print("Error writing location information: \(ex.localizedDescription)")
        }
    }
    
    /**
     Start recording the next part of the accident report.
    */
    func startRecordingNextStep() {
        if recordReportButton.title(for: .normal) == "PRESS TO RECORD REPORT" {
            recordReportButton.setImage(UIImage(named: "stop-30px.png"), for: .normal)
            recordReportButton.setTitle("PRESS STOP TO FINISH", for: .normal)
            
            audioRecorder.record()
        }
    }
    
    /**
     Trigger a relay using the Particle API.
     
     - parameter relayNumber: The number of the relay to send a trigger to.
     */
    func triggerRelay(relayNumber: String, manual: Bool) {
        if dist > 100 && manual {
            updateTextView(text: "too far away (> 100ft)")
        } else {
            updateTextView(text: "triggering relay #\(relayNumber)")
            
            let task = electron!.callFunction("relay_on", withArguments: [relayNumber]) {
                (resultCode: NSNumber?, error: Error?) -> Void in
                if (error == nil) {
                    // NOTE: readLoopState() may return "off" even after triggering the relay
                    // because the loop state is not updated until the box receives a message back
                    // from the controller that the relay on message was received
                    self.readLoopState(silent: false)
                } else {
                    self.updateTextView(text: "error triggering relay")
                }
            }
            
            let bytes = task.countOfBytesExpectedToReceive
            if bytes > 0 {
                // ..do something with bytesToReceive
            }
        }
    }
    
    /**
     Append the text to the textView, with the current date/time.
     
     - parameter text: The `String` to append to the textView.
     */
    internal func updateTextView(text: String) {
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss" // .SSSS milliseconds
        
        textView.text = textView.text + "[\(formatter.string(from: NSDate() as Date))] \(text)\n"
        
        let bottom = NSMakeRange(textView.text.count - 1, 1)
        textView.scrollRangeToVisible(bottom)
    }
    
    /**
     Send the designated Alexa wake word audio to AVS.
     */
    func wakeAlexa() {
        do {
            let url = Bundle.main.url(forResource: "wake", withExtension: "wav")
            let wake = try Data(contentsOf: url!)
            
            avsClient.postRecording(audioData: wake)
            
            // https://developer.amazon.com/docs/alexa-voice-service/recommended-media-support.html
            // mp3, aac, wav, etc.
            // try avsClient.postRecording(audioData: Data(contentsOf: fileURL))
        } catch let ex {
            print("AVS Client threw an error: \(ex.localizedDescription)")
            infoLabel.text = "wake word audio file not found"
        }
    }
    
    // MARK: IBActions
    @IBAction func loginWithAmazonButtonClick(_ sender: Any) {
        if (!isLoggedIn) {
            lwa.login(delegate: self)
        } else {
            let logoutConfirm = UIAlertController(title: "Logout", message: "You will no longer be able to interact with Alexa.", preferredStyle: UIAlertControllerStyle.alert)
            
            logoutConfirm.addAction(UIAlertAction(title: "Yes", style: .default, handler: {
                (action: UIAlertAction!) in
                self.lwa.logout(delegate: self)
            }))
            
            logoutConfirm.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: {
                (action: UIAlertAction!) in
                print("User cancelled logout.")
            }))
            
            present(logoutConfirm, animated: true, completion: nil)
        }
    }
    
    @IBAction func pollServerButtonClick(_ sender: Any) {
        updateTextView(text: "polling server")
        readLoopState(silent: false)
        pollServerButton.isEnabled = false
        pollServerTimer = Timer.scheduledTimer(timeInterval: 5,
                                               target: self,
                                               selector: #selector(self.updatePollServerButton),
                                               userInfo: nil,
                                               repeats: false)
    }
    
    @IBAction func recordButtonCancel(_ sender: Any) {
        if (self.isRecording) {
            audioRecorder.stop()
            self.isRecording = false
        }
    }
    
    @IBAction func recordButtonDown(_ sender: Any) {
        prepareAudioSession()
        
        audioRecorder.prepareToRecord()
        audioRecorder.record()
        isRecording = true
    }
    
    @IBAction func recordButtonUp(_ sender: Any) {
        if (self.isRecording) {
            isRecording = false
            audioRecorder.stop()
            
            do {
                try avsClient.postRecording(audioData: Data(contentsOf: audioRecorder.url))
            } catch let ex {
                print("AVS Client threw an error: \(ex.localizedDescription)")
            }
        }
    }

    @IBAction func recordReportButtonClick(_ sender: Any) {
//        if recordReportButton.title(for: .normal) == "PRESS TO RECORD REPORT" {
//            recordReportButton.setImage(UIImage(named: "stop-30px.png"), for: .normal)
//            recordReportButton.setTitle("PRESS STOP TO FINISH", for: .normal)
//
//            if (reportStep == 1) {
//                weatherCheckbox.isHidden = false
//                lightCheckbox.isHidden = false
//                otherInfoCheckbox.isHidden = false
//                prepareAudioSession()
//                audioRecorder.prepareToRecord()
//            }
//            audioRecorder.record()
//            isRecordingReport = true
//        }
//        else if recordReportButton.title(for: .normal) == "PRESS STOP TO FINISH" {
//            recordReportButton.setImage(UIImage(named: "record-30px.png"), for: .normal)
//            recordReportButton.setTitle("PRESS TO RECORD REPORT", for: .normal)
//
//            if (reportStep < kNumReportSteps) {
//                // notify Alexa to move to the next step
//                let url = Bundle.main.url(forResource: "step", withExtension: "wav")
//                do {
//                    try avsClient.postRecording(audioData: Data(contentsOf: url!))
//                } catch let ex {
//                    print("AVS Client threw an error: \(ex.localizedDescription)")
//                }
//
//                audioRecorder.pause()
//                switch reportStep {
//                case 1: weatherCheckbox.isChecked = true
//                    break
//                case 2: lightCheckbox.isChecked = true
//                    break
//                case 3: otherInfoCheckbox.isChecked = true
//                    break
//                default: break
//                }
//                reportStep += 1
//            }
//            else {
//                reportStep = 1
//                isRecordingReport = false
//                weatherCheckbox.isHidden = true
//                weatherCheckbox.isChecked = false
//                lightCheckbox.isHidden = true
//                lightCheckbox.isChecked = false
//                otherInfoCheckbox.isHidden = true
//                otherInfoCheckbox.isChecked = false
//                audioRecorder.stop()
//                s3Upload(url: audioRecorder.url)
//
//                // notify Alexa that we are done
//                let url = Bundle.main.url(forResource: "finish", withExtension: "wav")
//                do {
//                    try avsClient.postRecording(audioData: Data(contentsOf: url!))
//                } catch let ex {
//                    print("AVS Client threw an error: \(ex.localizedDescription)")
//                }
//            }
//        }
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let controller = storyboard.instantiateViewController(withIdentifier: "ReportView")
        self.navigationController?.pushViewController(controller, animated: true)
    }
    
    @IBAction func recordSensorsButtonClick(_ sender: Any) {
        if recordSensorsButton.title(for: .normal) == "record" {
            MotionHelper.isRecordingSensors = true
            recordSensorsButton.setImage(UIImage(named: "stop-30px.png"), for: .normal)
            recordSensorsButton.setTitle("stop", for: .normal)
        } else if recordSensorsButton.title(for: .normal) == "stop" {
            MotionHelper.isRecordingSensors = false
            recordSensorsButton.setImage(UIImage(named: "email-30px.png"), for: .normal)
            recordSensorsButton.setTitle("send", for: .normal)
        } else {
            // e-mail csv file
            exportAndSendCsv()
            recordSensorsButton.setImage(UIImage(named: "record-30px.png"), for: .normal)
            recordSensorsButton.setTitle("record", for: .normal)
        }
    }
    
    @IBAction func settingsButtonClick(_ sender: Any) {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let controller = storyboard.instantiateViewController(withIdentifier: "SettingsView")
        self.navigationController?.pushViewController(controller, animated: true)
    }
    
    @IBAction func triggerRelayButtonClick(_ sender: Any) {
        let number = "1"
        triggerRelay(relayNumber: number, manual: true)
    }
    
    @IBAction func tripButtonClick(_ sender: Any) {
        if startButton.titleLabel?.text == "Start Trip" {
            startButton.setTitle("Stop Trip", for: .normal)
            appState = 2
            isOnTrip = true
            updateTextView(text: "starting bicycle trip")
//            relayStateView.backgroundColor = UIColor.red
            MotionHelper.startMotionUpdates(motionManager: self.motionManager)
        }
        else if startButton.titleLabel?.text == "Stop Trip" {
            startButton.setTitle("Start Trip", for: .normal)
            autoPollTimer?.invalidate()
            locationTimer?.invalidate()
            pollServerTimer?.invalidate()
            isPaused = false
            appState = 1
            isOnTrip = false
            updateTextView(text: "stopping bicycle trip")
//            relayStateView.backgroundColor = UIColor.lightGray
            MotionHelper.stopMotionUpdates(motionManager: self.motionManager)
        }
    }
}
