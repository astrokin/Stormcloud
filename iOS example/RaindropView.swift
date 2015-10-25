//
//  RaindropView.swift
//  iCloud Extravaganza
//
//  Created by Simon Fairbairn on 24/10/2015.
//  Copyright © 2015 Voyage Travel Apps. All rights reserved.
//

import UIKit


@IBDesignable
class RaindropView: UIView {
    
    @IBInspectable var raindropColor : UIColor = UIColor.blueColor() {
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
        
        let roundedCorner = CGFloat(2)
        
        
        
        let centerX = CGRectGetMidX(self.bounds)
//        let centerY = CGRectGetMidY(self.bounds)
        let width = CGRectGetMaxX(self.bounds)
        let height = CGRectGetMaxY(self.bounds)
        
        let arcCenterPoint = height - centerX
        
        
        
        let path = UIBezierPath()
        
        path.addArcWithCenter(CGPoint(x: centerX, y: roundedCorner), radius: roundedCorner, startAngle: CGFloat(-180).degreesToRads(), endAngle: CGFloat(0).degreesToRads(), clockwise: true)
        path.addLineToPoint(CGPoint(x: width, y: arcCenterPoint))
//
        path.addArcWithCenter(CGPoint(x: centerX, y: arcCenterPoint), radius: centerX, startAngle: CGFloat(0).degreesToRads(), endAngle: CGFloat(180).degreesToRads(), clockwise: true)
        path.closePath()

        self.raindropColor.setFill()
        path.fill()
        
    }

}
