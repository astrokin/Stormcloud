//
//  StormcloudFetchedResultsController.swift
//  Stormcloud
//
//  Created by Simon Fairbairn on 19/07/2015.
//  Copyright © 2015 Voyage Travel Apps. All rights reserved.
//

import UIKit
import CoreData

/**
*  The protocol to implement if you want the detail view controller to have access to an object selected by tapping a row.
*/
public protocol StormcloudFetchedResultsControllerDetailVC {
    func setManagedObject( object : NSManagedObject )
}

/**
This class has been designed to make subclassing entirely optional. You can set all the properties it needs on it directly. 

If your detail view controller conforms to the `VTAUtilitiesFetchedResultsControllerDetailVC` protocol, this class will pass along the selected object when a row is tapped.
*/
public class StormcloudFetchedResultsController: UITableViewController {

    /// A callback to be used in the table view delegate's `tableView:cellForRowAtIndexPath:` method. Passes along the managed object from the Fetched Results Controller
    public var cellCallback : ((tableView : UITableView, object : NSManagedObject, indexPath: NSIndexPath) -> UITableViewCell)?
    
    /// Whether to allow deletion of the rows
    public var enableDelete  = false
    
    /// The Fetched Results Controller to use.
    public var frc : NSFetchedResultsController? {
        didSet {
            self.frc?.delegate = self
        }
    }
    
    public override func viewDidLoad() {
        super.viewDidLoad()

        do {
            try frc?.performFetch()
        } catch {
            print("Error performing fetch")
        }
        
        
        
        if enableDelete {
            self.navigationItem.leftBarButtonItem = self.editButtonItem()
        }
    }
}

// MARK: - UITableViewDelegate

extension StormcloudFetchedResultsController {
    
    public override func tableView(tableView: UITableView, canEditRowAtIndexPath indexPath: NSIndexPath) -> Bool {
        return self.enableDelete
    }
    
    public override func tableView(tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath) {
        switch editingStyle {
        case .Delete :
            if let frc = self.frc, object = frc.objectAtIndexPath(indexPath) as? NSManagedObject {
                frc.managedObjectContext.deleteObject(object)
            }
        case .Insert, .None:
            break
        }
    }
    
}

// MARK: - UITableViewDataSource

extension StormcloudFetchedResultsController  {
    public override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return frc?.sections?.count ?? 1
    }
    
    public override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if let sectionInfo = frc?.sections?[section] {
            return sectionInfo.numberOfObjects
        }
        return 0
    }
    
    public override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        
        if let callback = self.cellCallback, object = self.frc?.objectAtIndexPath(indexPath) as? NSManagedObject {
            return callback(tableView: tableView, object : object, indexPath : indexPath)
        }
        return UITableViewCell()
    }
    
}

// MARK: - NSFetchedResultsControllerDelegate

extension StormcloudFetchedResultsController : NSFetchedResultsControllerDelegate {
    
    public func controllerWillChangeContent(controller: NSFetchedResultsController) {
        tableView.beginUpdates()
    }
    
    public func controller(controller: NSFetchedResultsController, didChangeSection sectionInfo: NSFetchedResultsSectionInfo, atIndex sectionIndex: Int, forChangeType type: NSFetchedResultsChangeType) {
        switch type {
            
        case .Insert :
            tableView.insertSections(NSIndexSet(index: sectionIndex), withRowAnimation: .Fade)
        case .Delete :
            tableView.deleteSections(NSIndexSet(index: sectionIndex), withRowAnimation: .Fade)
        default :
            break
        }
    }
    
    public func controller(controller: NSFetchedResultsController, didChangeObject anObject: AnyObject, atIndexPath indexPath: NSIndexPath?, forChangeType type: NSFetchedResultsChangeType, newIndexPath: NSIndexPath?) {


        
        switch type {
        case .Insert :
            // get index path of didChangeObject
            //
            
            if let ip = newIndexPath {
                tableView.insertRowsAtIndexPaths([ip], withRowAnimation: .Automatic)
            }
            break
        case .Delete :
            if let ip = indexPath {
                tableView.deleteRowsAtIndexPaths([ip], withRowAnimation: .Fade)
            }
        case .Update :
            if let ip = indexPath {
                tableView.reloadRowsAtIndexPaths([ip], withRowAnimation: .Automatic)
            }
        case .Move :
            if let ip = indexPath, newIP = newIndexPath {
                tableView.deleteRowsAtIndexPaths([newIP], withRowAnimation: .None)
                tableView.insertRowsAtIndexPaths([ip], withRowAnimation: .None)
                
            }
        }
        
    }
    
    public func controllerDidChangeContent(controller: NSFetchedResultsController) {
        tableView.endUpdates()
    }
}

// MARK: - Segue

extension StormcloudFetchedResultsController {
    public override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        var controller : UIViewController  = segue.destinationViewController
        if let possibleNav = segue.destinationViewController as? UINavigationController {
            controller = possibleNav.viewControllers.first ?? possibleNav
        }
        if let dvc = controller as? StormcloudFetchedResultsControllerDetailVC,
            ip = self.tableView.indexPathForSelectedRow,
            object = self.frc?.objectAtIndexPath(ip) as? NSManagedObject {
            dvc.setManagedObject(object)
        }
    }
    
}
