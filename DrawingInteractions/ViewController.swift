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
    
    let movie = ("testvideo", "mov")
    let stripHeight:CGFloat = 44
    
    var desiredTime = kCMTimeZero {
        didSet {
            time = CMTimeClampToRange(time, timeBounds)
            videoView.time = desiredTime
        }
    }
    
    var time = kCMTimeZero {
        didSet { timelineView.time = time }
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
        
        guard let movieURL = Bundle.main.url(forResource: movie.0, withExtension: movie.1) else {
            fatalError("Can't find \(movie)")
        }
        
        canvasView = CanvasView()
        canvasView.frame = view.frame
        canvasView.translatesAutoresizingMaskIntoConstraints = true
        canvasView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        canvasView.backgroundColor = .clear
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
