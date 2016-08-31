//
//  TagsTableViewController.swift
//  iOS example
//
//  Created by Simon Fairbairn on 02/11/2015.
//  Copyright © 2015 Voyage Travel Apps. All rights reserved.
//

import UIKit
import CoreData

class TagsTableViewController: StormcloudFetchedResultsController {

    var cloud : Cloud!
    
    var tagOptions = ["Stormy", "Windy", "Wet", "Angry"]
    
    override func viewDidLoad() {

        let request = NSFetchRequest<NSFetchRequestResult>(entityName: "Tag")
        request.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
        
        self.frc = NSFetchedResultsController(fetchRequest: request, managedObjectContext: self.cloud.managedObjectContext!, sectionNameKeyPath: nil, cacheName: nil)
        
        self.cellCallback = {(tableView : UITableView, object : NSManagedObject, indexPath: IndexPath) -> UITableViewCell in
            if let cell = tableView.dequeueReusableCell(withIdentifier: "TagCell") {
                cell.textLabel?.text = object.value(forKey: "name") as? String
                
                if let isTag = object as? Tag {
                    cell.detailTextLabel?.text = "Clouds \(isTag.clouds!.count)"
                }
                
				cell.accessoryType = ( self.checkTag(tag: object) ) ? .checkmark : .none
                
                
                return cell
            }
            return UITableViewCell()

        }
    
        super.viewDidLoad()        
        
        
        // Uncomment the following line to preserve selection between presentations
        // self.clearsSelectionOnViewWillAppear = false

        // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
        // self.navigationItem.rightBarButtonItem = self.editButtonItem()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    // MARK: - Table view data source

}

extension NSManagedObject {
    func addObject(value: NSManagedObject, forKey: String) {
        self.willChangeValue(forKey: forKey, withSetMutation: NSKeyValueSetMutationKind.union, using: NSSet(object: value) as Set<NSObject>)
        let items = self.mutableSetValue(forKey: forKey)
        items.add(value)
		self.didChangeValue(forKey: forKey, withSetMutation: .union, using: NSSet(object: value) as Set<NSObject>)
    }
    
    func removeObject(value: NSManagedObject, forKey: String) {
        self.willChangeValue(forKey: forKey, withSetMutation: .union, using: NSSet(object: value) as Set<NSObject>)
        let items = self.mutableSetValue(forKey: forKey)
        items.remove(value)
        self.didChangeValue(forKey: forKey, withSetMutation: .union, using: NSSet(object: value) as Set<NSObject>)
    }
}

extension TagsTableViewController {
    
    func checkTag( tag : NSManagedObject ) -> Bool {
        if let tags = self.cloud.tags {
            if tags.contains(tag) {
                return true
            } else {
                return false
            }
        }
        return false
    }
    
	override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		if let tag = self.frc?.object(at: indexPath) as? Tag {
			
            if let tags = self.cloud.tags {
                if tags.contains(tag) {
					self.cloud.removeObject(value: tag, forKey: "tags")
                } else {
					self.cloud.addObject(value: tag, forKey: "tags")
                }
            }

        }

        self.tableView.deselectRow(at: indexPath as IndexPath, animated: true)
    }
}


extension TagsTableViewController {
    @IBAction func addTag(_ button : UIBarButtonItem ) {
        if tagOptions.count > 0 {
            let option = tagOptions.removeFirst()
            do {
                _ = try Tag.insertTagWithName(option, inContext: self.cloud.managedObjectContext!)
            } catch {
                fatalError("Error inserting tag")
            }
        }
    }
}
