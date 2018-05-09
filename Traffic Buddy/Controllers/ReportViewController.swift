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

class ReportViewController: UIViewController {
    let formatter = DateFormatter()
    var lastLocation: CLLocation?
    
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

        prepareAudioSession()
        audioRecorder.prepareToRecord()
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
            
            audioRecorder.pause()
        } else {
            additionalInfoButton.setTitle("Press Again When Done", for: .normal)
            isReporting = true
            
            // record any additional info
            audioRecorder.record()
        }
    }
    
    @IBAction func helpButtonClick(_ sender: Any) {
        // send a help request to Alexa
        
        // save recorded help message??
    }
    
    @IBAction func lightConditionsButtonClick(_ sender: Any) {
        if lightButton.title(for: .normal) == "Press Again When Done" {
            lightButton.setTitle("Additional Info", for: .normal)
            lightButton.isUserInteractionEnabled = false
            lightCheckbox.isChecked = true
            
            audioRecorder.pause()
        } else {
            lightButton.setTitle("Press Again When Done", for: .normal)
            isReporting = true
            
            // record light info
            audioRecorder.record()
        }
    }
    
    @IBAction func othersActivityButtonClick(_ sender: Any) {
        if othersActivityButton.title(for: .normal) == "Press Again When Done" {
            othersActivityButton.setTitle("Additional Info", for: .normal)
            othersActivityButton.isUserInteractionEnabled = false
            othersActivityCheckbox.isChecked = true
            
            audioRecorder.pause()
        } else {
            othersActivityButton.setTitle("Press Again When Done", for: .normal)
            isReporting = true
            
            // record activity info
            audioRecorder.record()
        }
    }
    
    @IBAction func roadConditionsButtonClick(_ sender: Any) {
        if roadButton.title(for: .normal) == "Press Again When Done" {
            roadButton.setTitle("Additional Info", for: .normal)
            roadButton.isUserInteractionEnabled = false
            roadCheckbox.isChecked = true
            
            audioRecorder.pause()
        } else {
            roadButton.setTitle("Press Again When Done", for: .normal)
            isReporting = true
            
            // record road info
            audioRecorder.record()
        }
    }
    
    @IBAction func weatherConditionsButtonClick(_ sender: Any) {
        if weatherButton.title(for: .normal) == "Press Again When Done" {
            weatherButton.setTitle("Additional Info", for: .normal)
            weatherButton.isUserInteractionEnabled = false
            weatherCheckbox.isChecked = true
            
            audioRecorder.pause()
        } else {
            weatherButton.setTitle("Press Again When Done", for: .normal)
            isReporting = true
            
            // record weather info
            audioRecorder.record()
        }
    }
    
    @IBAction func yourActivityButtonClick(_ sender: Any) {
        if yourActivityButton.title(for: .normal) == "Press Again When Done" {
            yourActivityButton.setTitle("Additional Info", for: .normal)
            yourActivityButton.isUserInteractionEnabled = false
            yourActivityCheckbox.isChecked = true
            
            audioRecorder.pause()
        } else {
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
        if !isReporting {
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
