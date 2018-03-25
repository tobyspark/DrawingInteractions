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
    
    let videoIsFlipped = true
    let nowMarkerDiameter:CGFloat = 12
    let textAttributes:[NSAttributedStringKey: Any] = [.foregroundColor: UIColor.white]
    
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
    
    func boundsDidChange() {
        updateImages()
        setNeedsDisplay()
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
            // Draw video frames
            if videoIsFlipped {
                context.saveGState()
                context.translateBy(x: 0.0, y: displaySize.height)
                context.scaleBy(x: 1.0, y: -1.0)
            }
            for t in images.keys {
                let imageRect = CGRect(
                    x: xAt(time: t),
                    y: 0,
                    width: displaySize.width,
                    height: displaySize.height
                )
                if let image = images[t]! {
                    context.draw(image, in: imageRect)
                }
                else {
                    context.setFillColor(UIColor.black.cgColor)
                    context.fill(imageRect)
                }
            }
            if videoIsFlipped {
                context.restoreGState()
            }
            
            // Draw timestamps
            for t in images.keys {
                let textPoint = CGPoint(
                    x: xAt(time: t),
                    y: displaySize.height/2.0 - 6
                )
                let secs = Double(t) / Double(time.timescale)
                ("\(secs)" as NSString).draw(at:textPoint, withAttributes: textAttributes)
            }
            
            // Draw 'now' marker
            context.setFillColor(gray: 1.0, alpha: 1.0)
            context.fillEllipse(in: CGRect(
                x: bounds.midX - nowMarkerDiameter/2.0,
                y: bounds.midY - nowMarkerDiameter/2.0,
                width: nowMarkerDiameter,
                height: nowMarkerDiameter
            ))
        }
    }

    // MARK: Private
    
    private var generator: AVAssetImageGenerator?
    private var images: [CMTimeValue:CGImage?] = [:]
    private var displaySize = CGSize()
    private var displayPeriod = CMTimeValue(1)
    private var timeRange = CMTimeRange()
    
    private func updateImages() {
        if let g = generator {
            let imageCountOutwards = Int(((bounds.width*0.5) / displaySize.width).rounded(.up)) + 1
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
    
    private func timeAt(x: CGFloat) -> CMTime {
        let timePerPoint = CGFloat(displayPeriod) / displaySize.width
        let xOffset = x - bounds.midX
        let timeOffset = CMTimeValue(xOffset * timePerPoint)
        return CMTime(value: time.value + timeOffset, timescale: time.timescale)
    }
    
    private func xAt(time xTime:CMTimeValue) -> CGFloat {
        return xAt(time: CMTime(value: xTime, timescale: time.timescale))
    }
    
    private func xAt(time xTime:CMTime) -> CGFloat {
        guard time.timescale == xTime.timescale else
        { fatalError("Inconsistent timescale encountered") }
        let timePerPoint = CGFloat(displayPeriod) / displaySize.width
        let timeOffset = xTime.value - time.value
        let pointsOffset = CGFloat(timeOffset) / timePerPoint
        return bounds.midX + pointsOffset
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
            delegate?.time = newTime
        }
        else {
            // On cancellation, return the piece to its original location.
            center = initialCenter
            time = initialTime
        }
    }
    
    @objc private func tapAction(_ gestureRecognizer: UITapGestureRecognizer) {
        // Set time to the timeline time at the tapped point
        if gestureRecognizer.state == .ended {
            let newTime = timeAt(x: gestureRecognizer.location(in: superview).x)
            // ...perchance to dream.
            //UIView.animate(
            //    withDuration: 0.5,
            //    animations: { self.delegate?.time = newTime }
            //)
            // ...so DIY
            self.delegate?.scrub(to: newTime, withDuration: 0.5)
        }
    }
}
