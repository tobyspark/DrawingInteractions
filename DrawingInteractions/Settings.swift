//
//  Settings.swift
//  DrawingInteractions
//
//  Created by Toby Harris on 27/11/2019.
//  Copyright © 2019 Toby Harris. All rights reserved.
//

import UIKit

struct Settings {
    static let filenameDocument = "document.drawinginteractions"
    static let filenameStaticDrawings = "staticDrawings.json"
    static let filenameDynamicDrawings = "dynamicDrawings.json"
    static let documentType = "net.sparklive.drawinginteractions.archive"
    
    static func urlCacheDoc() throws -> URL {
        return try FileManager.default
            .url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent(filenameDocument)
    }
}
