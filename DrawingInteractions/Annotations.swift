//
//  Annotations.swift
//  DrawingInteractions
//
//  Created by Toby Harris on 26/03/2018.
//  Copyright © 2018 Toby Harris. All rights reserved.
//

import UIKit
import AVFoundation
import os.log

class Annotations {
    var fullFrameSize = CGSize.zero
    var thumbnailSize = CGSize.zero
    var screenScale = CGFloat(2.0) // FIXME: UIApplication.shared.delegate!.window!!.screen.scale
    
    var staticDrawings:[CMTimeValue:[Line]] = [:]
    var staticDrawingsFullFrame:[CMTimeValue:CGImage] = [:]
    var staticDrawingsThumb:[CMTimeValue:CGImage] = [:]
    
    func staticDrawingAt(time: CMTime) -> (lines: [Line], fullImage: CGImage, thumbImage: CGImage)? {
        guard let lines = staticDrawings[time.value] else {
            return nil
        }
        if staticDrawingsFullFrame.index(forKey: time.value) == nil {
            fullFrameContext.clear(CGRect(origin: CGPoint.zero, size: fullFrameSize))
            for line in lines {
                line.drawCommitedPointsInContext(context: fullFrameContext, isDebuggingEnabled: false, usePreciseLocation: true)
            }
            if let image = fullFrameContext.makeImage() {
                staticDrawingsFullFrame[time.value] = image
            }
            else {
                os_log("Failed to make a staticDrawingsFullFrame")
                return nil
            }
        }
        if staticDrawingsThumb.index(forKey: time.value) == nil {
            thumbContext.clear(CGRect(origin: CGPoint.zero, size: thumbnailSize))
            for line in lines {
                line.drawCommitedPointsInContext(context: thumbContext, isDebuggingEnabled: false, usePreciseLocation: true)
            }
            if let image = thumbContext.makeImage() {
                staticDrawingsThumb[time.value] = image
            }
            else {
                os_log("Failed to make a staticDrawingsThumb")
                return nil
            }
        }
        return (lines, staticDrawingsFullFrame[time.value]!, staticDrawingsThumb[time.value]!)
    }
    
    lazy var fullFrameContext: CGContext = {
        var size = fullFrameSize
        
        size.width *= screenScale
        size.height *= screenScale
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        
        let context: CGContext = CGContext.init(data: nil, width: Int(size.width), height: Int(size.height), bitsPerComponent: 8, bytesPerRow: 0, space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        
        context.setLineCap(.round)
        let transform = CGAffineTransform.init(scaleX:screenScale, y: screenScale)
        context.concatenate(transform)
        
        return context
    }()
    lazy var thumbContext: CGContext = {
        var size = thumbnailSize
        
        size.width *= screenScale
        size.height *= screenScale
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        
        let context: CGContext = CGContext.init(data: nil, width: Int(size.width), height: Int(size.height), bitsPerComponent: 8, bytesPerRow: 0, space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        
        context.setLineCap(.round)
        let transform = CGAffineTransform.init(scaleX:screenScale, y: screenScale)
        context.concatenate(transform)
        
        return context
    }()
}
