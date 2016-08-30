//
//  Cloud+CoreDataProperties.swift
//  Stormcloud
//
//  Created by Simon Fairbairn on 02/11/2015.
//  Copyright © 2015 Voyage Travel Apps. All rights reserved.
//
//  Choose "Create NSManagedObject Subclass…" from the Core Data editor menu
//  to delete and recreate this implementation file for your updated model.
//

import Foundation
import CoreData

extension Cloud {

    @NSManaged var added: Date?
    @NSManaged var chanceOfRain: NSNumber?
    @NSManaged var didRain: NSNumber?
    @NSManaged var name: String?
    @NSManaged var order: NSNumber?
    @NSManaged var raindrops: NSSet?
    @NSManaged var tags: NSSet?

}
