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
            displaySize.width = displaySize.height / aspectRatio
            imageCountOutwards = Int(((bounds.width*0.5) / displaySize.width).rounded(.up))
        }
    }
    
    var time: CMTime {
        didSet {
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
                print("Remove: ", imageTimesToRemove.sorted())
                for t in imageTimesToRemove {
                    images.removeValue(forKey: t)
                }
                
                let imageTimesToAdd = imageTimesNew.subtracting(imageTimesOld)
                print("Add: ", imageTimesToAdd.sorted())
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
            setNeedsDisplay()
        }
    }
    
    override init(frame: CGRect) {
        self.time = CMTime()
        super.init(frame: frame)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("NSCoding not implemented")
    }
    
    // Only override draw() if you perform custom drawing.
    // An empty implementation adversely affects performance during animation.
    override func draw(_ rect: CGRect) {
        if let context = UIGraphicsGetCurrentContext() {
            let imageTimeSequence = images.keys.sorted()
            for (i, t) in imageTimeSequence.enumerated() {
                if let image = images[t]! {
                    context.draw(image, in: CGRect(
                        x: 0.0 + CGFloat(i) * displaySize.width,
                        y: 0,
                        width: displaySize.width,
                        height: displaySize.height
                        ))
                }
            }
        }
    }

    private var generator: AVAssetImageGenerator?
    private var images: [CMTimeValue:CGImage?] = [:]
    private var displaySize = CGSize(width: 44.0, height: 44.0)
    private var displayPeriod = CMTimeValue(1)
    private var imageCountOutwards = 1
}
