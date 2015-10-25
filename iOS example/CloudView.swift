//
//  CloudView.swift
//  iOS example
//
//  Created by Simon Fairbairn on 25/10/2015.
//  Copyright © 2015 Voyage Travel Apps. All rights reserved.
//

import UIKit

@IBDesignable
class CloudView: UIView {

    @IBInspectable var cloudColor : UIColor = UIColor.blueColor() {
        didSet {

            self.setNeedsDisplay()
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.setup()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.setup()
    }
    
    func setup() {
        self.translatesAutoresizingMaskIntoConstraints = false
        self.backgroundColor = UIColor.clearColor()
    }
    
    // Only override drawRect: if you perform custom drawing.
    // An empty implementation adversely affects performance during animation.
    override func drawRect(rect: CGRect) {
        // Drawing code
        
        if CGRectIsEmpty(rect) {
            return
        }

        self.cloudColor.setFill()
        
        let centerX = CGRectGetMidX(self.bounds)
        let centerY = CGRectGetMidY(self.bounds)
        
        let quarterX = centerX / 2
        let quarterY = centerY / 2
        
        let width = CGRectGetWidth(self.bounds)
        let height = CGRectGetHeight(self.bounds)
        
        let thirdX = width / 3
        let thirdY = height / 3
        
        let bottomLeftRect = CGRectMake(0, centerY, thirdX, centerY)
        let bottomLeftPath = UIBezierPath(ovalInRect: bottomLeftRect)
        bottomLeftPath.fill()

        let bottomRightRect = CGRectMake(thirdX * 2, centerY, thirdX, centerY)
        let bottomRightPath = UIBezierPath(ovalInRect: bottomRightRect)
        bottomRightPath.fill()
        
        let bottomRect = CGRectMake(thirdX / 2, centerY, thirdX * 2, centerY)
        let bottomRectPath = UIBezierPath(rect: bottomRect)
        bottomRectPath.fill()
        
        let centerCircle = CGRectMake(thirdX / 2, 0, thirdX * 2, thirdX * 2)
        let centerCirclePath = UIBezierPath(ovalInRect: centerCircle)
        centerCirclePath.fill()
        
    }


}
