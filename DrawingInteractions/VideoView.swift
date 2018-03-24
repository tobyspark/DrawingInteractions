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
                    using: { d.time = $0 }
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
    
    // MARK: Overrides
    
    override static var layerClass: AnyClass {
        return AVPlayerLayer.self
    }
    
    // MARK: Private
    
    private var playerObserver: Any?
}
