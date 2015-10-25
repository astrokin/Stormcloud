//
//  Cloud+CoreDataProperties.swift
//  VTABM
//
//  Created by Simon Fairbairn on 22/10/2015.
//  Copyright © 2015 Simon Fairbairn. All rights reserved.
//
//  Choose "Create NSManagedObject Subclass…" from the Core Data editor menu
//  to delete and recreate this implementation file for your updated model.
//

import Foundation
import CoreData

public extension Cloud {

    @NSManaged var added: NSDate?
    @NSManaged var didRain: NSNumber?
    @NSManaged var name: String?
    @NSManaged var order: NSNumber?
    @NSManaged var chanceOfRain: NSNumber?
    @NSManaged var raindrops: NSSet?

}
