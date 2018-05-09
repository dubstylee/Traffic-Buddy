//
//  ReportViewController.swift
//  Traffic Buddy
//
//  Created by Brian Williams on 5/8/18.
//  Copyright © 2018 Brian Williams. All rights reserved.
//

import Foundation
import UIKit

class ReportViewController: UIViewController {
    @IBOutlet weak var weatherCheckbox: CheckBox!
    @IBOutlet weak var lightCheckbox: CheckBox!
    @IBOutlet weak var additionalInfoCheckbox: CheckBox!
    @IBOutlet weak var roadCheckbox: CheckBox!
    @IBOutlet weak var yourActivityCheckbox: CheckBox!
    @IBOutlet weak var othersActivityCheckbox: CheckBox!
    
    var isReporting = false
    
    @IBAction func additionalInfoButtonClick(_ sender: Any) {
        isReporting = true
        
        // record light info
        additionalInfoCheckbox.isChecked = true
    }
    
    @IBAction func helpButtonClick(_ sender: Any) {
        // send a help request to Alexa
        
        // save recorded help message??
    }
    
    @IBAction func lightConditionsButtonClick(_ sender: Any) {
        isReporting = true
        
        // record light info
        lightCheckbox.isChecked = true
    }
    
    @IBAction func othersActivityButtonClick(_ sender: Any) {
        isReporting = true
        
        // record road info
        othersActivityCheckbox.isChecked = true
    }
    
    @IBAction func roadConditionsButtonClick(_ sender: Any) {
        isReporting = true
        
        // record road info
        roadCheckbox.isChecked = true
    }
    
    @IBAction func weatherConditionsButtonClick(_ sender: Any) {
        isReporting = true
        
        // record weather info
        weatherCheckbox.isChecked = true
    }
    
    @IBAction func yourActivityButtonClick(_ sender: Any) {
        isReporting = true
        
        // record road info
        yourActivityCheckbox.isChecked = true
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
            isReporting = false

            // clear all checkboxes and return to main screen
            additionalInfoCheckbox.isChecked = false
            lightCheckbox.isChecked = false
            othersActivityCheckbox.isChecked = false
            roadCheckbox.isChecked = false
            weatherCheckbox.isChecked = false
            yourActivityCheckbox.isChecked = false
        }
    }
}
