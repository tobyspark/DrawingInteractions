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
    
    var time: CMTime {
        get {
            return player?.currentTime() ?? kCMTimeZero
        }
        set {
            // Smooth seek
            if let p = player {
                if (!isSeekInProgress) {
                    rateBeforeSeek = p.rate
                    p.rate = 0.0
                }
                if CMTimeCompare(newValue, chaseTime) != 0 {
                    chaseTime = newValue
                    if !isSeekInProgress {
                        seekToChaseTime()
                    }
                }
            }
        }
    }
    
    var player: AVPlayer? {
        get {
            return playerLayer.player
        }
        set {
            playerLayer.player = newValue
            
            if let d = delegate, let videoTrack = playerLayer.player?.currentItem?.asset.tracks(withMediaType: .video).first {
                let timescale = videoTrack.naturalTimeScale
                let interval = videoTrack.minFrameDuration
                let mainQueue = DispatchQueue.main
                playerObserver = playerLayer.player?.addPeriodicTimeObserver(
                    forInterval: interval,
                    queue: mainQueue,
                    using: { d.time = CMTimeConvertScale($0, timescale, .roundHalfAwayFromZero) } // Emit a constant timescale, for sanity elsewhere
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
        print("tap videoview")
        if let p = player {
            p.rate = (p.rate != 0.0) ? 0.0 : 1.0
        }
    }
    
    // MARK: Overrides
    
    override static var layerClass: AnyClass {
        return AVPlayerLayer.self
    }
    
    // MARK: Private
    
    private var playerObserver: Any?
    
    private var isSeekInProgress = false
    private var rateBeforeSeek:Float = 0.0
    private var chaseTime = kCMTimeZero
    private func seekToChaseTime() {
        isSeekInProgress = true
        let seekTimeInProgress = chaseTime
        player?.seek(to: seekTimeInProgress, toleranceBefore: kCMTimeZero, toleranceAfter: kCMTimeZero, completionHandler: { [weak self] _ in
            if CMTimeCompare(seekTimeInProgress, self!.chaseTime) == 0 {
                self?.player?.rate = self!.rateBeforeSeek
                self?.isSeekInProgress = false
            }
            else {
                self?.seekToChaseTime()
            }
        })
    }
}
