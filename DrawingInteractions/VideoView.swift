//
//  VideoView.swift
//  DrawingInteractions
//
//  Created by Toby Harris on 23/03/2018.
//  Copyright © 2018 Toby Harris. All rights reserved.
//

import UIKit
import AVFoundation

class VideoView: UIView {
    
    // MARK: Properties
    
    var player: AVPlayer? {
        get {
            return playerLayer.player
        }
        set {
            playerLayer.player = newValue
            
            if let d = delegate {
                let interval = playerLayer.player?.currentItem?.asset.tracks(withMediaType: .video).first?.minFrameDuration
                let mainQueue = DispatchQueue.main
                playerObserver = playerLayer.player?.addPeriodicTimeObserver(
                    forInterval: interval!,
                    queue: mainQueue,
                    using: {
                        [weak self] time in
                        // The CMTime timescale changes when paused (!). This guards against updating with the erroneous values.
                        if self?.player?.rate != 0.0 {
                            d.time = time
                        }
                    }
                )
            }
        }
    }
    
    var playerLayer: AVPlayerLayer {
        return layer as! AVPlayerLayer
    }
    
    var delegate: VideoTimelineView?
    
    // MARK: Methods
    
    @IBAction func playPause(sender: UIGestureRecognizer) {
        if let p = player {
            p.rate = (p.rate != 0.0) ? 0.0 : 1.0
        }
    }
    
    // MARK: Methods
    
    func smoothSeek(to newChaseTime: CMTime) {
        player?.pause()
        if CMTimeCompare(newChaseTime, chaseTime) != 0 {
            chaseTime = newChaseTime
            if !isSeekInProgress {
                seekToChaseTime()
            }
        }
    }
    
    // MARK: Overrides
    
    override static var layerClass: AnyClass {
        return AVPlayerLayer.self
    }
    
    // MARK: Private
    
    private var playerObserver: Any?
    
    private var isSeekInProgress = false
    private var chaseTime = kCMTimeZero
    private func seekToChaseTime() {
        isSeekInProgress = true
        let seekTimeInProgress = chaseTime
        player?.seek(to: seekTimeInProgress, toleranceBefore: kCMTimeZero, toleranceAfter: kCMTimeZero, completionHandler: { [weak self] _ in
            if CMTimeCompare(seekTimeInProgress, self!.chaseTime) == 0 {
                self?.isSeekInProgress = false
            }
            else {
                self?.seekToChaseTime()
            }
        })
    }
}
