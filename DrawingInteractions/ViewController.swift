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
    
    var timelineView: VideoTimelineView!
    var videoView: VideoView {
        return view as! VideoView
    }
    
    let stripHeight:CGFloat = 44
    
    override func viewDidLayoutSubviews() {
        timelineView.boundsDidChange()
    }

    // MARK: View Life Cycle

    override func viewDidLoad() {
        super.viewDidLoad()
        
        guard let movieURL = Bundle.main.url(forResource: "testvideo", withExtension: "mov") else {
            fatalError("Can't find testvideo")
        }
        
        let strip = CGRect(x: 0, y: 0, width: view.frame.width, height: stripHeight)
        timelineView = VideoTimelineView(frame: strip)
        timelineView.translatesAutoresizingMaskIntoConstraints = true
        timelineView.center = CGPoint(x: view.bounds.midX, y: view.bounds.midY)
        timelineView.autoresizingMask = [UIViewAutoresizing.flexibleWidth, UIViewAutoresizing.flexibleTopMargin, UIViewAutoresizing.flexibleBottomMargin]
        timelineView.delegate = videoView
        videoView.delegate = timelineView
        
        videoView.player = AVPlayer(url: movieURL)
        timelineView.asset = videoView.player!.currentItem!.asset

        view.addSubview(timelineView)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
}
