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

    var player: AVPlayer? {
        get {
            return playerLayer.player
        }
        set {
            playerLayer.player = newValue
        }
    }
    
    var playerLayer: AVPlayerLayer {
        return layer as! AVPlayerLayer
    }
    
    // Override UIView property
    override static var layerClass: AnyClass {
        return AVPlayerLayer.self
    }
    
    @IBAction func playPause(sender: UIGestureRecognizer) {
        if let p = player {
            p.rate = (p.rate != 0.0) ? 0.0 : 1.0
        }
    }

}
