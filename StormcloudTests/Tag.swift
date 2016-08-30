//
//  Tag.swift
//  Stormcloud
//
//  Created by Simon Fairbairn on 02/11/2015.
//  Copyright © 2015 Voyage Travel Apps. All rights reserved.
//

import Foundation
import CoreData


open class Tag: NSManagedObject {

// Insert code here to add functionality to your managed object subclass

    open class func insertTagWithName(_ name : String, inContext context : NSManagedObjectContext ) throws -> Tag {
        if let tag = NSEntityDescription.insertNewObject(forEntityName: "Tag", into: context) as? Tag {
            tag.name = name
            return tag
        } else {
            throw ICECoreDataError.invalidType
        }
    }
    
}
