//
//  RealmHelper.swift
//  Traffic Buddy
//
//  Created by Brian Williams on 4/29/18.
//  Copyright © 2018 Brian Williams. All rights reserved.
//

import UIKit
import RealmSwift

class RealmHelper {
    private var database: Realm?
    static let sharedInstance = RealmHelper()
    
    private init() {
        if let _ = SyncUser.current {
            // already logged in
            let syncConfig = SyncConfiguration(user: SyncUser.current!, realmURL: Settings.Credentials.REALM_URL!)
            let config = Realm.Configuration(syncConfiguration: syncConfig, objectTypes: [ConfigItem.self, Intersection.self])
            
            self.database = try! Realm(configuration: config)
        }
        else {
            let creds = SyncCredentials.usernamePassword(username: Settings.Credentials.REALM_LOGIN, password: Settings.Credentials.REALM_KEY)
            
            SyncUser.logIn(with: creds, server: Settings.Credentials.AUTH_URL!, onCompletion: { [weak self](user, error) in
                if let _ = user {
                    let syncConfig = SyncConfiguration(user: SyncUser.current!, realmURL: Settings.Credentials.REALM_URL!)
                    let config = Realm.Configuration(syncConfiguration: syncConfig, objectTypes: [ConfigItem.self, Intersection.self])
                    
                    self?.database = try! Realm(configuration: config)
                } else if let error = error {
                    fatalError(error.localizedDescription)
                }
            })
        }
    }
    
    // delete particular object
    func deleteObject(obj: Object) {
        try! self.database?.write ({
            self.database?.delete(obj)
        })
    }
    
    // save a new object to database
    func saveObject(obj: Object) {
        try! self.database?.write ({
            // update existing?
            self.database?.add(obj, update: false)
        })
    }
    
    // edit an existing object
    func editObject(obj: Object) {
        try! self.database?.write ({
            self.database?.add(obj, update: true)
        })
    }
    
    // returns an array as Results<object>?
    func getObjects(type: Object.Type) -> Results<Object>? {
        if self.database != nil {
            return self.database!.objects(type)
        }
        return nil
    }
    
    func deleteAllFromDatabase()  {
        try! database?.write {
            database?.deleteAll()
        }
    }
}
