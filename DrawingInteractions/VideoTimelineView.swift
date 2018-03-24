//
//  VideoTimelineView.swift
//  DrawingInteractions
//
//  Created by Toby Harris on 23/03/2018.
//  Copyright © 2018 Toby Harris. All rights reserved.
//

import UIKit
import AVFoundation
import os.log

class VideoTimelineView: UIView {

    // MARK: Properties
    
    var asset: AVAsset? {
        get {
            return nil
        }
        set {
            if let videoTrack = newValue?.tracks(withMediaType: .video).first {
                displayPeriod = CMTimeValue(videoTrack.naturalTimeScale)
                timeRange = videoTrack.timeRange
                
                let aspectRatio = videoTrack.naturalSize.width / videoTrack.naturalSize.height
                displaySize.width = displaySize.height * aspectRatio
                imageCountOutwards = Int(((bounds.width*0.5) / displaySize.width).rounded(.up)) + 1
                
                generator = AVAssetImageGenerator(asset: newValue!)
                generator?.maximumSize = displaySize
                
                time = videoTrack.timeRange.start
            }
        }
    }
    
    var time: CMTime {
        didSet {
            time = CMTimeClampToRange(time, timeRange)
            updateImages()
            setNeedsDisplay()
        }
    }
    
    var delegate: VideoView?
    
    // MARK: Overrides
    
    override init(frame: CGRect) {
        self.time = CMTime()
        self.displaySize = CGSize(width: frame.height, height: frame.height)
        super.init(frame: frame)
        
        let panGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(panAction))
        self.addGestureRecognizer(panGestureRecognizer)
        
        let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(tapAction))
        self.addGestureRecognizer(tapGestureRecognizer)
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
                let rect = CGRect(
                    x: -offsetPoints + CGFloat(i) * displaySize.width,
                    y: 0,
                    width: displaySize.width,
                    height: displaySize.height
                )
                if let image = images[t]! {
                    context.draw(image, in: rect)
                }
                else {
                    context.setFillColor(UIColor.black.cgColor)
                    context.fill(rect)
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
    private var timeRange = CMTimeRange()
    
    private func updateImages() {
        if let g = generator {
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

            let imageTimesToGet = imageTimesToAdd.filter { CMTimeRangeContainsTime(timeRange, CMTime(value:$0, timescale: time.timescale)) }
            g.generateCGImagesAsynchronously(
                forTimes: imageTimesToGet.sorted().map { NSValue(time: CMTime(value: $0, timescale: time.timescale)) },
                completionHandler: { (requestedTime, image, actualTime, resultCode, error) in
                    if let i = image {
                        self.images[requestedTime.value] = i
                        DispatchQueue.main.async(execute: { self.setNeedsDisplay() })
                    }
            })
        }
    }
    
    private var initialCenter = CGPoint()
    private var initialTime = CMTime()
    @objc private func panAction(_ gestureRecognizer: UIPanGestureRecognizer) {
        let translation = gestureRecognizer.translation(in: superview)
        if gestureRecognizer.state == .began {
            self.initialCenter = center
            self.initialTime = time
        }
        if gestureRecognizer.state != .cancelled {
            // Pan view vertically
            let newCenter = CGPoint(x: initialCenter.x, y: initialCenter.y + translation.y)
            center = newCenter
            // Scrub video with horizontal movement
            let newTime = CMTime(value: initialTime.value - CMTimeValue(CGFloat(displayPeriod) * translation.x / displaySize.width), timescale: initialTime.timescale)
            time = newTime
            delegate?.smoothSeek(to: newTime)
        }
        else {
            // On cancellation, return the piece to its original location.
            center = initialCenter
        }
    }
    
    @objc private func tapAction(_ gestureRecognizer: UITapGestureRecognizer) {
        if gestureRecognizer.state == .ended {
            print("tap timeline")
            // this will jump to this point in the timeline.
            // but also, swallow the event so the video view doesn't get it and pause while we're dragging
        }
    }
}
