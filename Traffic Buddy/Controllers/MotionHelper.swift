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
    
    /**
     *  Configure the sensor data callback.
     */
    static func startMotionUpdates(motionManager: CMMotionManager) {
        //var readings = readings
        
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
        var xString = motion?.gravity.x != nil ? String(format: "%.2f", arguments: [(motion?.gravity.x)!]): "?"
        var yString = motion?.gravity.y != nil ? String(format: "%.2f", arguments: [(motion?.gravity.y)!]): "?"
        var zString = motion?.gravity.z != nil ? String(format: "%.2f", arguments: [(motion?.gravity.z)!]): "?"
        var text = "\(formatter.string(from: NSDate() as Date)),y,\(xString),\(yString),\(zString)"
        readings.append(text)
        
        xString = motion?.userAcceleration.x != nil ? String(format: "%.2f", arguments: [(motion?.userAcceleration.x)!]): "?"
        yString = motion?.userAcceleration.y != nil ? String(format: "%.2f", arguments: [(motion?.userAcceleration.y)!]): "?"
        zString = motion?.userAcceleration.z != nil ? String(format: "%.2f", arguments: [(motion?.userAcceleration.z)!]): "?"
        text = "\(formatter.string(from: NSDate() as Date)),a,\(xString),\(yString),\(zString)"
        readings.append(text)
        
        xString = motion?.rotationRate.x != nil ? String(format: "%.2f", arguments: [(motion?.rotationRate.x)!]): "?"
        yString = motion?.rotationRate.y != nil ? String(format: "%.2f", arguments: [(motion?.rotationRate.y)!]): "?"
        zString = motion?.rotationRate.z != nil ? String(format: "%.2f", arguments: [(motion?.rotationRate.z)!]): "?"
        text = "\(formatter.string(from: NSDate() as Date)),g,\(xString),\(yString),\(zString)"
        readings.append(text)
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
