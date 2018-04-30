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

class ConfigItem: Object {
    @objc dynamic var id: String = UUID().uuidString
    @objc dynamic var key: String = ""
    @objc dynamic var value: String = ""
    @objc dynamic var timestamp: Date = Date()
    
    override static func primaryKey() -> String? {
        return "id"
    }
    
}
