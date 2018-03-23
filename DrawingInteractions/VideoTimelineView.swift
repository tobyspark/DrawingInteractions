//
//  VideoTimelineView.swift
//  DrawingInteractions
//
//  Created by Toby Harris on 23/03/2018.
//  Copyright © 2018 Toby Harris. All rights reserved.
//

import UIKit
import AVFoundation

class VideoTimelineView: UIView {

    // MARK: Properties
    
    var asset: AVAsset? {
        get {
            return nil
        }
        set {
            generator = AVAssetImageGenerator(asset: newValue!)
        }
    }
    
    var time: CMTime {
        get {
            return CMTime()
        }
        set {
            if let g = generator {
                image = try! g.copyCGImage(at: newValue, actualTime: nil)
                setNeedsDisplay()

            }
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("NSCoding not implemented")
    }
    
    // Only override draw() if you perform custom drawing.
    // An empty implementation adversely affects performance during animation.
    override func draw(_ rect: CGRect) {
        if let context = UIGraphicsGetCurrentContext(), let i = image {
            context.draw(i, in: rect)
        }
    }

    private var generator: AVAssetImageGenerator?
    private var image: CGImage?
}
