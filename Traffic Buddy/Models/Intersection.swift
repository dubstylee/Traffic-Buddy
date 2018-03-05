//
//  Intersection.swift
//  Traffic Buddy
//
//  Created by Brian Williams on 10/1/17.
//  Copyright © 2017 Brian Williams. All rights reserved.
//

import CoreLocation
import Realm
import RealmSwift
import UIKit

@objcMembers
class Intersection: Object {
    dynamic var longitude : Double = 0.0
    dynamic var latitude : Double = 0.0
    dynamic var title : String = ""
    // schema version 2
    //dynamic var headings = List<Double>()

    required init() {
        super.init()
    }
    
    required init(realm: RLMRealm, schema: RLMObjectSchema) {
        super.init(realm: realm, schema: schema)
    }
    
    required init(value: Any, schema: RLMSchema) {
        super.init(value: value, schema: schema)
    }
    
    convenience init(latitude: Double, longitude: Double, title: String) {
        self.init()
        self.latitude = latitude
        self.longitude = longitude
        self.title = title
    }
    
    func getLocation() -> CLLocation {
        return CLLocation(latitude: self.latitude, longitude: self.longitude)
    }
    
    public override var description: String { return "Intersection [\(title): LAT: \(latitude), LONG: \(longitude)\\n" }
}
