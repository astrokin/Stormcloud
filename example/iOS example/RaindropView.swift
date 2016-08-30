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
    
    @IBInspectable var raindropColor : UIColor = UIColor.blue {
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
        self.backgroundColor = UIColor.clear
    }
    
    
    // Only override drawRect: if you perform custom drawing.
    // An empty implementation adversely affects performance during animation.
    override func draw(_ rect: CGRect) {
        // Drawing code
        
        let roundedCorner = CGFloat(2)
        
        
        
        let centerX = self.bounds.midX
//        let centerY = CGRectGetMidY(self.bounds)
        let width = self.bounds.maxX
        let height = self.bounds.maxY
        
        let arcCenterPoint = height - centerX
        
        
        
        let path = UIBezierPath()
        
        path.addArc(withCenter: CGPoint(x: centerX, y: roundedCorner), radius: roundedCorner, startAngle: CGFloat(-180).degreesToRads(), endAngle: CGFloat(0).degreesToRads(), clockwise: true)
        path.addLine(to: CGPoint(x: width, y: arcCenterPoint))
//
        path.addArc(withCenter: CGPoint(x: centerX, y: arcCenterPoint), radius: centerX, startAngle: CGFloat(0).degreesToRads(), endAngle: CGFloat(180).degreesToRads(), clockwise: true)
        path.close()

        self.raindropColor.setFill()
        path.fill()
        
    }

}
