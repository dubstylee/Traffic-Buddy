//
//  Intersection.swift
//  Traffic Buddy
//
//  Created by Brian Williams on 10/1/17.
//  Copyright © 2017 Brian Williams. All rights reserved.
//

import CoreLocation
import UIKit

public class Intersection: NSObject {
    var location : CLLocation // GPS info
    var title : String
    
    // timing
    
    init(lat : Double, long : Double, name : String) {
        location = CLLocation(latitude: lat, longitude: long)
        title = name
    }
}
