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


        let request = NSFetchRequest(entityName: "Tag")
        request.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
        
        self.frc = NSFetchedResultsController(fetchRequest: request, managedObjectContext: self.cloud.managedObjectContext!, sectionNameKeyPath: nil, cacheName: nil)
        
        self.cellCallback = {(tableView : UITableView, object : NSManagedObject, indexPath: NSIndexPath) -> UITableViewCell in
            if let cell = tableView.dequeueReusableCellWithIdentifier("TagCell") {
                cell.textLabel?.text = object.valueForKey("name") as? String
                
                cell.accessoryType = ( self.checkTag(object) ) ? .Checkmark : .None
                
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

extension TagsTableViewController {
    
    func checkTag( tag : NSManagedObject ) -> Bool {
        if let tags = self.cloud.tags {
            if tags.containsObject(tag) {
                return true
            } else {
                return false
            }
        }
        return false
    }
    
    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        if let tag = self.frc?.objectAtIndexPath(indexPath) as? Tag {

            if let tags = self.cloud.valueForKeyPath("tags") as? NSMutableSet {
                if tags.containsObject(tag) {
                    tags.removeObject(tag)
                } else {
                    tags.addObject(tag)
                }
            }
        }
        self.tableView.reloadRowsAtIndexPaths([indexPath], withRowAnimation: .None)
        self.tableView.deselectRowAtIndexPath(indexPath, animated: true)
    }
}


extension TagsTableViewController {
    @IBAction func addTag(button : UIBarButtonItem ) {
        if tagOptions.count > 0 {
            let option = tagOptions.removeFirst()
            do {
                let tag = try Tag.insertTagWithName(option, inContext: self.cloud.managedObjectContext!)

                
                
            } catch {
                print("Error inserting tag")
            }
        }
    }
}
