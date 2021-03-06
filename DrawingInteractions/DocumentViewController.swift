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

/// For delegates that affect video playback
protocol TimeProtocol: AnyObject {
    var time: CMTime { get set }
    var desiredTime: CMTime { get set }
    var rate: (rate:Float, isPaused: Bool) { get set }
    func scrub(to newTime:CMTime, withDuration duration:TimeInterval)
}

/// For delegates that affect document state
protocol DocumentProtocol: AnyObject {
    var document: Document! { get }
    func linesDidUpdate()
}

class DocumentViewController: UIViewController, TimeProtocol, DocumentProtocol {
    
    // MARK: Properties
        
    /// The annotations, i.e. drawings.
    var document: Document!
    
    /// The video playback rate.
    ///
    /// Use of `isPaused` allows the rate to be resumed upon unpause.
    var rate: (rate:Float, isPaused: Bool) = (1.0, false) {
        didSet {
            videoView.player?.rate = rate.isPaused ? 0.0 : rate.rate
        }
    }
    
    /// The time any component wants the app (i.e. video) to be at
    // TODO: There is also scrubTo:, should there be both?
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
                    if document.dynamicDrawings.index(forKey: time.value) == nil {
                        document.dynamicDrawings[time.value] = [info]
                    }
                    else {
                        document.dynamicDrawings[time.value]!.append(info)
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
                if let lines = document.staticDrawings[time.value] {
                    canvasView.finishedLines = lines
                    canvasView.needsFullRedraw = true
                    canvasView.setNeedsDisplay()
                }
                // Load dynamic drawing, aka focus points
                let timeSpan = CMTimeValue(time.timescale) / 2 // i.e. 1 second total span
                let spread = document.dynamicDrawings.filter { $0.key > time.value - timeSpan && $0.key < time.value + timeSpan }
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
    var videoView: VideoView!
    
    /// Marshall updates to the current drawing data around the app
    func linesDidUpdate() {
        if canvasView.finishedLines.count > 0 {
            document.staticDrawings[time.value] = canvasView.finishedLines
            timelineView.drawingsDidChange()
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
                
        videoView = VideoView(frame: view.bounds)
        videoView.translatesAutoresizingMaskIntoConstraints = true
        videoView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        videoView.delegate = self
        view.addSubview(videoView)
        
        canvasView = NotifyingCanvasView(frame: view.bounds)
        canvasView.translatesAutoresizingMaskIntoConstraints = true
        canvasView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        canvasView.backgroundColor = .clear
        canvasView.usePreciseLocations = true
        canvasView.delegate = self
        view.addSubview(canvasView)
        
        let strip = CGRect(x: 0, y: 0, width: view.frame.width, height: Settings.stripHeight)
        timelineView = VideoTimelineView(frame: strip)
        timelineView.translatesAutoresizingMaskIntoConstraints = true
        timelineView.center = CGPoint(x: view.bounds.midX, y: view.bounds.midY)
        timelineView.autoresizingMask = [.flexibleWidth, .flexibleTopMargin, .flexibleBottomMargin]
        timelineView.delegate = self
        view.addSubview(timelineView)
                
        let button = UIButton(type: .system)
        button.setTitle("Close", for: .normal)
        button.frame = CGRect(x: 20, y: (Settings.stripHeight - 30)/2, width: 60, height: 30)
        button.layer.cornerRadius = button.bounds.size.height/2
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = UIColor(white: 0, alpha: 0.5)
        button.addTarget(self, action: #selector(dismissDocumentViewController), for: .touchUpInside)
        timelineView.addSubview(button)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // Access the document
        document.open(completionHandler: { (openSuccess) in
            guard
                openSuccess,
                let movieURL = self.document.movieURL
            else {
                let alertController = UIAlertController(title: "Cannot open document", message: "Could not parse URL", preferredStyle: .alert)
                self.present(alertController, animated: true, completion: nil)
                self.dismissDocumentViewController()
                return
            }
            
            let player = AVPlayer(url: movieURL)
            guard let track = player.currentItem?.asset.tracks(withMediaType: .video).first else {
                let alertController = UIAlertController(title: "Cannot open document", message: "Could not parse video", preferredStyle: .alert)
                self.present(alertController, animated: true, completion: nil)
                self.dismissDocumentViewController()
                return
            }

            /// Load the video and parse what's needed
            self.timeBounds = track.timeRange
            self.videoSize = track.naturalSize
            self.timelineView.setVideoTrack(track)
            self.videoView.player = player
            self.time = track.timeRange.start
            self.rate = (rate: 1.0, isPaused: false)
        })
    }

    @objc func dismissDocumentViewController() {
        dismiss(animated: true) {
            self.document.close(completionHandler: nil)
        }
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
