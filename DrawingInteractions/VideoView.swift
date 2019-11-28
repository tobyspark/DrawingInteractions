//
//  VideoView.swift
//  DrawingInteractions
//
//  Created by Toby Harris on 23/03/2018.
//  Copyright © 2018 Toby Harris. All rights reserved.
//

import UIKit
import AVFoundation

/// Displays a video.
/// - When time is set, will seek smoothly; only seeking to a new time once a seek has finished.
/// - Will set `time` property on a delegate as video plays.
class VideoView: UIView {
    
    // MARK: Properties
    
    var time: CMTime {
        get {
            return player?.currentTime() ?? CMTime.zero
        }
        set {
            // Smooth seek
            if let p = player {
                if (!isSeekInProgress) {
                    p.rate = 0.0
                }
                if CMTimeCompare(newValue, desiredTime) != 0 {
                    desiredTime = newValue
                    if !isSeekInProgress {
                        seekToDesiredTime()
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
            
            guard
                let delegate = delegate,
                let videoTrack = playerLayer.player?.currentItem?.asset.tracks(withMediaType: .video).first
            else {
                return
            }
            let timescale = videoTrack.naturalTimeScale
            let interval = videoTrack.minFrameDuration
            let mainQueue = DispatchQueue.main
            playerObserver = playerLayer.player?.addPeriodicTimeObserver(
                forInterval: interval,
                queue: mainQueue,
                using: { [weak delegate] in
                    if let delegate = delegate {
                        // Emit a constant timescale, for sanity elsewhere
                        delegate.time = CMTimeConvertScale($0, timescale: timescale, method: .roundHalfAwayFromZero)
                    }
                }
            )
        }
    }
    
    var playerLayer: AVPlayerLayer {
        return layer as! AVPlayerLayer
    }
    
    weak var delegate: TimeProtocol?
    
    // MARK: Overrides
    
    override static var layerClass: AnyClass {
        return AVPlayerLayer.self
    }
    
    // MARK: Private
    
    private var playerObserver: Any?
    
    private var isSeekInProgress = false
    var desiredTime = CMTime.zero
    private func seekToDesiredTime() {
        isSeekInProgress = true
        let seekTimeInProgress = desiredTime
        player?.seek(to: seekTimeInProgress, toleranceBefore: CMTime.zero, toleranceAfter: CMTime.zero, completionHandler: { [weak self] _ in
            guard let s = self, let d = s.delegate else { return }
            if CMTimeCompare(seekTimeInProgress, s.desiredTime) == 0 {
                s.player?.rate = d.rate.isPaused ? 0.0 : d.rate.rate
                s.isSeekInProgress = false
            }
            else {
                s.seekToDesiredTime()
            }
        })
    }
}
