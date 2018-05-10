//
//  ReportViewController.swift
//  Traffic Buddy
//
//  Created by Brian Williams on 5/8/18.
//  Copyright © 2018 Brian Williams. All rights reserved.
//

import AVFoundation
import AWSS3
import CoreLocation
import Foundation
import UIKit

class ReportViewController: UIViewController, AVAudioPlayerDelegate {
    let formatter = DateFormatter()
    var lastLocation: CLLocation?
    var reported = false
    
    @IBOutlet weak var additionalInfoButton: UIButton!
    @IBOutlet weak var additionalInfoCheckbox: CheckBox!
    @IBOutlet weak var lightButton: UIButton!
    @IBOutlet weak var lightCheckbox: CheckBox!
    @IBOutlet weak var othersActivityButton: UIButton!
    @IBOutlet weak var othersActivityCheckbox: CheckBox!
    @IBOutlet weak var roadButton: UIButton!
    @IBOutlet weak var roadCheckbox: CheckBox!
    @IBOutlet weak var weatherButton: UIButton!
    @IBOutlet weak var weatherCheckbox: CheckBox!
    @IBOutlet weak var yourActivityButton: UIButton!
    @IBOutlet weak var yourActivityCheckbox: CheckBox!
    
    // Alexa-related variables
    private let audioSession = AVAudioSession.sharedInstance()
    private var audioRecorder: AVAudioRecorder!
    private var audioPlayer: AVAudioPlayer!
    private var avsClient = AlexaVoiceServiceClient()
    private var avsToken: String?
    private var isReporting = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // setup Alexa Voice Services client
        avsClient.pingHandler = self.pingHandler
        avsClient.syncHandler = self.syncHandler
        avsClient.directiveHandler = self.directiveHandler
        avsClient.downchannelHandler = self.downchannelHandler

        prepareAudioSession()
        audioRecorder.prepareToRecord()
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
        
        avsClient.sendEvent(namespace: "SpeechSynthesizer", name: "SpeechFinished", token: avsToken!)
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
                    //self.infoLabel.text = "Alexa is speaking"
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
                //self.infoLabel.text = "Ping success!"
            } else {
                //self.infoLabel.text = "Ping failure!"
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
                //self.infoLabel.text = "Sync success!"
            } else {
                //self.infoLabel.text = "Sync failure!"
            }
        }
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
                return nil
            }
            
            _ = task.result
            print("Upload complete for: \(String(describing: uploadRequest.key))")
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
    
    @IBAction func additionalInfoButtonClick(_ sender: Any) {
        if additionalInfoButton.title(for: .normal) == "Press Again When Done" {
            additionalInfoButton.setTitle("Additional Info", for: .normal)
            additionalInfoButton.isUserInteractionEnabled = false
            additionalInfoCheckbox.isChecked = true
            isReporting = false
            reported = true
            
            audioRecorder.pause()
        } else if !isReporting {
            additionalInfoButton.setTitle("Press Again When Done", for: .normal)
            isReporting = true
            
            // record any additional info
            audioRecorder.record()
        }
    }
    
    @IBAction func helpButtonClick(_ sender: Any) {
        // send a help request to Alexa
        let url = Bundle.main.url(forResource: "help", withExtension: "wav")
        do {
            try avsClient.postRecording(audioData: Data(contentsOf: url!))
        } catch let ex {
            print("AVS Client threw an error: \(ex.localizedDescription)")
        }
        
        // save recorded help message??
    }
    
    @IBAction func lightConditionsButtonClick(_ sender: Any) {
        if lightButton.title(for: .normal) == "Press Again When Done" {
            lightButton.setTitle("Light Conditions", for: .normal)
            lightButton.isUserInteractionEnabled = false
            lightCheckbox.isChecked = true
            isReporting = false
            reported = true

            audioRecorder.pause()
        } else if !isReporting {
            lightButton.setTitle("Press Again When Done", for: .normal)
            isReporting = true

            // record light info
            audioRecorder.record()
        }
    }
    
    @IBAction func othersActivityButtonClick(_ sender: Any) {
        if othersActivityButton.title(for: .normal) == "Press Again When Done" {
            othersActivityButton.setTitle("Others' Activity", for: .normal)
            othersActivityButton.isUserInteractionEnabled = false
            othersActivityCheckbox.isChecked = true
            isReporting = false
            reported = true

            audioRecorder.pause()
        } else if !isReporting {
            othersActivityButton.setTitle("Press Again When Done", for: .normal)
            isReporting = true
            
            // record activity info
            audioRecorder.record()
        }
    }
    
    @IBAction func roadConditionsButtonClick(_ sender: Any) {
        if roadButton.title(for: .normal) == "Press Again When Done" {
            roadButton.setTitle("Road Conditions", for: .normal)
            roadButton.isUserInteractionEnabled = false
            roadCheckbox.isChecked = true
            isReporting = false
            reported = true
            
            audioRecorder.pause()
        } else if !isReporting {
            roadButton.setTitle("Press Again When Done", for: .normal)
            isReporting = true

            // record road info
            audioRecorder.record()
        }
    }
    
    @IBAction func weatherConditionsButtonClick(_ sender: Any) {
        if weatherButton.title(for: .normal) == "Press Again When Done" {
            weatherButton.setTitle("Weather Conditions", for: .normal)
            weatherButton.isUserInteractionEnabled = false
            weatherCheckbox.isChecked = true
            isReporting = false
            reported = true
            
            audioRecorder.pause()
        } else if !isReporting {
            weatherButton.setTitle("Press Again When Done", for: .normal)
            isReporting = true
            
            // record weather info
            audioRecorder.record()
        }
    }
    
    @IBAction func yourActivityButtonClick(_ sender: Any) {
        if yourActivityButton.title(for: .normal) == "Press Again When Done" {
            yourActivityButton.setTitle("Your Activity", for: .normal)
            yourActivityButton.isUserInteractionEnabled = false
            yourActivityCheckbox.isChecked = true
            isReporting = false
            reported = true
            
            audioRecorder.pause()
        } else if !isReporting {
            yourActivityButton.setTitle("Press Again When Done", for: .normal)
            isReporting = true
            
            // record activity info
            audioRecorder.record()
        }
    }
    
    @IBAction func activityInfoButtonClick(_ sender: Any) {
        let info = UIAlertController(title: "Activity Type", message: "Examples of activity types include, but are not limited to: riding straight, turning right, turning left, crossing the street, etc.; vehicle activities include, but are not limited to: opening the door, not using blinker, etc.", preferredStyle: UIAlertControllerStyle.alert)
        
        info.addAction(UIAlertAction(title: "Ok", style: .cancel, handler: {
            (action: UIAlertAction!) in
            // close alert
        }))
        
        present(info, animated: true, completion: nil)
    }
    
    @IBAction func submitButtonClick(_ sender: Any) {
        if !reported {
            let alert = UIAlertController(title: "Empty Report", message: "You cannot submit an empty incident report.", preferredStyle: UIAlertControllerStyle.alert)
            
            alert.addAction(UIAlertAction(title: "Ok", style: .cancel, handler: {
                (action: UIAlertAction!) in
                // close alert
            }))
            
            present(alert, animated: true, completion: nil)
        }
        else {
            // submit report to S3
            audioRecorder.stop()
            isReporting = false
            reported = false
            s3Upload(url: audioRecorder.url)
            
            // notify Alexa that we are done
            let url = Bundle.main.url(forResource: "finish", withExtension: "wav")
            do {
                try avsClient.postRecording(audioData: Data(contentsOf: url!))
            } catch let ex {
                print("AVS Client threw an error: \(ex.localizedDescription)")
            }

            // clear all checkboxes and return to main screen
            additionalInfoButton.isUserInteractionEnabled = true
            additionalInfoCheckbox.isChecked = false
            lightButton.isUserInteractionEnabled = true
            lightCheckbox.isChecked = false
            othersActivityButton.isUserInteractionEnabled = true
            othersActivityCheckbox.isChecked = false
            roadButton.isUserInteractionEnabled = true
            roadCheckbox.isChecked = false
            weatherButton.isUserInteractionEnabled = true
            weatherCheckbox.isChecked = false
            yourActivityButton.isUserInteractionEnabled = true
            yourActivityCheckbox.isChecked = false
        }
    }
}
