//
//  SettingsViewController.swift
//  Traffic Buddy
//
//  Created by Brian Williams on 4/28/18.
//  Copyright © 2018 Brian Williams. All rights reserved.
//

import Foundation
import UIKit

class SettingsViewController: UITableViewController {
    @IBOutlet weak var distanceFeetSlider: UISlider!
    @IBOutlet weak var distanceFeetLabel: UILabel!
    @IBOutlet weak var distanceSecondsSlider: UISlider!
    @IBOutlet weak var distanceSecondsLabel: UILabel!
    @IBOutlet weak var sensorChangeStepper: UIStepper!
    @IBOutlet weak var sensorChangeLabel: UILabel!
    
    override func viewWillAppear(_ animated: Bool) {
        // load config info
        if let configs = RealmHelper.sharedInstance.getObjects(type: ConfigItem.self) {
            for item in configs {
                if let config = item as? ConfigItem {
                    if config.key == "SensorChangeThreshold" {
                        if let val = Double(config.value) {
                            sensorChangeStepper.value = val
                        }
                        sensorChangeLabel.text = "\(sensorChangeStepper.value)"
                    }
                    else if config.key == "DistanceThresholdFeet" {
                        if let val = Float(config.value) {
                            distanceFeetSlider.value = val
                        }
                        distanceFeetLabel.text = "\(distanceFeetSlider.value) feet"
                    }
                    else if config.key == "DistanceThresholdSeconds" {
                        if let val = Float(config.value) {
                            distanceSecondsSlider.value = val
                        }
                        distanceSecondsLabel.text = "\(distanceSecondsSlider.value) seconds"
                    }
                    else if config.key == "HeadingThreshold" {
                        // not configurable from within the app
                    }
                    else if config.key == "AutoPollDistance" {
                        // not configurable from within the app
                    }
                    else if config.key == "UseSpeedTrigger" {
                        // not configurable from within the app
                    }
                    else {
                        print("unknown key: '\(config.key)'")
                    }
                }
            }
        }
        super.viewWillAppear(animated)
    }
    
    @IBAction func distanceFeetChanged(_ sender: Any) {
        distanceFeetLabel.text = "\(distanceFeetSlider.value) feet"
        if let distanceFeet = RealmHelper.sharedInstance.getObjects(type: ConfigItem.self)?.filter("key = 'DistanceThresholdFeet'")[0] as? ConfigItem {
            let copy = ConfigItem()
            copy.id = distanceFeet.id
            copy.key = "DistanceThresholdFeet"
            copy.value = "\(distanceFeetSlider.value)"
            RealmHelper.sharedInstance.editObject(obj: copy)
        }
    }
    
    @IBAction func distanceSecondsChanged(_ sender: Any) {
        distanceSecondsLabel.text = "\(distanceSecondsSlider.value) seconds"
        if let distanceSeconds = RealmHelper.sharedInstance.getObjects(type: ConfigItem.self)?.filter("key = 'DistanceThresholdSeconds'")[0] as? ConfigItem {
            let copy = ConfigItem()
            copy.id = distanceSeconds.id
            copy.key = "DistanceThresholdSeconds"
            copy.value = "\(distanceSecondsSlider.value)"
            RealmHelper.sharedInstance.editObject(obj: copy)
        }
    }
    
    @IBAction func sensorDistanceThresholdChanged(_ sender: Any) {
        sensorChangeLabel.text = "\(sensorChangeStepper.value)"
        if let sensorChangeThreshold = RealmHelper.sharedInstance.getObjects(type: ConfigItem.self)?.filter("key = 'SensorChangeThreshold'")[0] as? ConfigItem {
            let copy = ConfigItem()
            copy.id = sensorChangeThreshold.id
            copy.key = "SensorChangeThreshold"
            copy.value = "\(sensorChangeStepper.value)"
            RealmHelper.sharedInstance.editObject(obj: copy)
        }
    }
}
