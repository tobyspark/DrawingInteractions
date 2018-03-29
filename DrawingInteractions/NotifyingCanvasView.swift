//
//  NotifyingCanvasView.swift
//  DrawingInteractions
//
//  Created by Toby Harris on 28/03/2018.
//  Copyright © 2018 Toby Harris. All rights reserved.
//

import UIKit

class NotifyingCanvasView: CanvasView {
    
    override var finishedLines: [Line] {
        get { return super.finishedLines }
        set {
            super.finishedLines = newValue
            delegate?.linesDidUpdate()
        }
    }
    
    var delegate: ViewController?
    
    var focusPoints = [(amount:CGFloat, points:[CGPoint])]()
    
    let focusDiameter = CGFloat(100)
    
    override func clear() {
        focusPoints.removeAll(keepingCapacity: true)
        super.clear()
    }
    
    override func draw(_ rect: CGRect) {
        let context = UIGraphicsGetCurrentContext()!
        
        context.setLineCap(.round)
        
        if needsFullRedraw {
            setFrozenImageNeedsUpdate()
            frozenContext.clear(bounds)
            if focusPoints.count > 0 {
                let maxFocusAmount = focusPoints.map({$0.amount}).max()!
                frozenContext.setFillColor(gray: 1.0, alpha: 0.5*maxFocusAmount)
                frozenContext.fill(bounds)
                frozenContext.setBlendMode(.destinationOut)
                for (amount, points) in focusPoints {
                    frozenContext.setFillColor(gray: 1.0, alpha: amount*amount) // use square to compensate for alpha accumulating in overlaps
                    for point in points {
                        frozenContext.fillEllipse(in: CGRect(x: point.x - focusDiameter/2.0,
                                                            y: point.y - focusDiameter/2.0,
                                                            width: focusDiameter,
                                                            height: focusDiameter
                        ))
                    }
                }
                frozenContext.setBlendMode(.normal)
            }
            for array in [finishedLines,lines] {
                for line in array {
                    line.drawCommitedPointsInContext(context: frozenContext, isDebuggingEnabled: isDebuggingEnabled, usePreciseLocation: usePreciseLocations)
                }
            }
            needsFullRedraw = false
        }
        
        frozenImage = frozenImage ?? frozenContext.makeImage()
        
        if let frozenImage = frozenImage {
            context.draw(frozenImage, in: bounds)
        }
        
        for line in lines {
            line.drawInContext(context: context, isDebuggingEnabled: isDebuggingEnabled, usePreciseLocation: usePreciseLocations)
        }
    }
}
