//
//  DocumentsTableViewController.swift
//  iCloud Extravaganza
//
//  Created by Simon Fairbairn on 18/10/2015.
//  Copyright © 2015 Voyage Travel Apps. All rights reserved.
//

import UIKit
import Stormcloud

class DocumentsTableViewController: UITableViewController {

    
    let dateFormatter = NSDateFormatter()
    var documentsManager : Stormcloud!
    
    let numberFormatter = NSNumberFormatter()
    
    var stack : CoreDataStack?
    
    @IBOutlet var iCloudSwitch : UISwitch!
    
    override func viewDidLoad() {
        super.viewDidLoad()


        // MARK: - To Copy
        self.documentsManager.delegate = self
        self.documentsManager.reloadData()
        self.tableView.reloadData()
        // End
        
        self.iCloudSwitch.on = self.documentsManager.isUsingiCloud
    }

    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
//        self.configureDocuments()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    // MARK: - Table view data source

    override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.documentsManager.metadataList.count
    }

    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier("BackupTableViewCell", forIndexPath: indexPath)

        // MARK: - To Copy
        let data = self.documentsManager.metadataList[indexPath.row]
        data.delegate = self
        // End
        
        self.configureTableViewCell(cell, withMetadata: data)
        return cell
    }
    
    
    func configureTableViewCell( tvc : UITableViewCell, withMetadata data: StormcloudMetadata ) {
        

        dateFormatter.dateStyle = .ShortStyle
        dateFormatter.timeStyle = .ShortStyle
        dateFormatter.timeZone = NSTimeZone(abbreviation: "UTC")
        var text = dateFormatter.stringFromDate(data.date)
        
        if self.documentsManager.isUsingiCloud {
            
            if data.isDownloading {
                text.appendContentsOf(" ⏬ \(self.numberFormatter.stringFromNumber(data.percentDownloaded / 100))%")
            } else if data.iniCloud {
                text.appendContentsOf(" ☁️")
            } else if data.isUploading {
                
                self.numberFormatter.numberStyle = NSNumberFormatterStyle.PercentStyle
                text.appendContentsOf(" ⏫ \(self.numberFormatter.stringFromNumber(data.percentUploaded / 100)!)")
            }
            
        }
        tvc.textLabel?.text = text
        tvc.detailTextLabel?.text = data.device
    }


    // Override to support editing the table view.
    override func tableView(tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath) {
        if editingStyle == .Delete {
            
            // MARK: - To Copy
            
            let metadataItem = self.documentsManager.metadataList[indexPath.row]
            self.documentsManager.deleteItem(metadataItem, completion: { ( index, error) -> () in
                
                if let _ = error {
                    
                    let alert = UIAlertController(title: "Couldn't delete item!", message: "Error", preferredStyle: .Alert)
                    alert.addAction(UIAlertAction(title: "OK", style: .Cancel, handler: { (action) -> Void in
                    }))
                    self.presentViewController(alert, animated: true, completion: nil)
                    
                }
                
            })

            // End
        } else if editingStyle == .Insert {
            // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
        }    
    }
}

// MARK: - Methods

extension DocumentsTableViewController {

    func showAlertView(title : String, message : String ) {
        let alertViewController = UIAlertController(title: title, message: message, preferredStyle: UIAlertControllerStyle.Alert)
        
        let action = UIAlertAction(title: "OK!", style: .Cancel, handler: { (alertAction) -> Void in
            
        })
        alertViewController.addAction(action)
        self.presentViewController(alertViewController, animated: true, completion: nil)
        
    }
    

}

// MARK: - StormcloudDelegate

extension DocumentsTableViewController : StormcloudDelegate {
    
    func metadataListDidAddItemsAtIndexes(addedItems: NSIndexSet?, andDeletedItemsAtIndexes deletedItems: NSIndexSet?) {
        
        self.tableView.beginUpdates()
        
        if let didAddItems = addedItems {
            var indexPaths : [NSIndexPath] = []
            for additionalItems in didAddItems {
                indexPaths.append(NSIndexPath(forRow: additionalItems, inSection: 0))
            }
            self.tableView.insertRowsAtIndexPaths(indexPaths, withRowAnimation: .Automatic)
        }
        
        if let didDeleteItems = deletedItems {
            var indexPaths : [NSIndexPath] = []
            for deletedItems in didDeleteItems {
                indexPaths.append(NSIndexPath(forRow: deletedItems, inSection: 0))
            }
            self.tableView.deleteRowsAtIndexPaths(indexPaths, withRowAnimation: .Automatic)
        }
        self.tableView.endUpdates()
    }
    
    
    func metadataListDidChange(manager: Stormcloud) {
//        self.configureDocuments()
    }
}


extension DocumentsTableViewController : StormcloudMetadataDelegate {
    func iCloudMetadataDidUpdate(metadata: StormcloudMetadata) {
        if let index = self.documentsManager.metadataList.indexOf(metadata) {
            if let tvc = self.tableView.cellForRowAtIndexPath(NSIndexPath(forRow: index, inSection: 0)) {
                
                self.configureTableViewCell(tvc, withMetadata: metadata)
            }
        }
    }
}

// End

// MARK: - Segue

extension DocumentsTableViewController {
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if let dvc = segue.destinationViewController as? DetailViewController, tvc = self.tableView.indexPathForSelectedRow {
            
            let metadata = self.documentsManager.metadataList[tvc.row]
            dvc.itemURL = self.documentsManager.urlForItem(metadata)
            dvc.backupManager = self.documentsManager
            dvc.stack  = self.stack
        }
    }
}




// MARK: - Actions

extension DocumentsTableViewController {
    
    @IBAction func enableiCloud( sender : UISwitch ) {
        if sender.on {
            self.documentsManager.enableiCloudShouldMoveLocalDocumentsToiCloud(true) { (error) -> Void in
                
                if let hasError = error {
                    sender.on = false
                    if hasError == StormcloudError.iCloudUnavailable {
                        self.showAlertView("iCloud Unavailable", message: "Couldn't access iCloud. Are you logged in?")
                    }
                }

            }
        } else {
            self.documentsManager.disableiCloudShouldMoveiCloudDocumentsToLocal(true, completion: { (moveSuccessful) -> Void in
                print("Disabled iCloud: \(moveSuccessful)")
            })
        }
    }
    
    @IBAction func doneButton( sender : UIBarButtonItem ) {
        self.presentingViewController?.dismissViewControllerAnimated(true, completion: nil)
    }
    
    @IBAction func addButton( sender : UIBarButtonItem ) {
//        let jsonArray : AnyObject
//        if let jsonFileURL = NSBundle.mainBundle().URLForResource("questions_json", withExtension: "json"),
//            data = NSData(contentsOfURL: jsonFileURL) {
//
//            do {
//                
//                jsonArray = try NSJSONSerialization.JSONObjectWithData(data, options: NSJSONReadingOptions())
//            } catch let error as NSError {
//                print("Error reading json: \(error.localizedDescription)")
//                jsonArray = ["Error json" ]
//            }
//            
//        } else {
//            jsonArray = ["Error json" ]
//        }
//        let easyJSON : AnyObject
//        if let hasValue = NSUserDefaults.standardUserDefaults().objectForKey(ICEDefaultsKeys.textValue.rawValue) {
//            easyJSON = ["Item" : hasValue ]
//        } else {
//            easyJSON = ["Item" : "No Value"]
//        }

        if let context = self.stack?.managedObjectContext {
            self.documentsManager.backupCoreDataEntities(inContext: context, completion: { (error, metadata) -> () in

                var title = NSLocalizedString("Success!", comment: "The title of the alert box shown when a backup successfully completes")
                var message = NSLocalizedString("Successfully backed up all Core Data entities.", comment: "The message when the backup manager successfully completes")
                
                if let hasError = error {
                    title = NSLocalizedString("Error!", comment: "The title of the alert box shown when there's an error")
                    
                    switch hasError {
                    case .InvalidJSON:
                        message = NSLocalizedString("There was an error creating the backup document", comment: "Shown when a backup document couldn't be created")
                    case .BackupFileExists:
                        message = NSLocalizedString("The backup filename already exists. Please wait a second and try again.", comment: "Shown when the file already exists on disk.")
                    case .CouldntMoveDocumentToiCloud:
                        message = NSLocalizedString("Saved backup locally but couldn't move it to iCloud. Is your iCloud storage full?", comment: "Shown when the file could not be moved to iCloud.")
                    case .CouldntSaveManagedObjectContext:
                        message = NSLocalizedString("Error reading from database.", comment: "Shown when the database context could not be read.")
                    case .CouldntSaveNewDocument:
                        message = NSLocalizedString("Could not create a new document.", comment: "Shown when a new document could not be created..")
                    case .InvalidURL:
                        message = NSLocalizedString("Could not get a valid URL.", comment: "Shown when it couldn't get a URL either locally or in iCloud.")
                    default:
                        break

                    }
                }
                
                if let _ = self.presentedViewController as? UIAlertController {
                    self.dismissViewControllerAnimated(false, completion: nil)
                }

                self.showAlertView(title, message: message)
                
                
            })

            
        }
        
        
//        self.documentsManager.backupObjectsToJSON(jsonArray) { (success, metadata) -> () in
//            if let hasMetadata = metadata {
//
//            } else {
//                let alert = UIAlertController(title: "Couldn't add backup!", message: "Error", preferredStyle: .Alert)
//                alert.addAction(UIAlertAction(title: "OK", style: .Cancel, handler: { (action) -> Void in
//                }))
//                
//                self.presentViewController(alert, animated: true, completion: nil)
//                
//            }
//        }
    }
}

