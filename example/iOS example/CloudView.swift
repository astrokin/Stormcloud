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

    @IBInspectable var cloudColor : UIColor = UIColor.blue {
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
        
        if rect.isEmpty {
            return
        }

        self.cloudColor.setFill()
        
        let centerX = self.bounds.midX
        let centerY = self.bounds.midY
        
//        let quarterX = centerX / 2
//        let quarterY = centerY / 2
        
        let width = self.bounds.width
//        let height = CGRectGetHeight(self.bounds)
        
        let thirdX = width / 3
//        let thirdY = height / 3
        
		let bottomLeftRect = CGRect(x: 0, y: centerY, width: thirdX, height: centerY)
        let bottomLeftPath = UIBezierPath(ovalIn: bottomLeftRect)
        bottomLeftPath.fill()

		let bottomRightRect = CGRect(x: thirdX * 2, y: centerY, width: thirdX, height: centerY)
        let bottomRightPath = UIBezierPath(ovalIn: bottomRightRect)
        bottomRightPath.fill()
        
		let bottomRect = CGRect(x: thirdX / 2, y: centerY, width: thirdX * 2, height: centerY)
        let bottomRectPath = UIBezierPath(rect: bottomRect)
        bottomRectPath.fill()
        
        
        // When quarter
        
        let circleSize = thirdX * 2
        
		let centerCircle = CGRect(x: centerX - (circleSize / 2), y: centerY - (circleSize / 2), width: circleSize, height: circleSize)
        let centerCirclePath = UIBezierPath(ovalIn: centerCircle)
        centerCirclePath.fill()
        
//        
//        let miniCircleSize = circleSize / 3
//        let xPos = centerX - (( circleSize / 2) + (  miniCircleSize / 2 ) )
//        let yPos = centerY - miniCircleSize / 2
//        
//        let miniCircleRect = CGRectMake(xPos, yPos, miniCircleSize, miniCircleSize)
//        let miniCirclePath = UIBezierPath(ovalInRect: miniCircleRect)
//        miniCirclePath.fill()
//        
//        let newXpos = centerX + (( circleSize / 2) - (  miniCircleSize / 2 ) )
//        let secondMiniCircleRect = CGRectMake(newXpos, yPos, miniCircleSize, miniCircleSize)
//        let secondMiniCirclePath = UIBezierPath(ovalInRect: secondMiniCircleRect)
//        secondMiniCirclePath.fill()
        
        
        
    }


}
