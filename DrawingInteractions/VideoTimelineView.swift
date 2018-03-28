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
    let textAttributes:[NSAttributedStringKey: Any] = [.foregroundColor: UIColor.white]
    let targetPoints:CGFloat = 40
    
    func setVideoTrack(_ track: AVAssetTrack) {
        let aspectRatio = track.naturalSize.width / track.naturalSize.height
        displaySize.width = displaySize.height * aspectRatio
        displayPeriod = CMTimeValue(track.naturalTimeScale) // i.e. 1 sec per filmstrip cell
        timeRange = track.timeRange
        generator = AVAssetImageGenerator(asset: track.asset!)
        generator?.maximumSize = displaySize
    }
    
    var time: CMTime {
        didSet {
            updateImages()
            setNeedsDisplay()
        }
    }
    
    func boundsDidChange() {
        triangleAltitude = iconHeight * sqrt(3.0)/2.0
        triangle1 = CGPoint(x: bounds.midX - triangleAltitude/2, y: bounds.midY - iconHeight/2)
        triangle2 = CGPoint(x: bounds.midX - triangleAltitude/2, y: bounds.midY + iconHeight/2)
        triangle3 = CGPoint(x: bounds.midX + triangleAltitude/2, y: bounds.midY)
        
        updateImages()
        setNeedsDisplay()
    }
    
    var delegate: ViewController?
    
    // MARK: Overrides
    
    override init(frame: CGRect) {
        self.time = CMTime()
        self.displaySize = CGSize(width: frame.height, height: frame.height)
        super.init(frame: frame)
        
        let panGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(panAction))
        self.addGestureRecognizer(panGestureRecognizer)
        
        let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(tapAction))
        self.addGestureRecognizer(tapGestureRecognizer)
        
        boundsDidChange()
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
            for t in frames.keys {
                let imageRect = CGRect(
                    x: xAt(time: t),
                    y: 0,
                    width: displaySize.width,
                    height: displaySize.height
                )
                if let image = frames[t]! {
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
            
            // Draw drawings
            for t in drawings.keys {
                let x = xAt(time: t)
                let tickPath = [CGPoint(x:x,y:0), CGPoint(x:x,y:displaySize.height)]
                context.setStrokeColor(gray: 1.0, alpha: 1.0)
                context.strokeLineSegments(between: tickPath)
                let imageRect = CGRect(
                    x: x - displaySize.width/2,
                    y: 0,
                    width: displaySize.width,
                    height: displaySize.height
                )
                context.draw(drawings[t]!, in: imageRect)
            }
            
            // Draw timestamps
            for t in frames.keys {
                let textPoint = CGPoint(
                    x: xAt(time: t),
                    y: displaySize.height/2.0 - 6
                )
                let secs = Double(t) / Double(time.timescale)
                ("\(secs)" as NSString).draw(at:textPoint, withAttributes: textAttributes)
            }
            
            // Draw play/pause icon with 'now' markers
            context.setFillColor(gray: 1.0, alpha: 1.0)
            context.strokeLineSegments(between: [
                CGPoint(x: bounds.midX, y: 0), CGPoint(x: bounds.midX, y: 0 + tickHeight),
                CGPoint(x: bounds.midX, y: displaySize.height), CGPoint(x: bounds.midX, y: displaySize.height - tickHeight),
                ])
            if delegate?.rate.isPaused ?? true {
                context.strokeLineSegments(between: [
                    triangle1, triangle2,
                    triangle2, triangle3,
                    triangle3, triangle1
                    ])
            }
            else {
                context.stroke(CGRect(
                    x: bounds.midX - rectSpacing - rectWidth,
                    y: bounds.midY - iconHeight/2,
                    width: rectWidth,
                    height: iconHeight
                ))
                context.stroke(CGRect(
                    x: bounds.midX + rectSpacing,
                    y: bounds.midY - iconHeight/2,
                    width: rectWidth,
                    height: iconHeight
                ))
            }
        }
    }

    // MARK: Private
    
    private var generator: AVAssetImageGenerator?
    private var frames: [CMTimeValue:CGImage?] = [:]
    private var drawings: [CMTimeValue: CGImage] = [:]
    var displaySize = CGSize()
    private var displayPeriod = CMTimeValue(1)
    private var timeRange = CMTimeRange()
    
    let tickHeight = CGFloat(6)
    let iconHeight = CGFloat(20)
    let rectWidth = CGFloat(7)
    let rectSpacing = CGFloat(3)
    var triangleAltitude = CGFloat()
    var triangle1 = CGPoint()
    var triangle2 = CGPoint()
    var triangle3 = CGPoint()
    
    private func updateImages() {
        let imageCountOutwards = Int(((bounds.width*0.5) / displaySize.width).rounded(.up)) + 1
        let anchorTime = (time.value / displayPeriod) * displayPeriod
        let timeMin = anchorTime - CMTimeValue(imageCountOutwards)*displayPeriod
        let timeMax = anchorTime + CMTimeValue(imageCountOutwards)*displayPeriod
        // frames, e.g. filmstrip cells
        if let g = generator {
            let imageTimesOld = Set(frames.keys)
            let imageTimesNew:Set<CMTimeValue> = {
                var times = Set<CMTimeValue>()
                for i in 0..<imageCountOutwards*2 {
                    times.insert(timeMin + CMTimeValue(i)*displayPeriod)
                }
                return times
            }()
            
            let imageTimesToRemove = imageTimesOld.subtracting(imageTimesNew)
            for t in imageTimesToRemove {
                frames.removeValue(forKey: t)
            }
            
            let imageTimesToAdd = imageTimesNew.subtracting(imageTimesOld)
            for t in imageTimesToAdd {
                frames.updateValue(nil, forKey: t)
            }

            let imageTimesToGet = imageTimesToAdd.filter { CMTimeRangeContainsTime(timeRange, CMTime(value:$0, timescale: time.timescale)) }
            g.generateCGImagesAsynchronously(
                forTimes: imageTimesToGet.sorted().map { NSValue(time: CMTime(value: $0, timescale: time.timescale)) },
                completionHandler: { (requestedTime, image, actualTime, resultCode, error) in
                    if let i = image {
                        self.frames[requestedTime.value] = i
                        DispatchQueue.main.async(execute: { self.setNeedsDisplay() })
                    }
            })
        }
        // drawings
        if let d = delegate {
            let drawingTimes = d.annotations.staticDrawings.keys.filter({ $0 >= timeMin && $0 <= timeMax })
            for time in drawingTimes {
                if let drawing = d.annotations.staticDrawingAt(time: CMTime(value: time, timescale:timeRange.start.timescale)) {
                    drawings[time] = drawing.thumbImage
                }
                self.setNeedsDisplay()
            }
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
            delegate?.desiredTime = newTime
        }
        else {
            // On cancellation, return the piece to its original location.
            center = initialCenter
            delegate?.desiredTime = initialTime
        }
    }
    
    @objc private func tapAction(_ gestureRecognizer: UITapGestureRecognizer) {
        // Play-pause psuedo button at centre
        // Set time to the timeline time at the tapped point
        if gestureRecognizer.state == .ended {
            let tapX = gestureRecognizer.location(in: superview).x
            switch tapX {
            case bounds.midX-targetPoints...bounds.midX+targetPoints:
                if let d = delegate {
                    d.rate.isPaused = !d.rate.isPaused
                }
                setNeedsDisplay()
            default:
                var newTime = timeAt(x: tapX)
                if let nearestSnapTime = drawings.keys.min(by: { abs($0 - time.value) < abs($1 - time.value) }) {
                    let nearestSnapX = xAt(time: nearestSnapTime)
                    if abs(tapX - nearestSnapX) < targetPoints {
                        newTime = timeAt(x: nearestSnapX)
                    }
                }
                // ...perchance to dream.
                //UIView.animate(
                //    withDuration: 0.5,
                //    animations: { self.delegate?.time = newTime }
                //)
                // ...so DIY
                delegate?.scrub(to: newTime, withDuration: 0.5)
            }
        }
    }
}
