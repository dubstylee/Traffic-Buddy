//
//  UserLocation.swift
//  Traffic Buddy
//
//  Created by Brian Williams on 10/29/17.
//  Copyright © 2017 Brian Williams. All rights reserved.
//

import Foundation
import Realm
import RealmSwift

@objcMembers
class UserLocation: Object
{
    // CLLocationDegrees == Double
    dynamic var longitude : Double = 0.0
    dynamic var latitude : Double = 0.0
    
    required init() {
        super.init()
    }
    
    required init(realm: RLMRealm, schema: RLMObjectSchema) {
        super.init(realm: realm, schema: schema)
    }
    
    required init(value: Any, schema: RLMSchema) {
        super.init(value: value, schema: schema)
    }
    
    convenience init(latitude: Double, longitude: Double) {
        self.init()
        self.latitude = latitude
        self.longitude = longitude
    }
}
