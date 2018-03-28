//
//  NotifyingCanvasView.swift
//  DrawingInteractions
//
//  Created by Toby Harris on 28/03/2018.
//  Copyright © 2018 Toby Harris. All rights reserved.
//

class NotifyingCanvasView: CanvasView {
    
    override var finishedLines: [Line] {
        get { return super.finishedLines }
        set {
            super.finishedLines = newValue
            delegate?.linesDidUpdate()
        }
    }
    
    var delegate: ViewController?
}
