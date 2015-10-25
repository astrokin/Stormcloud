//
//  Cloud.swift
//  iCloud Extravaganza
//
//  Created by Simon Fairbairn on 21/10/2015.
//  Copyright © 2015 Voyage Travel Apps. All rights reserved.
//

import Foundation
import CoreData

@objc(Cloud)
public class Cloud: NSManagedObject {

// Insert code here to add functionality to your managed object subclass

    public class func insertCloudWithName(name : String, order : Int, didRain : Bool?, inContext context : NSManagedObjectContext ) throws -> Cloud {
        if let cloud = NSEntityDescription.insertNewObjectForEntityForName("Cloud", inManagedObjectContext: context) as? Cloud {
            cloud.name = name
            cloud.order = order
            cloud.didRain = didRain
            cloud.added = NSDate()
            cloud.chanceOfRain = 0.45
            return cloud
        } else {
            throw ICECoreDataError.InvalidType
        }
    }
 
    public func raindropsForType( type : RaindropType) -> [Raindrop] {
        var raindrops : [Raindrop] = []
        
        if let hasRaindrops = self.raindrops?.allObjects as? [Raindrop] {
            raindrops =  hasRaindrops.filter() { $0.type == type.rawValue  }
        }
        return raindrops
    }
    
}
