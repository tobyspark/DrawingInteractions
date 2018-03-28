//
//  Annotations.swift
//  DrawingInteractions
//
//  Created by Toby Harris on 26/03/2018.
//  Copyright © 2018 Toby Harris. All rights reserved.
//

import UIKit
import AVFoundation
import os.log

class Annotations {
    var staticDrawings:[CMTimeValue:[Line]] = [:]
    var dynamicDrawings:[CMTimeValue:[(line:Line, point:LinePoint)]] = [:] {
        didSet {
            print(dynamicDrawings)
        }
    }
}
