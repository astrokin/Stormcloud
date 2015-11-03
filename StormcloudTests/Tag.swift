//
//  Tag.swift
//  Stormcloud
//
//  Created by Simon Fairbairn on 02/11/2015.
//  Copyright © 2015 Voyage Travel Apps. All rights reserved.
//

import Foundation
import CoreData


public class Tag: NSManagedObject {

// Insert code here to add functionality to your managed object subclass

    public class func insertTagWithName(name : String, inContext context : NSManagedObjectContext ) throws -> Tag {
        if let tag = NSEntityDescription.insertNewObjectForEntityForName("Tag", inManagedObjectContext: context) as? Tag {
            tag.name = name
            return tag
        } else {
            throw ICECoreDataError.InvalidType
        }
    }
    
}
