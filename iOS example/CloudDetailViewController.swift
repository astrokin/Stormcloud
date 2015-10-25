//
//  CloudDetailViewController.swift
//  iCloud Extravaganza
//
//  Created by Simon Fairbairn on 24/10/2015.
//  Copyright © 2015 Voyage Travel Apps. All rights reserved.
//

import UIKit
import Stormcloud
import CoreData

class CloudDetailViewController: UIViewController {

    @IBOutlet weak var cloudImage : CloudView!
    @IBOutlet weak var raindropType: UISegmentedControl!
    @IBOutlet weak var cloudNameTextField: UITextField!
    @IBOutlet weak var exampleRaindrop: RaindropView!
    @IBOutlet weak var addRaindropButton : UIButton!
    
    @IBOutlet weak var raindropCount: UILabel!
    
    var currentCloud : Cloud?
    
    var dynamicAnimator : UIDynamicAnimator?
    let gravityBehaviour = UIGravityBehavior()
    
    var itemConstraints : [Int : [NSLayoutConstraint]] = [:]
    var dynamicItems : [Int : UIDynamicItem] = [:]
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        
        self.raindropType.removeAllSegments()
        self.setupViews()
        
        self.dynamicAnimator = UIDynamicAnimator(referenceView: self.view)
        self.dynamicAnimator?.addBehavior(self.gravityBehaviour)
        
        self.addRaindropButton.enabled = false
        
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

}

// MARK: - Methods

extension CloudDetailViewController {
    func setupViews() {
        var count = 0
        for value in RaindropType.allValues {
            self.raindropType.insertSegmentWithTitle(value.rawValue, atIndex: count, animated: false)
            count++
        }
        
        self.cloudNameTextField.delegate = self
        
        guard let cloud = self.currentCloud else {
            return
        }
        
            if let didRain = cloud.didRain?.boolValue {
                self.cloudImage.cloudColor = didRain ? UIColor.lightGrayColor() : UIColor.darkGrayColor()
            }

        
        self.raindropCount.text = "\(cloud.raindrops!.count)"
        
        self.cloudNameTextField.text = cloud.name
        // Persist outstanding changes before edits
        self.saveChanges()
    }
    
    func saveChanges() {
        self.currentCloud?.name = self.cloudNameTextField.text
        do {
            try self.currentCloud?.managedObjectContext?.save()
        } catch {
            print("Error saving")
        }
    }
    
    func rollbackChanges() {
        self.currentCloud?.managedObjectContext?.rollback()
    }
    
    func colorFromSliders() -> UIColor {
        var r : CGFloat = 0
        var g : CGFloat = 0
        var b : CGFloat = 0
        if let rView =   self.view.viewWithTag(1) as? UISlider {
            r = CGFloat(rView.value)
        }
        if let gView =   self.view.viewWithTag(2) as? UISlider {
            g = CGFloat(gView.value)
        }
        if let bView =   self.view.viewWithTag(3) as? UISlider {
            b = CGFloat(bView.value)
        }
        
        return UIColor(red: r, green: g, blue: b, alpha: 1.0)
    }
    
    func addDynamicItem( item : UIDynamicItem ) {
        self.gravityBehaviour.addItem(item)
    }
}

extension CloudDetailViewController : UITextFieldDelegate {
    func textFieldShouldReturn(textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
    
}



// MARK: - Actions

extension CloudDetailViewController {
    
    @IBAction func selectedRaindropType( sender : UISegmentedControl ) {
        
        guard let cloud = self.currentCloud else {
            return
        }
        
        self.addRaindropButton.enabled = true
        
        let subviews = self.view.subviews.filter() { $0.tag >= 100 }
        
        for view in subviews {
            let index = view.tag - 100
            if let item = self.dynamicItems[index] {
                self.gravityBehaviour.removeItem(item)
            }
            
            
            view.removeFromSuperview()
        }
        
        let type = RaindropType.allValues[sender.selectedSegmentIndex]
        
        var size = CGRectZero
        switch type {
        case .Drizzle:
            size = CGRectMake(0, 0, 5, 9)
        case .Light:
            size = CGRectMake(0, 0, 10, 18)
        case .Heavy :
            size = CGRectMake(0, 0, 15, 27)
        }
        
        let minLeading = CGFloat(CGRectGetMinX(self.cloudImage.frame))
        let maxLeading = CGFloat(CGRectGetMaxX(self.cloudImage.frame)) - size.width
        let distance = maxLeading - minLeading
        
        
        func getRandomPosition() -> CGFloat {
            let randomPos = CGFloat(Float(arc4random()) / Float(UINT32_MAX))
            return minLeading + (distance * randomPos)
        }
        
        
        var i = 0
        for raindrop in cloud.raindropsForType(type) {
            
            
            let raindropview = RaindropView(frame: size)
            raindropview.raindropColor = raindrop.colour as! UIColor
            raindropview.tag = 100 + i
            self.view.insertSubview(raindropview, belowSubview  : self.cloudImage)
            
            let yConstant : CGFloat = 30
            
            let xConstraint = NSLayoutConstraint(item: raindropview, attribute: .Leading, relatedBy: .Equal, toItem: self.view, attribute: .Leading, multiplier: 1.0, constant: getRandomPosition())
            let yConstraint = NSLayoutConstraint(item: raindropview, attribute: .CenterY, relatedBy: .Equal, toItem: self.cloudImage, attribute: .CenterY, multiplier: 1.0, constant: yConstant)
            
            self.itemConstraints[raindropview.tag] = [xConstraint, yConstraint]
            
            raindropview.widthAnchor.constraintEqualToConstant(size.width).active = true
            raindropview.heightAnchor.constraintEqualToConstant(size.height).active = true

            self.view.addConstraint(xConstraint)
            self.view.addConstraint(yConstraint)
            
            let dynamicItem = DynamicHub(bounds : CGRectMake(0, 0, size.width, size.height))
            dynamicItem.center = CGPointMake(self.cloudImage.center.x, self.cloudImage.center.y + yConstant)
            
            self.dynamicItems[raindropview.tag] = dynamicItem

            let maxDelay : NSTimeInterval = 0.5
            let randomPos = CGFloat(Float(arc4random()) / Float(UINT32_MAX))
            
            self.performSelector(Selector("addDynamicItem:"), withObject: dynamicItem, afterDelay: NSTimeInterval(maxDelay * NSTimeInterval(randomPos)) + NSTimeInterval(i) * 0.2)
            
            self.gravityBehaviour.action = {
                
                let subviews = self.view.subviews.filter() { $0.tag >= 100 }
                for subview in subviews {
                    if let dynamicItem = self.dynamicItems[subview.tag], constraints = self.itemConstraints[subview.tag] where constraints.count == 2 {
                        
                        if subview.tag == 100 {
                            let view = self.view.viewWithTag(10)
                            view?.center = dynamicItem.center
                        }
                        
                        if constraints[1].constant > self.view.bounds.size.height {
                            self.gravityBehaviour.removeItem(dynamicItem)
                            constraints[1].constant = yConstant
                            subview.updateConstraintsIfNeeded()
                            constraints[0].constant = getRandomPosition()
                            
                        } else if constraints[1].constant == yConstant && dynamicItem.center.y > self.view.bounds.size.height {
                            dynamicItem.center = subview.center
                            self.gravityBehaviour.addItem(dynamicItem)
                        } else {
                            
                            constraints[1].constant = dynamicItem.center.y - CGRectGetMidY(self.cloudImage.frame)
                        }
                    }
                }
            }
            i++
        }
    }
    
    @IBAction func addRaindrop( sender : UIButton ) {
        
        guard let cloud = self.currentCloud else{
            return
        }
        
        
        
        
        do {
            let raindrop = try Raindrop.insertRaindropWithType(RaindropType.allValues[self.raindropType.selectedSegmentIndex], withCloud: cloud, inContext: cloud.managedObjectContext!)
            raindrop.colour = self.colorFromSliders()
        } catch {
            print("Couldn't create raindrop")
        }
        
        self.selectedRaindropType(self.raindropType)
    }
    
    
    @IBAction func sliderChanged(sender: UISlider) {
        self.exampleRaindrop.raindropColor  = self.colorFromSliders()

    }
    
    @IBAction func dismissVC(sender : UIBarButtonItem ) {
        self.rollbackChanges()
        self.presentingViewController?.dismissViewControllerAnimated(true, completion: nil)
    }
    
    @IBAction func saveAndDismiss(sender : UIBarButtonItem ) {

        self.saveChanges()
        self.presentingViewController?.dismissViewControllerAnimated(true, completion: nil)
    }
}

// MARK: - VTAUtilitiesFetchedResultsControllerDetailVC

extension CloudDetailViewController : StormcloudFetchedResultsControllerDetailVC {
    
    func setManagedObject(object: NSManagedObject) {
        if let cloud = object as? Cloud {
            self.currentCloud = cloud
        }
    }
    
}
