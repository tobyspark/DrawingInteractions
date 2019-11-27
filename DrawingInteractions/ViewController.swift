//
//  ViewController.swift
//  DrawingInteractions
//
//  Created by Toby Harris on 23/03/2018.
//  Copyright © 2018 Toby Harris. All rights reserved.
//

import UIKit
import AVFoundation

/// The view controller for the main drawing-on-video view.
///
/// A `VideoView` displays the video and is the source for time, i.e. the video's current time, throughout the app. A subview `VideoTimelineView` displays a timeline scrubber, with input handling. Another subview provides the drawing canvas, with input handling. This controller marshalls the current time around the application, handling the storage and retrieval of drawing annotations per time change.

protocol TimeProtocol: AnyObject {
    var time: CMTime { get set }
    var desiredTime: CMTime { get set }
    var rate: (rate:Float, isPaused: Bool) { get set }
    func scrub(to newTime:CMTime, withDuration duration:TimeInterval)
}

protocol AnnotationProtocol: AnyObject {
    var annotations: Annotations { get set }
    func linesDidUpdate()
}

class ViewController: UIViewController, TimeProtocol, AnnotationProtocol {
    
    // MARK: Properties
    
    let movie = (name:"testvideo", ext:"mov")
    let stripHeight:CGFloat = 44
    
    /// The annotations, i.e. drawings.
    var annotations = Annotations()
    
    /// The video playback rate.
    ///
    /// Use of `isPaused` allows the rate to be resumed upon unpause.
    var rate: (rate:Float, isPaused: Bool) = (1.0, false) {
        didSet {
            videoView.player?.rate = rate.isPaused ? 0.0 : rate.rate
        }
    }
    
    // The time any component wants the app (i.e. video) to be at
    var desiredTime = CMTime.zero {
        didSet {
            time = CMTimeClampToRange(time, range: timeBounds)
            videoView.time = desiredTime
        }
    }
    
    /// The actual time, driven by the video playback
    ///
    /// Note multiple identical times can be received under some conditions.
    /// Firstrun hack exploits time on init has timescale of 1.
    var time = CMTime.zero {
        willSet {
            if time != newValue || time.timescale == CMTime.zero.timescale {
                // Dynamic Drawings - Line still active across frames
                if canvasView.lines.count > 0 {
                    let info = (canvasView.lines.first!, canvasView.lines.first!.points.last!)
                    if annotations.dynamicDrawings.index(forKey: time.value) == nil {
                        annotations.dynamicDrawings[time.value] = [info]
                    }
                    else {
                        annotations.dynamicDrawings[time.value]!.append(info)
                    }
                }
                if canvasView.focusPoints.count > 0 {
                    canvasView.focusPoints.removeAll()
                    canvasView.needsFullRedraw = true
                    canvasView.setNeedsDisplay()
                }
                // Static Drawings - Lines completed within frame
                if canvasView.finishedLines.count > 0 {
                    canvasView.finishedLines.removeAll()
                    canvasView.needsFullRedraw = true
                    canvasView.setNeedsDisplay()
                }
            }
        }
        didSet {
            if time != oldValue || oldValue.timescale == CMTime.zero.timescale {
                // Propogate time amongst views
                timelineView.time = time
                // Load static drawing
                if let lines = annotations.staticDrawings[time.value] {
                    canvasView.finishedLines = lines
                    canvasView.needsFullRedraw = true
                    canvasView.setNeedsDisplay()
                }
                // Load dynamic drawing, aka focus points
                let timeSpan = CMTimeValue(time.timescale) / 2 // i.e. 1 second total span
                let spread = annotations.dynamicDrawings.filter { $0.key > time.value - timeSpan && $0.key < time.value + timeSpan }
                for (instantTime, info) in spread {
                    let focusAmount = 1.0 - CGFloat(abs(instantTime - time.value)) / CGFloat(timeSpan)
                    canvasView.focusPoints.append((amount: focusAmount, points: info.map { $0.point.preciseLocation }))
                }
            }
        }
    }
    
    var timeBounds = CMTimeRange.zero
    var videoSize = CGSize()
    
    var timelineView: VideoTimelineView!
    var canvasView: NotifyingCanvasView!
    var videoView: VideoView {
        return view as! VideoView
    }
    
    /// Marshall updates to the current drawing data around the app
    func linesDidUpdate() {
        if canvasView.finishedLines.count > 0 {
            annotations.staticDrawings[time.value] = canvasView.finishedLines
            timelineView.drawingsDidChange()
        }
    }
    
    /// Set the video to play
    ///
    /// - ToDo: Ensure everything is (re-)initialised from the video, here.
    func setVideo(_ movieURL:URL) {
        let player = AVPlayer(url: movieURL)
        if let track = player.currentItem!.asset.tracks(withMediaType: .video).first {
            timeBounds = track.timeRange
            videoSize = track.naturalSize
            timelineView.setVideoTrack(track)
            videoView.player = player
            time = track.timeRange.start
            rate = (rate: 1.0, isPaused: false)
        }
    }
    
    /// Animate time property to a new value, over a duration. In video-speak, "to scrub"
    ///
    /// - parameter newTime: the new time to animate to.
    /// - parameter duration: the time over which to animate.
    ///
    /// Note: ideally, there would be a CAAnimation-like way of animating the `time` property.
    /// Without, this is DIY ugliness.
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
    
    /// Only send stylus touch events to the drawing canvas.
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
    
    /// Only send stylus touch events to the drawing canvas.
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
    
    /// Only send stylus touch events to the drawing canvas.
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
    
    /// Only send stylus touch events to the drawing canvas.
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
    
    /// Only send stylus touch events to the drawing canvas.
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
        
        canvasView = NotifyingCanvasView()
        canvasView.frame = view.frame
        canvasView.translatesAutoresizingMaskIntoConstraints = true
        canvasView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        canvasView.backgroundColor = .clear
        canvasView.usePreciseLocations = true
        canvasView.delegate = self
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
        
        // FIXME: Handle screen rotation for drawings. Non-trivial!
        // - Line points are in coordinate system of screen at particular orientation
        // - frozen context is currently orientation specific
        // - idea of 'light table' of videos will require mapping screen coords to video coords
        print("Video rect now: ", videoView.playerLayer.videoRect)
        canvasView.transform = CGAffineTransform(translationX: 0, y: videoView.playerLayer.videoRect.origin.y)
    }
}
