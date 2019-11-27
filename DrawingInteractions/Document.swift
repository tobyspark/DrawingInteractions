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

typealias StaticDrawingsType = [CMTimeValue:[Line]]
typealias DynamicDrawingsType = [CMTimeValue:[(line:Line, point:LinePoint)]]

typealias StaticDrawingsCodableType = [CMTimeValue:[LineCodable]]
typealias DynamicDrawingsCodableType = [CMTimeValue:[LinePointCodable]] // FIXME: Line here is meant to be a ref to the line, not a copy. So ignoring for now.

enum DocumentError: Error {
    case malformedPackage
}

class Document: UIDocument {
    var staticDrawings:StaticDrawingsType = [:]
    var dynamicDrawings:DynamicDrawingsType = [:]
    
    override func contents(forType typeName: String) throws -> Any {
        let staticDrawingsCodable = staticDrawings.mapValues { $0.map({ LineCodable(from: $0) }) }
        let staticDrawingsData = try JSONEncoder().encode(staticDrawingsCodable)
        let staticDrawingsWrapper = FileWrapper(regularFileWithContents: staticDrawingsData)
        
        let dynamicDrawingsCodable = dynamicDrawings.mapValues { $0.map({ LinePointCodable(from: $0.point) }) }
        let dynamicDrawingsData = try JSONEncoder().encode(dynamicDrawingsCodable)
        let dynamicDrawingsWrapper = FileWrapper(regularFileWithContents: dynamicDrawingsData)
        
        return FileWrapper(directoryWithFileWrappers: [
            Settings.filenameStaticDrawings: staticDrawingsWrapper,
            Settings.filenameDynamicDrawings: dynamicDrawingsWrapper
        ])
    }
    
    override func load(fromContents contents: Any, ofType typeName: String?) throws {
        guard
            let docWrapper = contents as? FileWrapper,
            let staticDrawingsData = docWrapper.fileWrappers?[Settings.filenameStaticDrawings]?.regularFileContents,
            let dynamicDrawingsData = docWrapper.fileWrappers?[Settings.filenameDynamicDrawings]?.regularFileContents
        else { throw DocumentError.malformedPackage }
        
        let staticDrawingsCodable = try JSONDecoder().decode(StaticDrawingsCodableType.self, from: staticDrawingsData)
        staticDrawings = staticDrawingsCodable.mapValues { $0.map({ $0.line() }) }
        
        let dynamicDrawingsCodable = try JSONDecoder().decode(DynamicDrawingsCodableType.self, from: dynamicDrawingsData)
        dynamicDrawings = dynamicDrawingsCodable.mapValues { $0.map({ (Line(), $0.linePoint()) }) }
    }
}

