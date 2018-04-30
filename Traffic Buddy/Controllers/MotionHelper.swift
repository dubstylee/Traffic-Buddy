//
//  MotionHelper.swift
//  Traffic Buddy
//
//  Created by Brian Williams on 3/20/18.
//  Copyright © 2018 Brian Williams. All rights reserved.
//

import Foundation
import CoreMotion
import UIKit

class MotionHelper {
    static let kMotionUpdateInterval = 0.2
    static let formatter = DateFormatter()
    static var accelerometerReadings = [String]()
    static var gyroscopeReadings = [String]()
    static var motionReadings = [String]()
    static var accidentDetected = false
    
    /**
     *  Configure the sensor data callback.
     */
    static func startMotionUpdates(motionManager: CMMotionManager) {
        if motionManager.isDeviceMotionAvailable {
            // deviceMotion combines accelerometer and gyroscope data
            motionManager.deviceMotionUpdateInterval = kMotionUpdateInterval
            motionManager.startDeviceMotionUpdates(to: OperationQueue.main) { (motionData, error) in
                self.report(motion: motionData, readings: &motionReadings)
                self.log(error: error)
            }
        }
        else {
            // only handle accelerometer and gyro separately if device motion is unavailable
            if motionManager.isAccelerometerAvailable {
                motionManager.accelerometerUpdateInterval = kMotionUpdateInterval
                motionManager.startAccelerometerUpdates(to: OperationQueue.main) { (accelerometerData, error) in
                    self.report(acceleration: accelerometerData?.acceleration, readings: &accelerometerReadings)
                    self.log(error: error)
                }
            }
            
            if motionManager.isGyroAvailable {
                motionManager.gyroUpdateInterval = kMotionUpdateInterval
                motionManager.startGyroUpdates(to: OperationQueue.main) { (gyroData, error) in
                    self.report(rotationRate: gyroData?.rotationRate, readings: &gyroscopeReadings)
                    self.log(error: error)
                }
            }
        }
    }

    static func stopMotionUpdates(motionManager: CMMotionManager) {
        if motionManager.isAccelerometerActive {
            motionManager.stopAccelerometerUpdates()
        }
        
        if motionManager.isGyroActive {
            motionManager.stopGyroUpdates()
        }
        
        if motionManager.isDeviceMotionActive {
            motionManager.stopDeviceMotionUpdates()
        }
    }

    /**
     Report the device motion sensor data.
     
     - parameter motion: A `CMDeviceMotion` holding the sensor data to report.
     */
    internal static func report(motion: CMDeviceMotion?, readings: inout [String]) {
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSSS"
        let acc_x = (motion?.userAcceleration.x)!
        let acc_y = (motion?.userAcceleration.y)!
        let acc_z = (motion?.userAcceleration.z)!
        let yaw = (motion?.attitude.yaw)!
        let pitch = (motion?.attitude.pitch)!
        let roll = (motion?.attitude.roll)!
        
        let acc = pow(acc_x, 2.0) + pow(acc_y, 2.0) + pow(acc_z, 2.0)
        let acc_total = pow(acc, 0.5)
        let acc_vertical = abs(acc_x * sin(roll) + acc_y * sin(pitch) - acc_z * cos(pitch) * cos(roll))
        
        var text = "\(formatter.string(from: NSDate() as Date)),A_t,\(acc_total)"
        readings.append(text)
        
        text = "\(formatter.string(from: NSDate() as Date)),A_v,\(acc_vertical)"
        readings.append(text)
        
        if !accidentDetected {
            if let thresh = RealmHelper.sharedInstance.getObjects(type: ConfigItem.self)?.filter("key == 'SensorChangeThreshold'") {
                let threshValue = Double((thresh[0] as! ConfigItem).value)!
                if acc_total > threshValue {
                    print("threshold value \(threshValue)")
                    accidentDetected = true
                }
            }
        }
    }

    /**
     Sets acceleration data values to a specified `DataTableSection`.
     
     - parameter acceleration: A `CMAcceleration` holding the values to set.
     - parameter readings:     A String array to append the reading to.
     */
    internal static func report(acceleration: CMAcceleration?, readings: inout [String]) {
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSSS"
        let xString = acceleration?.x != nil ? String(format: "%.2f", arguments: [acceleration!.x]): "?"
        let yString = acceleration?.y != nil ? String(format: "%.2f", arguments: [acceleration!.y]): "?"
        let zString = acceleration?.z != nil ? String(format: "%.2f", arguments: [acceleration!.z]): "?"
        
        let text = "\(formatter.string(from: NSDate() as Date)),a,\(xString),\(yString),\(zString)"
        readings.append(text)
    }

    /**
     Sets rotation rate data values to a specified `DataTableSection`.
     
     - parameter rotationRate: A `CMRotationRate` holding the values to set.
     - parameter section:      Section these values need to be applied to.
     */
    internal static func report(rotationRate: CMRotationRate?, readings: inout [String]) {
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSSS"
        let xString = rotationRate?.x != nil ? String(format: "%.2f", arguments: [rotationRate!.x]): "?"
        let yString = rotationRate?.y != nil ? String(format: "%.2f", arguments: [rotationRate!.y]): "?"
        let zString = rotationRate?.z != nil ? String(format: "%.2f", arguments: [rotationRate!.z]): "?"
        
        let text = "\(formatter.string(from: NSDate() as Date)),g,\(xString),\(yString),\(zString)"
        readings.append(text)
    }

    /**
     Logs an error in a consistent format.
     
     - parameter error:  Error value.
     - parameter sensor: `DeviceSensor` that triggered the error.
     */
    fileprivate static func log(error: Error?) {
        guard let error = error else { return }
        
        NSLog("Error reading sensor data: \n \(error) \n")
    }
}
