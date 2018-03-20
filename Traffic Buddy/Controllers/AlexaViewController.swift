//
//  AlexaViewController.swift
//  Traffic Buddy
//
//  Created by Brian Williams on 2/27/18.
//  Copyright © 2018 Brian Williams. All rights reserved.
//

import UIKit
import AVFoundation
import MapKit
import Particle_SDK
import Realm
import RealmSwift

class AlexaViewController: UIViewController, AVAudioPlayerDelegate, AVAudioRecorderDelegate, MKMapViewDelegate {

    @IBOutlet weak var recordButton: UIButton!
    @IBOutlet weak var recordSensorsButton: UIButton!
    @IBOutlet weak var infoLabel: UILabel!
    @IBOutlet weak var startButton: UIButton!
    @IBOutlet weak var pollServerButton: UIButton!
    @IBOutlet weak var triggerRelayButton: UIButton!
    @IBOutlet weak var relayStateView: UIView!
    @IBOutlet weak var textView: UITextView!
    @IBOutlet weak var mapView: MKMapView!
    var myPhoton : ParticleDevice?
    var pollServerTimer: Timer?
    var intersections: Results<Intersection>!
    
    /*
    @IBOutlet weak var pingBtn: UIButton!
    @IBOutlet weak var startDownchannelBtn: UIButton!
    @IBOutlet weak var pushToTalkBtn: UIButton!
    @IBOutlet weak var wakeWordBtn: UIButton!
    @IBOutlet weak var debugLabel: UILabel!
    */
    private let audioSession = AVAudioSession.sharedInstance()
    private var audioRecorder: AVAudioRecorder!
    private var audioPlayer: AVAudioPlayer!
    private var isRecording = false
    
    private var avsClient = AlexaVoiceServiceClient()
    private var speakToken: String?
    
    //private var snowboy: SnowboyWrapper!
    private var snowboyTimer: Timer!
    private var snowboyTempSoundFileURL: URL!
    private var stopCaptureTimer: Timer!
    private var isListening = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.relayStateView.layer.borderColor = UIColor.black.cgColor
        self.relayStateView.layer.borderWidth = 1.0
        self.textView.layoutManager.allowsNonContiguousLayout = false
        self.textView.text = ""
        
        //snowboy = SnowboyWrapper(resources: Settings.WakeWord.RESOURCE, modelStr: Settings.WakeWord.MODEL)
        //snowboy.setSensitivity(Settings.WakeWord.SENSITIVITY)
        //snowboy.setAudioGain(Settings.WakeWord.AUDIO_GAIN)
        
        avsClient.pingHandler = self.pingHandler
        avsClient.syncHandler = self.syncHandler
        avsClient.directiveHandler = self.directiveHandler
        avsClient.downchannelHandler = self.downchannelHandler
        
        self.becomeFirstResponder()
        
        if myPhoton != nil {
            self.pollServerButton.isEnabled = true
            self.triggerRelayButton.isEnabled = true
        }
        setupMapView()
    }
    
    override var canBecomeFirstResponder: Bool {
        get { return true }
    }
    
    override func motionEnded(_ motion: UIEventSubtype, with event: UIEvent?) {
        if motion == .motionShake {
            self.infoLabel.text = "shake gesture detected"
            avsClient.ping()
            
            do {
                //let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                //let fileURL = directory.appendingPathComponent(Settings.Audio.WAKE_FILE_NAME)
                
                let url = Bundle.main.url(forResource: "wake", withExtension: "wav")
                let wake = try Data(contentsOf: url!)
                
                avsClient.postRecording(audioData: wake)
                
                // https://developer.amazon.com/docs/alexa-voice-service/recommended-media-support.html
                // mp3, aac, wav, etc.
                // try avsClient.postRecording(audioData: Data(contentsOf: fileURL))
            } catch let ex {
                print("AVS Client threw an error: \(ex.localizedDescription)")
                self.infoLabel.text = "wake word audio file not found"
            }
        }
    }

    /*
    @IBAction func onClickStartDownchannelBtn(_ sender: Any) {
        avsClient.startDownchannel()
    }
    */
    
    @IBAction func recordButtonClick(_ sender: Any) {
        
        if (self.isRecording) {
            audioRecorder.stop()
            
            self.isRecording = false
            recordButton.setTitle("mic", for: .normal)
            recordButton.setImage(UIImage(named: "mic-30px.png"), for: .normal)

            do {
                print(audioRecorder.url)
                try avsClient.postRecording(audioData: Data(contentsOf: audioRecorder.url))
            } catch let ex {
                print("AVS Client threw an error: \(ex.localizedDescription)")
            }
        } else {
            prepareAudioSession()
            
            audioRecorder.prepareToRecord()
            audioRecorder.record()
            
            self.isRecording = true
            recordButton.setTitle("stop", for: .normal)
            recordButton.setImage(UIImage(named: "stop-30px.png"), for: .normal)
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
    
    func prepareAudioSession() {
        do {
            let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let fileURL = directory.appendingPathComponent(Settings.Audio.TEMP_FILE_NAME)
            try audioRecorder = AVAudioRecorder(url: fileURL, settings: Settings.Audio.RECORDING_SETTING as [String : AnyObject])
            try audioSession.setCategory(AVAudioSessionCategoryPlayAndRecord, with:[AVAudioSessionCategoryOptions.allowBluetooth, AVAudioSessionCategoryOptions.allowBluetoothA2DP])
        } catch let ex {
            print("Audio session has an error: \(ex.localizedDescription)")
        }
    }
    
    func prepareAudioSessionForWakeWord() {
        do {
            let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            snowboyTempSoundFileURL = directory.appendingPathComponent(Settings.WakeWord.TEMP_FILE_NAME)
            try audioRecorder = AVAudioRecorder(url: snowboyTempSoundFileURL, settings: Settings.Audio.RECORDING_SETTING as [String : AnyObject])
            try audioSession.setCategory(AVAudioSessionCategoryPlayAndRecord)
            audioRecorder.delegate = self
        } catch let ex {
            print("Audio session for wake word has an error: \(ex.localizedDescription)")
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
            
            for h in i.headings {
                // draw arrows to indicate heading directions
                let line = drawLine(start: i.getLocation(), direction: h, length: 15.0)
                mapView.add(line)
            }
        }
    }
    
    func degreesToRadians(degrees: Double) -> Double { return degrees * .pi / 180.0 }
    func radiansToDegrees(radians: Double) -> Double { return radians * 180.0 / .pi }
    
    func getBearingBetweenTwoPoints1(point1 : CLLocation, point2 : CLLocation) -> Double {
        
        let lat1 = degreesToRadians(degrees: point1.coordinate.latitude)
        let lon1 = degreesToRadians(degrees: point1.coordinate.longitude)
        
        let lat2 = degreesToRadians(degrees: point2.coordinate.latitude)
        let lon2 = degreesToRadians(degrees: point2.coordinate.longitude)
        
        let dLon = lon2 - lon1
        
        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        let radiansBearing = atan2(y, x)
        
        return radiansToDegrees(radians: radiansBearing)
    }
    
    // double precision arithmetic is too inaccurate to calculate location coordinates
    func locationWithBearing(bearing:Double, distanceMeters:Double, origin:CLLocationCoordinate2D) -> CLLocationCoordinate2D {
        let distRadians = distanceMeters / (6372797.6) // earth radius in meters
        
        let lat1 = origin.latitude * Double.pi / 180.0
        let lon1 = origin.longitude * Double.pi / 180.0
        
        let lat2 = asin(sin(lat1) * cos(distRadians) + cos(lat1) * sin(distRadians) * cos(bearing))
        let lon2 = lon1 + atan2(sin(bearing) * sin(distRadians) * cos(lat1), cos(distRadians) - sin(lat1) * sin(lat2))
        
        let coord = CLLocationCoordinate2D(latitude: lat2 * 180.0 / Double.pi, longitude: lon2 * 180.0 / Double.pi)
        print("locationWithBearing: \(coord.latitude),\(coord.longitude)")
        return coord
    }
    
    internal func drawLine(start: CLLocation, direction: Double, length: Double) -> MKPolyline {
        var coords = [CLLocationCoordinate2D]()
        
        //print(getBearingBetweenTwoPoints1(point1: start, point2: CLLocation(latitude: 44.039963, longitude: -123.080199)))
        
        //coords.append(CLLocationCoordinate2D(latitude: 44.039963, longitude: -123.080199))
        //coords.append(locationWithBearing(bearing: 180.6147, distanceMeters: length, origin: start.coordinate))
        coords.append(locationWithBearing(bearing: getBearingBetweenTwoPoints1(point1: start, point2: CLLocation(latitude: 44.039963, longitude: -123.080199)), distanceMeters: length, origin: start.coordinate))
        coords.append(start.coordinate)
        coords.append(CLLocationCoordinate2D(latitude: 44.040127, longitude: -123.080199))
        //coords.append(locationWithBearing(bearing: 359.5753, distanceMeters: length, origin: start.coordinate))

        return MKPolyline(coordinates: coords, count: coords.count)
    }
    
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        if overlay is MKCircle {
            let circle = MKCircleRenderer(overlay: overlay)
            circle.strokeColor = UIColor.red
            circle.fillColor = UIColor(red: 255, green: 0, blue: 0, alpha: 0.1)
            circle.lineWidth = 1
            return circle
        } else if overlay is MKPolyline {
            let line = MKPolylineRenderer(overlay: overlay)
            line.strokeColor = UIColor.red
            line.lineWidth = 2.0
            return line
        }
        return MKOverlayRenderer()
    }
    
    @objc func startListening() {
        audioRecorder.record(forDuration: 1.0)
    }
    
    func pingHandler(isSuccess: Bool) {
        DispatchQueue.main.async { () -> Void in
            if (isSuccess) {
                self.infoLabel.text = "Ping success!"
            } else {
                self.infoLabel.text = "Ping failure!"
            }
        }
    }
    
    func syncHandler(isSuccess: Bool) {
        DispatchQueue.main.async { () -> Void in
            if (isSuccess) {
                self.infoLabel.text = "Sync success!"
            } else {
                self.infoLabel.text = "Sync failure!"
            }
        }
    }
    
    func directiveHandler(directives: [DirectiveData]) {
        // Store the token for directive "Speak"
        for directive in directives {
            if (directive.contentType == "application/json") {
                do {
                    let jsonData = try JSONSerialization.jsonObject(with: directive.data) as! [String:Any]
                    let directiveJson = jsonData["directive"] as! [String:Any]
                    let header = directiveJson["header"] as! [String:String]
                    if (header["name"] == "Speak") {
                        let payload = directiveJson["payload"] as! [String:String]
                        self.speakToken = payload["token"]!
                    }
                } catch let ex {
                    print("Directive data has an error: \(ex.localizedDescription)")
                }
            }
        }
        
        // Play the audio
        for directive in directives {
            if (directive.contentType == "application/octet-stream") {
                DispatchQueue.main.async { () -> Void in
                    self.infoLabel.text = "Alexa is speaking"
                }
                do {
                    self.avsClient.sendEvent(namespace: "SpeechSynthesizer", name: "SpeechStarted", token: self.speakToken!)
                    
                    try audioSession.setCategory(AVAudioSessionCategoryPlayAndRecord, with:[AVAudioSessionCategoryOptions.allowBluetooth, AVAudioSessionCategoryOptions.allowBluetoothA2DP])
                    try self.audioPlayer = AVAudioPlayer(data: directive.data)
                    self.audioPlayer.delegate = self
                    self.audioPlayer.prepareToPlay()
                    self.audioPlayer.play()
                } catch let ex {
                    print("Audio player has an error: \(ex.localizedDescription)")
                }
            }
        }
    }
    
    func downchannelHandler(directive: String) {
        
        do {
            let jsonData = try JSONSerialization.jsonObject(with: directive.data(using: String.Encoding.utf8)!) as! [String:Any]
            let directiveJson = jsonData["directive"] as! [String:Any]
            let header = directiveJson["header"] as! [String:String]
            if (header["name"] == "StopCapture") {
                // Handle StopCapture
            } else if (header["name"] == "SetAlert") {
                // Handle SetAlert
                let payload = directiveJson["payload"] as! [String:String]
                let scheduledTime = payload["scheduledTime"]
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
                dateFormatter.locale = Locale.init(identifier: "en_US")
                let futureDate = dateFormatter.date(from: scheduledTime!)
                
                let numberOfSecondsDiff = Calendar.current.dateComponents([.second], from: Date(), to: futureDate!).second ?? 0
                
                DispatchQueue.main.async { () -> Void in
                    Timer.scheduledTimer(timeInterval: TimeInterval(numberOfSecondsDiff),
                                         target: self,
                                         selector: #selector(self.timerStart),
                                         userInfo: nil,
                                         repeats: false)
                }
                
                print("Downchannel SetAlert scheduledTime: \(scheduledTime!); \(numberOfSecondsDiff) seconds from now.")
            }
        } catch let ex {
            print("Downchannel error: \(ex.localizedDescription)")
        }
    }
    
    @objc func timerStart() {
        print("Timer is triggered")
        DispatchQueue.main.async { () -> Void in
            self.infoLabel.text = "Time is up!"
        }
    }
    
    /*
    func runSnowboy() {
        
        let file = try! AVAudioFile(forReading: snowboyTempSoundFileURL)
        let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 16000.0, channels: 1, interleaved: false)
        let buffer = AVAudioPCMBuffer(pcmFormat: format!, frameCapacity: AVAudioFrameCount(file.length))
        try! file.read(into: buffer!)
        let len = buffer?.frameLength
        let array = Array(UnsafeBufferPointer(start: buffer?.floatChannelData![0], count:Int(len!)))
        
        let result = snowboy.runDetection(array, length: Int32(len!))
        print("Snowboy result: \(result)")
        
        // Wake word matches
        if (result == 1) {
            DispatchQueue.main.async { () -> Void in
                self.infoLabel.text = "Alexa is listening"
            }
            
            prepareAudioSession()
            
            audioRecorder.isMeteringEnabled = true
            audioRecorder.record()
            stopCaptureTimer = Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(checkAudioMetering), userInfo: nil, repeats: true)
        } else {
            DispatchQueue.main.async { () -> Void in
                self.infoLabel.text = "Say Alexa"
            }
        }
    }
    */
    
    @objc func checkAudioMetering() {
        
        audioRecorder.updateMeters()
        let power = audioRecorder.averagePower(forChannel: 0)
        print("Average power: \(power)")
        if (power < Settings.Audio.SILENCE_THRESHOLD) {
            
            DispatchQueue.main.async { () -> Void in
               self.infoLabel.text = "Waiting for Alexa to respond..."
            }
            
            stopCaptureTimer.invalidate()
            snowboyTimer.invalidate()
            audioRecorder.stop()
            
            do {
                try avsClient.postRecording(audioData: Data(contentsOf: audioRecorder.url))
            } catch let ex {
                print("AVS Client threw an error: \(ex.localizedDescription)")
            }
            
            prepareAudioSessionForWakeWord()
            snowboyTimer = Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(startListening), userInfo: nil, repeats: true)
        }
    }
    
    func readLoopState(silent: Bool) {
        myPhoton!.getVariable("loop_state", completion: { (result:Any?, error:Error?) -> Void in
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
    
    func triggerRelay(relayNumber: String) {
        self.updateTextView(text: "triggering relay #\(relayNumber)")
        
        let task = myPhoton!.callFunction("relay_on", withArguments: [relayNumber]) { (resultCode : NSNumber?, error : Error?) -> Void in
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
    
    @IBAction func startTripClick(_ sender: Any) {
        if startButton.titleLabel?.text == "Start Trip" {
            startButton.setTitle("Stop Trip", for: .normal)
            //polling = true
            self.updateTextView(text: "starting bicycle trip")
        }
        else if startButton.titleLabel?.text == "Stop Trip" {
            startButton.setTitle("Start Trip", for: .normal)
            relayStateView.backgroundColor = UIColor.white
            //autoPollTimer?.invalidate()
            //locationTimer?.invalidate()
            pollServerTimer?.invalidate()
            //pause = false
            //polling = false
            self.updateTextView(text: "stopping bicycle trip")
        }
    }
    
    @objc func updatePollServerButton() {
        pollServerButton.isEnabled = true
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
    
    @IBAction func recordSensorsButtonClick(_ sender: Any) {
        if recordSensorsButton.title(for: .normal) == "record" {
            //startMotionUpdates()
            recordSensorsButton.setImage(UIImage(named: "stop-30px.png"), for: .normal)
            recordSensorsButton.setTitle("stop", for: .normal)
        } else if recordSensorsButton.title(for: .normal) == "stop" {
            //stopMotionUpdates()
            recordSensorsButton.setImage(UIImage(named: "email-30px.png"), for: .normal)
            recordSensorsButton.setTitle("send", for: .normal)
        } else {
            // e-mail csv file
            //exportCsv()
            recordSensorsButton.setImage(UIImage(named: "record-30px.png"), for: .normal)
            recordSensorsButton.setTitle("record", for: .normal)
        }
    }

    @IBAction func triggerRelayButtonClick(_ sender: Any) {
        let number = "1"
        triggerRelay(relayNumber: number)
    }
    
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        print("Audio player is finished playing")
        self.infoLabel.text = "Cycle Buddy"
        
        self.avsClient.sendEvent(namespace: "SpeechSynthesizer", name: "SpeechFinished", token: self.speakToken!)
    }
    
    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        print("Audio player has an error: \(String(describing: error?.localizedDescription))")
    }
    
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        print("Audio recorder is finished recording")
        //runSnowboy()
    }
    
    func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        print("Audio recorder has an error: \(String(describing: error?.localizedDescription))")
    }
}
