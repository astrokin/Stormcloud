//
//  StormcloudDefaultsManager.swift
//  Stormcloud
//
//  Created by Simon Fairbairn on 18/10/2015.
//  Copyright © 2015 Voyage Travel Apps. All rights reserved.
//

import UIKit

public class StormcloudDefaultsManager: NSObject {
    
    public var prefix : String = ""
    var updatingiCloud = false
    
    override public init() {
        super.init()
        NSNotificationCenter.defaultCenter().addObserver(self, selector: Selector("ubiquitousContentDidChange:"), name: NSUbiquitousKeyValueStoreDidChangeExternallyNotification, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: Selector("enablediCloud:"), name: NSUbiquityIdentityDidChangeNotification, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: Selector("userDefaultsDidChange:"), name: NSUserDefaultsDidChangeNotification, object: nil)
        NSUbiquitousKeyValueStore.defaultStore().synchronize()
    }
    
    func ubiquitousContentDidChange( note : NSNotification ) {
        
        for ( key, value ) in NSUbiquitousKeyValueStore.defaultStore().dictionaryRepresentation {
            if key.hasPrefix(self.prefix ) {
                if let isBool = value as? Bool {
                    NSUserDefaults.standardUserDefaults().setBool(isBool, forKey: key)
                }
                if let isInt = value as? Int {
                    NSUserDefaults.standardUserDefaults().setInteger(isInt, forKey: key)
                }
                if let isString = value as? String {
                    NSUserDefaults.standardUserDefaults().setObject(isString, forKey: key)
                }
            }
        }
    }
    
    func userDefaultsDidChange( note : NSNotification ) {
        if updatingiCloud {
            return
        }
        
        updatingiCloud = true
        
        for ( key, value ) in NSUserDefaults.standardUserDefaults().dictionaryRepresentation() {
            if key.hasPrefix(self.prefix ) {
                if let isBool = value as? Bool {
                    NSUbiquitousKeyValueStore.defaultStore().setBool(isBool, forKey: key)
                }
                if let isInt = value as? Int {
                    NSUbiquitousKeyValueStore.defaultStore().setLongLong(Int64(isInt), forKey: key)
                }
                if let isString = value as? String {
                    NSUbiquitousKeyValueStore.defaultStore().setObject(isString, forKey: key)
                }
            }
        }
        
        NSUbiquitousKeyValueStore.defaultStore().synchronize()
        
        updatingiCloud = false
    }
    
    
    func enablediCloud( note : NSNotification? ) {
        NSUbiquitousKeyValueStore.defaultStore().synchronize()
    }
    
    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }
    
}
