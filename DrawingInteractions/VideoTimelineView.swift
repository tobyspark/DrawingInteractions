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
            let naturalSize = newValue?.tracks(withMediaType: .video).first?.naturalSize
            let aspectRatio = naturalSize!.width / naturalSize!.height
            displaySize.width = displaySize.height * aspectRatio
            imageCountOutwards = Int(((bounds.width*0.5) / displaySize.width).rounded(.up)) + 1
            // FIXME: This doesn't set the timeline on paused start
            time = (newValue?.tracks(withMediaType: .video).first?.timeRange.start)!
        }
    }
    
    var time: CMTime {
        didSet {
            updateImages()
            setNeedsDisplay()
        }
    }
    
    // MARK: Overrides
    
    override init(frame: CGRect) {
        self.time = CMTime()
        self.displaySize = CGSize(width: frame.height, height: frame.height)
        super.init(frame: frame)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("NSCoding not implemented")
    }
    
    override func draw(_ rect: CGRect) {
        if let context = UIGraphicsGetCurrentContext() {
            let offsetNormalised = CGFloat(time.value % displayPeriod) / CGFloat(displayPeriod)
            let offsetPoints = offsetNormalised * displaySize.width
            let imageTimeSequence = images.keys.sorted()
            for (i, t) in imageTimeSequence.enumerated() {
                if let image = images[t]! {
                    context.draw(image, in: CGRect(
                        x: -offsetPoints + CGFloat(i) * displaySize.width,
                        y: 0,
                        width: displaySize.width,
                        height: displaySize.height
                        ))
                }
            }
        }
    }

    // MARK: Private
    
    private var generator: AVAssetImageGenerator?
    private var images: [CMTimeValue:CGImage?] = [:]
    private var displaySize = CGSize()
    private var displayPeriod = CMTimeValue(1)
    private var imageCountOutwards = 1
    
    private func updateImages() {
        if let g = generator {
            // TODO: Set on asset set
            displayPeriod = CMTimeValue(time.timescale)
            
            let anchorTime = (time.value / displayPeriod) * displayPeriod
            let time0 = anchorTime - CMTimeValue(imageCountOutwards)*displayPeriod
            let imageTimesOld = Set(images.keys)
            let imageTimesNew:Set<CMTimeValue> = {
                var times = Set<CMTimeValue>()
                for i in 0..<imageCountOutwards*2 {
                    times.insert(time0 + CMTimeValue(i)*displayPeriod)
                }
                return times
            }()
            
            let imageTimesToRemove = imageTimesOld.subtracting(imageTimesNew)
            for t in imageTimesToRemove {
                images.removeValue(forKey: t)
            }
            
            let imageTimesToAdd = imageTimesNew.subtracting(imageTimesOld)
            for t in imageTimesToAdd {
                images.updateValue(nil, forKey: t)
            }
            // TODO: Black frames, i.e. create keys but don't generate images for times before start, after end
            g.generateCGImagesAsynchronously(
                forTimes: imageTimesToAdd.map { NSValue(time: CMTime(value: $0, timescale: time.timescale)) },
                completionHandler: { (requestedTime, image, actualTime, resultCode, error) in
                    if let i = image {
                        self.images[requestedTime.value] = i
                    }
            })
        }
    }
}
