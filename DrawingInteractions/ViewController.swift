//
//  ViewController.swift
//  DrawingInteractions
//
//  Created by Toby Harris on 23/03/2018.
//  Copyright © 2018 Toby Harris. All rights reserved.
//

import UIKit
import AVFoundation

class ViewController: UIViewController {
    
    // MARK: Properties
    
    var staticDrawings:[CMTimeValue:[Line]] = [:]
    var staticDrawingsImaged:[CMTimeValue:CGImage] = [:]
    
    let movie = (name:"testvideo", ext:"mov")
    let stripHeight:CGFloat = 44
    
    // The time any component wants the video to be at
    var desiredTime = kCMTimeZero {
        didSet {
            time = CMTimeClampToRange(time, timeBounds)
            videoView.time = desiredTime
        }
    }
    
    // The actual time, driven by the video playback
    var time = kCMTimeZero {
        willSet {
            // Save static drawing, clear canvas
            let newCount = canvasView.finishedLines.count
            if newCount > 0 {
                if let oldCount = staticDrawings[time.value]?.count {
                    // The lines have changed, update and invalidate cache
                    if oldCount != newCount {
                        staticDrawings[time.value] = canvasView.finishedLines
                        staticDrawingsImaged.removeValue(forKey: time.value)
                    }
                    // The lines have not changed, do nothing
                }
                else {
                    // There is a new drawing
                    staticDrawings[time.value] = canvasView.finishedLines
                }
                canvasView.clear()
            }
        }
        didSet {
            // Propogate time amongst views
            timelineView.time = time
            // Load static drawing
            if let d = staticDrawingAt(time: time) {
                canvasView.finishedLines = d.lines
                canvasView.frozenImage = d.image
                canvasView.setNeedsDisplay()
            }
        }
    }
    
    /// A `CGContext` for drawing the last representation of lines no longer receiving updates into.
    lazy var lineContext: CGContext = {
        let scale = view.window!.screen.scale
        var size = view.bounds.size
        
        size.width *= scale
        size.height *= scale
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        
        let context: CGContext = CGContext.init(data: nil, width: Int(size.width), height: Int(size.height), bitsPerComponent: 8, bytesPerRow: 0, space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        
        context.setLineCap(.round)
        let transform = CGAffineTransform.init(scaleX:scale, y: scale)
        context.concatenate(transform)
        
        return context
    }()
    func staticDrawingAt(time: CMTime) -> (lines: [Line], image: CGImage)? {
        guard let lines = staticDrawings[time.value] else {
            return nil
        }
        if staticDrawingsImaged.index(forKey: time.value) == nil {
            lineContext.clear(view.bounds)
            for line in lines {
                line.drawCommitedPointsInContext(context: lineContext, isDebuggingEnabled: false, usePreciseLocation: true)
            }
            if let image = lineContext.makeImage() {
                staticDrawingsImaged[time.value] = image
            }
            else {
                return nil
            }
        }
        return (lines, staticDrawingsImaged[time.value]!)
    }
    
    var timeBounds = kCMTimeRangeZero
    var videoSize = CGSize()
    
    var timelineView: VideoTimelineView!
    var canvasView: CanvasView!
    var videoView: VideoView {
        return view as! VideoView
    }
    
    func setVideo(_ movieURL:URL) {
        let player = AVPlayer(url: movieURL)
        if let track = player.currentItem!.asset.tracks(withMediaType: .video).first {
            timeBounds = track.timeRange
            videoSize = track.naturalSize
            timelineView.setVideoTrack(track)
            videoView.player = player
            time = track.timeRange.start
        }
    }
    
    // Ideally, there would be a CAAnimation-like way of animating the `time` property
    // Without, here is the DIY ugliness.
    func scrub(to newTime:CMTime, withDuration duration:TimeInterval) {
        let startDate = Date()
        let startTime = time
        let timeDelta = newTime - startTime
        if let t = scrubTimer {
            t.invalidate()
        }
        scrubTimer = Timer.scheduledTimer(withTimeInterval: 1.0/60.0, repeats: true) { (timer) in
            let progress = -startDate.timeIntervalSinceNow / duration
            if progress > 1.0 {
                timer.invalidate()
            }
            let easedProgress = sin(progress*Double.pi/2.0)
            self.desiredTime = startTime + CMTime(
                value: CMTimeValue(easedProgress*Double(timeDelta.value)),
                timescale: timeDelta.timescale
            )
        }
    }
    private var scrubTimer:Timer?
    
    // MARK: Touch Handling
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        let stylusTouches = touches.filter { return $0.type == .stylus }
        if !stylusTouches.isEmpty {
            canvasView.drawTouches(touches: stylusTouches, withEvent: event)
        }
        let otherTouches = touches.subtracting(stylusTouches)
        if !otherTouches.isEmpty {
            super.touchesBegan(touches, with: event)
        }
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        let stylusTouches = touches.filter { return $0.type == .stylus }
        if !stylusTouches.isEmpty {
            canvasView.drawTouches(touches: stylusTouches, withEvent: event)
        }
        let otherTouches = touches.subtracting(stylusTouches)
        if !otherTouches.isEmpty {
            super.touchesBegan(touches, with: event)
        }
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        let stylusTouches = touches.filter { return $0.type == .stylus }
        if !stylusTouches.isEmpty {
            canvasView.drawTouches(touches: stylusTouches, withEvent: event)
            canvasView.endTouches(touches: stylusTouches, cancel: false)
        }
        let otherTouches = touches.subtracting(stylusTouches)
        if !otherTouches.isEmpty {
            super.touchesBegan(touches, with: event)
        }
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        let stylusTouches = touches.filter { return $0.type == .stylus }
        if !stylusTouches.isEmpty {
            canvasView.endTouches(touches: stylusTouches, cancel: false)
        }
        let otherTouches = touches.subtracting(stylusTouches)
        if !otherTouches.isEmpty {
            super.touchesBegan(touches, with: event)
        }
    }
    
    override func touchesEstimatedPropertiesUpdated(_ touches: Set<UITouch>) {
        let stylusTouches = touches.filter { return $0.type == .stylus }
        if !stylusTouches.isEmpty {
            canvasView.updateEstimatedPropertiesForTouches(touches: stylusTouches)
        }
        let otherTouches = touches.subtracting(stylusTouches)
        if !otherTouches.isEmpty {
            super.touchesEstimatedPropertiesUpdated(touches)
        }
    }

    // MARK: View Life Cycle

    override func viewDidLoad() {
        super.viewDidLoad()
        
        guard let movieURL = Bundle.main.url(forResource: movie.name, withExtension: movie.ext) else {
            fatalError("Can't find \(movie)")
        }
        
        canvasView = CanvasView()
        canvasView.frame = view.frame
        canvasView.translatesAutoresizingMaskIntoConstraints = true
        canvasView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        canvasView.backgroundColor = .clear
        canvasView.usePreciseLocations = true
        view.addSubview(canvasView)
        
        let strip = CGRect(x: 0, y: 0, width: view.frame.width, height: stripHeight)
        timelineView = VideoTimelineView(frame: strip)
        timelineView.translatesAutoresizingMaskIntoConstraints = true
        timelineView.center = CGPoint(x: view.bounds.midX, y: view.bounds.midY)
        timelineView.autoresizingMask = [.flexibleWidth, .flexibleTopMargin, .flexibleBottomMargin]
        timelineView.delegate = self
        videoView.delegate = self
        view.addSubview(timelineView)
        
        setVideo(movieURL)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func viewDidLayoutSubviews() {
        timelineView.boundsDidChange()
    }
}
