//
//  SettingsViewController.swift
//  iCloud Extravaganza
//
//  Created by Simon Fairbairn on 18/10/2015.
//  Copyright © 2015 Voyage Travel Apps. All rights reserved.
//

import UIKit
import CoreData
import Stormcloud

class SettingsViewController: UIViewController {

    var stack : CoreDataStack? {
        didSet {
            if let context = stack?.managedObjectContext {
                self.cloudAdder = CloudAdder(context: context)
            }
            self.backupManager.reloadData()
            self.updateCount()
        }
    }

    let backupManager = Stormcloud()
    var cloudAdder : CloudAdder?
    
    @IBOutlet var settingsSwitch1 : UISwitch!
    @IBOutlet var settingsSwitch2 : UISwitch!
    @IBOutlet var settingsSwitch3 : UISwitch!
    
    @IBOutlet var textField : UITextField!
    
    @IBOutlet var valueLabel : UILabel!
    @IBOutlet var valueStepper : UIStepper!

    @IBOutlet var cloudLabel : UILabel!
    
    func updateCount() {
        if let stack = self.stack {
            let clouds = stack.performRequestForTemplate(ICEFetchRequests.CloudFetch)
            self.cloudLabel.text = "Cloud Count: \(clouds.count)"
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        NSNotificationCenter.defaultCenter().addObserver(self, selector: Selector("updateDefaults:"), name: NSUbiquitousKeyValueStoreDidChangeExternallyNotification, object: nil)
        
        self.prepareSettings()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        self.updateCount()
    }
    

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }
    
}

extension SettingsViewController {
    func updateDefaults(note : NSNotification ) {
        self.prepareSettings()
    }
    
    func prepareSettings() {
        
        settingsSwitch1.on = NSUserDefaults.standardUserDefaults().boolForKey(ICEDefaultsKeys.Setting1.rawValue)
        settingsSwitch2.on = NSUserDefaults.standardUserDefaults().boolForKey(ICEDefaultsKeys.Setting2.rawValue)
        settingsSwitch3.on = NSUserDefaults.standardUserDefaults().boolForKey(ICEDefaultsKeys.Setting3.rawValue)
        
        if let text = NSUserDefaults.standardUserDefaults().stringForKey(ICEDefaultsKeys.textValue.rawValue) {
            self.textField.text = text
        }
        
        self.valueStepper.value = Double(NSUserDefaults.standardUserDefaults().integerForKey(ICEDefaultsKeys.stepperValue.rawValue))
        self.valueLabel.text = "Add Clouds: \(Int(valueStepper.value))"
    }
}

extension SettingsViewController {
    
    @IBAction func addNewClouds( sender : UIButton ) {
        if let adder = self.cloudAdder, let stack = self.stack {
            let clouds = stack.performRequestForTemplate(ICEFetchRequests.CloudFetch)
            let total = Int(self.valueStepper.value) ?? 1
            let runningTotal = clouds.count + 1
            for var i = 0; i < total; i++ {
                adder.addCloudWithNumber(runningTotal + i, addRaindrops : false)
            }
            self.updateCount()
            
        }
    }
    
    @IBAction func settingsSwitchChanged( sender : UISwitch ) {
        
        var key : String?
        if let senderSwitch = sender.accessibilityLabel {
            if senderSwitch.containsString("1") {
                key = ICEDefaultsKeys.Setting1.rawValue
            } else if senderSwitch.containsString("2") {
                key = ICEDefaultsKeys.Setting2.rawValue
            } else if senderSwitch.containsString("3") {
                key = ICEDefaultsKeys.Setting3.rawValue
            }
        }

        if let hasKey = key {
            NSUserDefaults.standardUserDefaults().setBool(sender.on, forKey: hasKey)
        }
        
    }
    
    @IBAction func stepperChanged( sender : UIStepper ) {
        self.valueLabel.text = "Add Clouds: \(Int(sender.value))"
        NSUserDefaults.standardUserDefaults().setInteger(Int(sender.value), forKey: ICEDefaultsKeys.stepperValue.rawValue)
    }
    
    @IBAction func dismissCloudVC(sender : UIBarButtonItem ) {
        self.dismissViewControllerAnimated(true, completion: nil)
    }
    
}

extension SettingsViewController {
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        
        if let navController = segue.destinationViewController as? UINavigationController, documentsVC = navController.viewControllers.first as? DocumentsTableViewController {
            documentsVC.stack = self.stack
            documentsVC.documentsManager = self.backupManager
        }
        

        if let navController = segue.destinationViewController as? UINavigationController, cloudVC = navController.viewControllers.first as? StormcloudFetchedResultsController {
            
            if let context = self.stack?.managedObjectContext {
                let fetchRequest = NSFetchRequest(entityName: "Cloud")
                fetchRequest.sortDescriptors = [NSSortDescriptor(key: "order", ascending: true)]
                fetchRequest.fetchBatchSize = 20
                cloudVC.frc = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: context, sectionNameKeyPath: nil, cacheName: nil)
            }
            
            cloudVC.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .Done, target: self, action: Selector("dismissCloudVC:"))
            
            cloudVC.enableDelete = true
            cloudVC.cellCallback = { (tableView: UITableView, object: NSManagedObject, ip : NSIndexPath) -> UITableViewCell in
                guard let cell = tableView.dequeueReusableCellWithIdentifier("CloudTableViewCell") else {
                    return UITableViewCell()
                }
                if let cloudObject = object as? Cloud {
                    cell.textLabel?.text =   cloudObject.name
                }
                return cell
            }
        }
        
        
    }
}

extension SettingsViewController : UITextFieldDelegate {
    
    func textFieldShouldReturn(textField: UITextField) -> Bool {
        textField.resignFirstResponder()        
        return true;
    }
    
    
    func textFieldDidEndEditing(textField: UITextField) {
        NSUserDefaults.standardUserDefaults().setObject(textField.text, forKey: ICEDefaultsKeys.textValue.rawValue)
    }
    
}