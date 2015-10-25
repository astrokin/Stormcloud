//
//  DetailViewController.swift
//  iCloud Extravaganza
//
//  Created by Simon Fairbairn on 20/10/2015.
//  Copyright © 2015 Voyage Travel Apps. All rights reserved.
//

import UIKit
import Stormcloud


class DetailViewController: UIViewController {
    
    var itemURL : NSURL?
    var document : BackupDocument?
    var backupManager : Stormcloud?
    var stack  : CoreDataStack?
    
    @IBOutlet var detailLabel : UILabel!
    @IBOutlet var activityIndicator : UIActivityIndicatorView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Do any additional setup after loading the view.
        
        if let url = self.itemURL {
            self.document = BackupDocument(fileURL: url)
            if let doc = self.document {
                doc.openWithCompletionHandler({ (success) -> Void in
                    dispatch_async(dispatch_get_main_queue(), { () -> Void in
                        self.activityIndicator.stopAnimating()
                        if let dict = doc.objectsToBackup as? [String : AnyObject] {
                            self.detailLabel.text = "Objects backed up: \(dict.count)"
                        }
                        
                    })
                })
            }
        }
    }
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
    }
    
    override func viewWillDisappear(animated: Bool) {
        super.viewWillDisappear(animated)
        self.document?.closeWithCompletionHandler(nil)
    }
    
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    
    @IBAction func restoreObject(sender : UIButton) {
        if let context = self.stack?.managedObjectContext, doc = self.document {
            self.activityIndicator.startAnimating()
            self.view.userInteractionEnabled = false
            self.backupManager?.restoreCoreDataBackup(withDocument: doc, toContext: context , completion: { (success) -> () in
                self.activityIndicator.stopAnimating()
                self.view.userInteractionEnabled = true
            
                let avc = UIAlertController(title: "Completed!", message: (success) ? "Successfully" : "With errors", preferredStyle: .Alert)
                avc.addAction(UIAlertAction(title: "OK", style: .Cancel, handler: nil))
                self.presentViewController(avc, animated: true, completion: nil)
            
            })
        }
    }
    
    /*
    // MARK: - Navigation
    
    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
    // Get the new view controller using segue.destinationViewController.
    // Pass the selected object to the new view controller.
    }
    */
    
}
