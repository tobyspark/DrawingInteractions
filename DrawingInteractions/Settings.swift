//
//  Settings.swift
//  DrawingInteractions
//
//  Created by Toby Harris on 27/11/2019.
//  Copyright © 2019 Toby Harris. All rights reserved.
//

import UIKit

struct Settings {
    static let filenameStaticDrawings = "staticDrawings.json"
    static let filenameDynamicDrawings = "dynamicDrawings.json"
    static let filenameMovie = "video"
    static let documentType = "net.sparklive.drawinginteractions.archive"
    static let documentExtension = "drawinginteractions"
    
    static let stripHeight:CGFloat = 44
    
    static func filenameDocument(_ name: String = "document") -> String {
        "\(name) \(dateFormatter.string(from: Date())).\(documentExtension)"
    }
    
    static func urlCacheDoc() throws -> URL {
        try FileManager.default
            .url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent(filenameDocument())
    }
    
    static private let dateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd HH-mm-ss"
        return df
    }()
}
