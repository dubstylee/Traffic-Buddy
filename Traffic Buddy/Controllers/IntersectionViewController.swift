//
//  IntersectionViewController.swift
//  Traffic Buddy
//
//  Created by Brian Williams on 6/26/18.
//  Copyright © 2018 Brian Williams. All rights reserved.
//

import Foundation
import RealmSwift
import UIKit

extension DateFormatter {
    static let iso8601Full: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZZZZ"
        formatter.calendar = Calendar(identifier: .iso8601)
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()
}

class IntersectionViewController: UIViewController, UIPickerViewDataSource, UIPickerViewDelegate {
    struct Phase: Codable {
        var becameActiveTimestamp: Date
        var currentActiveTime: Float
        var currentlyActive: Bool
        var lastActiveTime: Float
        var maxGreen: Int
        var minGreen: Int
        var phaseId: Int
        
        enum CodingKeys: String, CodingKey {
            case becameActiveTimestamp = "BecameActiveTimestamp"
            case currentActiveTime = "CurrentActiveTime"
            case currentlyActive = "CurrentlyActive"
            case lastActiveTime = "LastActiveTime"
            case maxGreen = "MaxGreen"
            case minGreen = "MinGreen"
            case phaseId = "PhaseID"
        }
    }
    var autoPollTimer: Timer?
    var activePhases = [Int]()
    var activeHistory = [([Int], Date)]()
    var lastCache: ([Int], Date)?
    var updateTimer: Timer?
    var intersections = [Intersection]()
    var realm: Realm = {
        let config = Realm.Configuration(
            // Set the new schema version. This must be greater than the previously used
            // version (if you've never set a schema version before, the version is 0).
            schemaVersion: 2,
            
            // Set the block which will be called automatically when opening a Realm with
            // a schema version lower than the one set above
            migrationBlock: { migration, oldSchemaVersion in
                if oldSchemaVersion < 2 {
                    
                }
        })
        Realm.Configuration.defaultConfiguration = config
        return try! Realm()
    }()

    @IBOutlet weak var progressBar1: UIProgressView!
    @IBOutlet weak var progressBar2: UIProgressView!
    @IBOutlet weak var timingOffsetLabel: UILabel!
    @IBOutlet weak var timingOffsetStepper: UIStepper!
    @IBOutlet weak var statusCheckLabel: UILabel!
    @IBOutlet weak var statusCheckSlider: UISlider!
    @IBOutlet weak var intersectionPicker: UIPickerView!
    
    
    override func viewWillAppear(_ animated: Bool) {
        // load config info
        let configs = realm.objects(ConfigItem.self)
        if configs.count > 0 {
            for item in configs {
                let config = item
                if config.key == "TimingOffsetSeconds" {
                    if let val = Double(config.value) {
                        timingOffsetStepper.value = val
                    }
                    timingOffsetLabel.text = "Timing Offset: \(timingOffsetStepper.value) seconds"
                } else if config.key == "StatusCheckInterval" {
                    if let val = Float(config.value) {
                        statusCheckSlider.value = val
                    }
                    statusCheckLabel.text = "Status Check Interval: \(statusCheckSlider.value) seconds"
                }
                else {
                    print("unknown key: '\(config.key)'")
                }
            }
        }
        
//        let i = Intersection()
//        i.title = "13th & Alder"
//        i.id = "b3c0fe11-bbe0-4dd2-9a6d-a77700e13754"
//        let j = Intersection()
//        j.title = "13th & Hilyard"
//        j.id = "4de40699-dbf3-4616-aed4-a77700e02c7e"
//        let k = Intersection()
//        k.title = "13th & Patterson"
//        k.id = "4bb0d4e7-32c5-4ba8-82b3-a77700df7ca0"
//        let l = Intersection()
//        l.title = "13th & High"
//        l.id = "bae4383a-913a-4fce-a9ae-a77700d4f7bc"

        // load intersections
        if let inters = RealmHelper.sharedInstance.getObjects(type: Intersection.self) {
            for i in inters {
                if let intersection = i as? Intersection {
                    intersections.append(intersection)
                }
            }
        }

        super.viewWillAppear(animated)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        intersectionPicker.dataSource = self
        intersectionPicker.delegate = self
        
        // stretch progress bars to look better
        let progressBarHeight: CGFloat = 6.0
        progressBar1.transform = progressBar1.transform.scaledBy(x: 1, y: progressBarHeight)
        progressBar1.layer.cornerRadius = progressBarHeight
        progressBar1.clipsToBounds = true
        progressBar2.transform = progressBar2.transform.scaledBy(x: 1, y: progressBarHeight)
        progressBar2.layer.cornerRadius = progressBarHeight
        progressBar2.clipsToBounds = true
        
        // register the intersection to get good data
        let intersectionId = "4de40699-dbf3-4616-aed4-a77700e02c7e" //"b3c0fe11-bbe0-4dd2-9a6d-a77700e13754"
        let url = "http://128.223.6.20/api/intersection/register/\(intersectionId)"
        let request : NSMutableURLRequest = NSMutableURLRequest()
        request.url = URL(string: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 240
        
        URLSession.shared.dataTask(with: request as URLRequest) { data, response, error in
            if let data = data {
                let str = String(data: data, encoding: .utf8)
                if str == "\"success\""
                {
                    print("success")
                    self.getIntersectionStatus(intersectionId: intersectionId)
                }
            }
            if let error = error {
                print(String(describing: error))
            }
        }.resume()
        
        updateTimer = Timer.scheduledTimer(timeInterval: 0.02,
                                         target: self,
                                         selector: #selector(self.updateProgressBars),
                                         userInfo: nil,
                                         repeats: true)
    }
    
    
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return intersections.count
    }
    
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        return intersections[row].title
    }
    
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        print(intersections[row])
    }
    
    @objc func getIntersectionStatus(intersectionId: String)
    {
        //let userInfo = autoPollTimer?.userInfo as! Dictionary<String, AnyObject>
        //let intersectionId = (userInfo["intersectionId"] as! String)
        let url = "http://128.223.6.20/api/intersection/\(intersectionId)"
        let request : NSMutableURLRequest = NSMutableURLRequest()
        request.url = URL(string: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 240
        
        URLSession.shared.dataTask(with: request as URLRequest) { data, response, error in
            if data != nil {
                do {
                    let json = try JSONSerialization.jsonObject(with: data!) as! [String:Any]
                    if let currentActivePhases = json["ActivePhases"] as? [Int] {
                        if currentActivePhases.count == 0 {
                            // skipping over yellows
                        }
                        else {
                            print(currentActivePhases)
                            let allPhases = json["AllPhases"] as Any
                            let allPhasesJson = try JSONSerialization.data(withJSONObject: allPhases, options: JSONSerialization.WritingOptions.prettyPrinted)
                            let start = self.getStartTime(data: allPhasesJson, phases: currentActivePhases)
                            self.lastCache = (currentActivePhases, start)
                            
                            if currentActivePhases != self.activePhases {
                                self.activeHistory.append(self.lastCache!)
                                self.activePhases = currentActivePhases
                            }
                        }
                    }
                }
                catch {
                    
                }
            }
            
            if let error = error {
                print(String(describing: error))
            }
            
            self.getIntersectionStatus(intersectionId: intersectionId)
        }.resume()
    }

    func getStartTime(data: Data, phases: [Int]) -> Date {
        var startTime = Date()

        if phases.count > 0 {
            do {
                let records = try JSONSerialization.jsonObject(with: data) as! [Any]
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .formatted(DateFormatter.iso8601Full)
                let phase = phases[0] // come in pairs but always the same so just check first

                do {
                    let recordJson = try! JSONSerialization.data(withJSONObject: records[phase-1], options: [])
                    let record = try decoder.decode(Phase.self, from: recordJson)
                    startTime = record.becameActiveTimestamp
                    print(record)
                } catch {
                    print(error)
                }
            }
            catch { }
        } else {
            print("no phases")
        }
        return startTime
    }
    
    func getWait(last: ([Int], Date), targetPhase: [Int]) -> Float {
        let lastPhase = last.0
        let lastStart = last.1
        let elapsed = Float(Date().timeIntervalSince(lastStart))
        var wait: Float = 0
        
        if lastPhase == targetPhase {
            if elapsed <= 31 {
                wait = -(31 - elapsed)
            } else {
                let cycles = Int(elapsed / 31)
                let rem = elapsed - Float(cycles * 31)
                
                if cycles % 2 != 0 {
                    wait = 31 - rem
                } else {
                    wait = -(31 - rem)
                }
            }
        } else {
            // lastPhase != targetPhase
            if elapsed <= 31 {
                wait = (31 - elapsed)
            }
            else {
                let cycles = Int(elapsed / 31)
                let rem = elapsed - Float(cycles * 31)
                
                if cycles % 2 == 0 {
                    wait = 31 - rem
                } else {
                    wait = -(31 - rem)
                }
            }
        }
        
        return wait
    }
    
//    internal func startTimer(timer: Timer)
//    {
//        print("starting timer")
//        timer = Timer.scheduledTimer(timeInterval: 5.0,
//                                     target: self,
//                                     selector: #selector(self.getIntersectionStatus),
//                                     userInfo: ["intersectionId": "b3c0fe11-bbe0-4dd2-9a6d-a77700e13754"],
//                                     repeats: false)
//    }
    
    @objc func updateProgressBars() {
        if (lastCache != nil) {
            var w = getWait(last: lastCache!, targetPhase: [2, 6])
            var x = getWait(last: lastCache!, targetPhase: [4, 8])

            if w < -6 {
                w = w * -1
                self.progressBar1.tintColor = UIColor.green
            } else if w < -1 {
                w = w * -1
                self.progressBar1.tintColor = UIColor.yellow
            } else {
                self.progressBar1.tintColor = UIColor.red
                if w < 0 {
                    // this is the time where both phases are red
                    w = 31
                } else {
                    w = w + 1
                }
            }
        
            if x < -6 {
                x = x * -1
                self.progressBar2.tintColor = UIColor.green
            } else if x < -1 {
                x = x * -1
                self.progressBar2.tintColor = UIColor.yellow
            } else {
                self.progressBar2.tintColor = UIColor.red
                if x < 0 {
                    // this is the time where both phases are red
                    x = 31
                } else {
                    x = x + 1
                }
            }
            self.progressBar1.progress = (w - 1) / 30 // setProgress((w - 1) / 30, animated: true)
            self.progressBar2.progress = (x - 1) / 30
        } else {
            progressBar1.progress = 0
            progressBar2.progress = 0
        }
    }
    
    @IBAction func timingOffsetChanged(_ sender: Any) {
        timingOffsetLabel.text = "Timing Offset: \(timingOffsetStepper.value) seconds"
        
        let timingOffsetSeconds = realm.objects(ConfigItem.self).filter("key = 'TimingOffsetSeconds'")
        let copy = ConfigItem()
        if timingOffsetSeconds.count > 0 {
            copy.id = timingOffsetSeconds[0].id
        }
        copy.key = "TimingOffsetSeconds"
        copy.value = "\(timingOffsetStepper.value)"
    
        try! realm.write ({
            realm.add(copy, update: true)
        })
    }
    
    @IBAction func statusCheckIntervalChanged(_ sender: Any) {
        statusCheckLabel.text = "Status Check Interval: \(statusCheckSlider.value) seconds"
        
        let statusCheckInterval = realm.objects(ConfigItem.self).filter("key = 'StatusCheckInterval'")
        let copy = ConfigItem()
        if statusCheckInterval.count > 0 {
            copy.id = statusCheckInterval[0].id
        }
        copy.key = "StatusCheckInterval"
        copy.value = "\(statusCheckSlider.value)"
        
        try! realm.write ({
            realm.add(copy, update: true)
        })
    }
}
