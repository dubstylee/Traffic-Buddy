//
//  Configuration.swift
//  Traffic Buddy
//
//  Created by Brian Williams on 4/28/18.
//  Copyright © 2018 Brian Williams. All rights reserved.
//

import Foundation
import Realm
import RealmSwift

@objcMembers
class ConfigItem: Object {
    dynamic var id: String = UUID().uuidString
    dynamic var key: String = ""
    dynamic var value: String = ""
    dynamic var timestamp: Date = Date()
    
    override static func primaryKey() -> String? {
        return "id"
    }
}
