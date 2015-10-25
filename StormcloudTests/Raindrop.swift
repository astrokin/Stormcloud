//
//  Raindrop.swift
//  iCloud Extravaganza
//
//  Created by Simon Fairbairn on 21/10/2015.
//  Copyright © 2015 Voyage Travel Apps. All rights reserved.
//

import UIKit
import CoreData

public enum RaindropType : String {
    case Heavy, Light, Drizzle
    public static let allValues = [Heavy, Light, Drizzle]
}


public enum ICECoreDataError : ErrorType {
    case InvalidType
}

@objc(Raindrop)
public class Raindrop: NSManagedObject {

// Insert code here to add functionality to your managed object subclass

    public class func insertRaindropWithType(type : RaindropType, withCloud : Cloud, inContext context : NSManagedObjectContext ) throws -> Raindrop {
        
        if let drop1 = NSEntityDescription.insertNewObjectForEntityForName("Raindrop", inManagedObjectContext: context) as? Raindrop {
            drop1.type = type.rawValue
            drop1.cloud = withCloud
            drop1.colour = UIColor.redColor()
            drop1.timesFallen = 10
            drop1.raindropValue = NSDecimalNumber(string: "10.54")
            return drop1
        } else {
            throw ICECoreDataError.InvalidType
        }
    }
    
}
