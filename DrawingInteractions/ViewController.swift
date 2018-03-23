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
    
    var videoView: VideoView {
        return view as! VideoView
    }
    
    let stripHeight:CGFloat = 44

    // MARK: View Life Cycle

    override func viewDidLoad() {
        super.viewDidLoad()
        
        guard let movieURL = Bundle.main.url(forResource: "testvideo", withExtension: "mov") else {
            fatalError("Can't find testvideo")
        }
        
        let strip = CGRect(
            x: view.frame.origin.x,
            y: view.frame.origin.y + (view.frame.height - stripHeight)/2.0,
            width: view.frame.width,
            height: stripHeight
            )
        let timelineView = VideoTimelineView(frame: strip)
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
