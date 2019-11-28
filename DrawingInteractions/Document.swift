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
    case movieURLStale
    case movieURLNotSet
}

class Document: UIDocument {
    var staticDrawings:StaticDrawingsType = [:] { didSet { updateChangeCount(.done) }}
    var dynamicDrawings:DynamicDrawingsType = [:] { didSet { updateChangeCount(.done) }}
    var movieURL: URL? { didSet { updateChangeCount(.done) }}
    
    override func contents(forType typeName: String) throws -> Any {
        guard let movieURL = movieURL else {
            throw DocumentError.movieURLNotSet
        }
        let staticDrawingsCodable = staticDrawings.mapValues { $0.map({ LineCodable(from: $0) }) }
        let staticDrawingsData = try JSONEncoder().encode(staticDrawingsCodable)
        let staticDrawingsWrapper = FileWrapper(regularFileWithContents: staticDrawingsData)
        
        let dynamicDrawingsCodable = dynamicDrawings.mapValues { $0.map({ LinePointCodable(from: $0.point) }) }
        let dynamicDrawingsData = try JSONEncoder().encode(dynamicDrawingsCodable)
        let dynamicDrawingsWrapper = FileWrapper(regularFileWithContents: dynamicDrawingsData)
        
        let movieURLData = try movieURL.bookmarkData()
        let movieURLWrapper = FileWrapper(regularFileWithContents: movieURLData)
        
        return FileWrapper(directoryWithFileWrappers: [
            Settings.filenameStaticDrawings: staticDrawingsWrapper,
            Settings.filenameDynamicDrawings: dynamicDrawingsWrapper,
            Settings.filenameMovie: movieURLWrapper
        ])
    }
    
    override func load(fromContents contents: Any, ofType typeName: String?) throws {
        // workaround for import
        guard let docWrapper = contents as? FileWrapper else {
            print("Couldn't load - not a wrapper")
            return
        }
        
        guard
//            let docWrapper = contents as? FileWrapper,
            let staticDrawingsData = docWrapper.fileWrappers?[Settings.filenameStaticDrawings]?.regularFileContents,
            let dynamicDrawingsData = docWrapper.fileWrappers?[Settings.filenameDynamicDrawings]?.regularFileContents,
            let movieURLData = docWrapper.fileWrappers?[Settings.filenameMovie]?.regularFileContents
        else {
            throw DocumentError.malformedPackage
        }
        
        let staticDrawingsCodable = try JSONDecoder().decode(StaticDrawingsCodableType.self, from: staticDrawingsData)
        staticDrawings = staticDrawingsCodable.mapValues { $0.map({ $0.line() }) }
        
        let dynamicDrawingsCodable = try JSONDecoder().decode(DynamicDrawingsCodableType.self, from: dynamicDrawingsData)
        dynamicDrawings = dynamicDrawingsCodable.mapValues { $0.map({ (Line(), $0.linePoint()) }) }
        
        var isStale = false
        self.movieURL = try URL(resolvingBookmarkData: movieURLData, bookmarkDataIsStale: &isStale)
        if isStale { throw DocumentError.movieURLStale }
    }
}

