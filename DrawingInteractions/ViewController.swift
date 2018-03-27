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
    
    let movie = (name:"testvideo", ext:"mov")
    let stripHeight:CGFloat = 44
    
    // The annotations
    var annotations = Annotations()
    
    // The time any component wants the video to be at
    var desiredTime = kCMTimeZero {
        didSet {
            time = CMTimeClampToRange(time, timeBounds)
            videoView.time = desiredTime
        }
    }
    
    // The actual time, driven by the video playback
    // Note slower than 1.0 can set multiple identical times.
    // Firstrun hack exploits time on init has timescale of 1.
    var time = kCMTimeZero {
        willSet {
            if time != newValue || time.timescale == kCMTimeZero.timescale {
                // Clear canvas, Save static drawing
                let newCount = canvasView.finishedLines.count
                if newCount > 0 {
                    if let oldCount = annotations.staticDrawings[time.value]?.count {
                        // The lines have changed, update and invalidate cache
                        if oldCount != newCount {
                            annotations.staticDrawings[time.value] = canvasView.finishedLines
                            annotations.staticDrawingsFullFrame.removeValue(forKey: time.value)
                        }
                        // The lines have not changed, do nothing
                    }
                    else {
                        // There is a new drawing
                        annotations.staticDrawings[time.value] = canvasView.finishedLines
                    }
                    canvasView.clear()
                }
            }
        }
        didSet {
            if time != oldValue || oldValue.timescale == kCMTimeZero.timescale {
                // Propogate time amongst views
                timelineView.time = time
                // Load static drawing
                if let d = annotations.staticDrawingAt(time: time) {
                    canvasView.finishedLines = d.lines
                    canvasView.frozenImage = d.fullImage
                    canvasView.setNeedsDisplay()
                }
            }
        }
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
            annotations.fullFrameSize = videoSize
            annotations.thumbnailSize = timelineView.displaySize
            annotations.screenScale = view.contentScaleFactor
            
            // FIXME
            let hackHeight = videoView.frame.width / videoSize.width * videoSize.height
            let hackY = (videoView.frame.height - hackHeight) / 2
            canvasView.frame = CGRect(x:0, y:hackY, width: videoView.frame.width, height: hackHeight)
            print(videoView.frame, canvasView.frame)
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
            if progress < 1.0 {
                let easedProgress = sin(progress*Double.pi/2.0)
                self.desiredTime = startTime + CMTime(
                    value: CMTimeValue(easedProgress*Double(timeDelta.value)),
                    timescale: timeDelta.timescale
                )
            }
            else {
                self.desiredTime = newTime
                timer.invalidate()
            }
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
