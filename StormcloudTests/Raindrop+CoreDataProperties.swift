//
//  Raindrop+CoreDataProperties.swift
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

public extension Raindrop {

    @NSManaged var type: String?
    @NSManaged var colour: NSObject?
    @NSManaged var timesFallen: NSNumber?
    @NSManaged var raindropValue: NSDecimalNumber?
    @NSManaged var cloud: Cloud?

}
