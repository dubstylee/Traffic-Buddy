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
    static let sharedInstance = RealmHelper()
    private var database: Realm?

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
    
    /**
     Delete an object from the database.
     
     - parameter obj: The `Object` to delete.
    */
    func deleteObject(obj: Object) {
        try! self.database?.write ({
            self.database?.delete(obj)
        })
    }
    
    /**
     Insert a new object into the database.
     
     - parameter obj: The `Object` to save.
    */
    func saveObject(obj: Object) {
        try! self.database?.write ({
            self.database?.add(obj, update: false)
        })
    }
    
    /**
     Update an existing database object.
     
     - parameter obj: The `Object` to update. If the object doesn't exist, it will be added.
    */
    func editObject(obj: Object) {
        try! self.database?.write ({
            self.database?.add(obj, update: true)
        })
    }
    
    /**
     Get an array of objects from the database.
     
     - parameter type: The `Type` of objects to query from the database.
    */
    func getObjects(type: Object.Type) -> Results<Object>? {
        if self.database != nil {
            return self.database!.objects(type)
        }
        return nil
    }
    
    /**
     Delete all objects from the database.
    */
    func deleteAllFromDatabase()  {
        try! database?.write {
            database?.deleteAll()
        }
    }
}
