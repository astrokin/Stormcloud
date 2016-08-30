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
		NotificationCenter.default.addObserver(self, selector: #selector(updateDefaults), name: NSUbiquitousKeyValueStore.didChangeExternallyNotification, object: nil)
        
        self.prepareSettings()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func viewDidAppear(_ animated: Bool) {
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
        NotificationCenter.default.removeObserver(self)
    }
    
}

extension SettingsViewController {
    func updateDefaults(note : NSNotification ) {
        self.prepareSettings()
    }
    
    func prepareSettings() {
        
        settingsSwitch1.isOn = UserDefaults.standard.bool(forKey: ICEDefaultsKeys.Setting1.rawValue)
        settingsSwitch2.isOn = UserDefaults.standard.bool(forKey: ICEDefaultsKeys.Setting2.rawValue)
        settingsSwitch3.isOn = UserDefaults.standard.bool(forKey: ICEDefaultsKeys.Setting3.rawValue)
        
        if let text = UserDefaults.standard.string(forKey: ICEDefaultsKeys.textValue.rawValue) {
            self.textField.text = text
        }
        
        self.valueStepper.value = Double(UserDefaults.standard.integer(forKey: ICEDefaultsKeys.stepperValue.rawValue))
        self.valueLabel.text = "Add Clouds: \(Int(valueStepper.value))"
    }
}

extension SettingsViewController {
    
    @IBAction func addNewClouds( sender : UIButton ) {
        if let adder = self.cloudAdder, let stack = self.stack {
            let clouds = stack.performRequestForTemplate(ICEFetchRequests.CloudFetch)
            let total = Int(self.valueStepper.value)
            let runningTotal = clouds.count + 1
            for i in 0 ..< total {
                adder.addCloudWithNumber(number: runningTotal + i, addRaindrops : false)
            }
            self.updateCount()
            
        }
    }
    
    @IBAction func settingsSwitchChanged( sender : UISwitch ) {
        
        var key : String?
        if let senderSwitch = sender.accessibilityLabel {
            if senderSwitch.contains("1") {
                key = ICEDefaultsKeys.Setting1.rawValue
            } else if senderSwitch.contains("2") {
                key = ICEDefaultsKeys.Setting2.rawValue
            } else if senderSwitch.contains("3") {
                key = ICEDefaultsKeys.Setting3.rawValue
            }
        }

        if let hasKey = key {
            UserDefaults.standard.set(sender.isOn, forKey: hasKey)
        }
        
    }
    
    @IBAction func stepperChanged( sender : UIStepper ) {
        self.valueLabel.text = "Add Clouds: \(Int(sender.value))"
        UserDefaults.standard.set(Int(sender.value), forKey: ICEDefaultsKeys.stepperValue.rawValue)
    }
    
    @IBAction func dismissCloudVC(sender : UIBarButtonItem ) {
        self.dismiss(animated: true, completion: nil)
    }
    
}

extension SettingsViewController {
    func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        
        if let navController = segue.destination as? UINavigationController, let documentsVC = navController.viewControllers.first as? DocumentsTableViewController {
            documentsVC.stack = self.stack
            documentsVC.documentsManager = self.backupManager
        }
        

        if let navController = segue.destination as? UINavigationController, let cloudVC = navController.viewControllers.first as? StormcloudFetchedResultsController {
            
            if let context = self.stack?.managedObjectContext {
                let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Cloud")
                fetchRequest.sortDescriptors = [NSSortDescriptor(key: "order", ascending: true)]
                fetchRequest.fetchBatchSize = 20
                cloudVC.frc = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: context, sectionNameKeyPath: nil, cacheName: nil)
            }
            
			cloudVC.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(SettingsViewController.dismissCloudVC))
            
            cloudVC.enableDelete = true
            cloudVC.cellCallback = { (tableView: UITableView, object: NSManagedObject, ip : IndexPath) -> UITableViewCell in
                guard let cell = tableView.dequeueReusableCell(withIdentifier: "CloudTableViewCell") else {
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
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()        
        return true;
    }
    
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        UserDefaults.standard.set(textField.text, forKey: ICEDefaultsKeys.textValue.rawValue)
    }
    
}
