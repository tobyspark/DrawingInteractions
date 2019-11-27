//
//  LineCodable.swift
//  DrawingInteractions
//
//  Created by Toby Harris on 27/11/2019.
//  Copyright © 2019 Toby Harris. All rights reserved.
//

///  Codable intermediaries for the non-codable Line classes.
///
///  Obviously not what you'd do in a clean-sheet design, but IMHO cleaner to do this, than do the contortions to rework the NSObject derived classes themselves.
///  As a bonus, produces a compact representation.

import UIKit

struct LineCodable: Codable {
    let sequenceNumber: [Int]
    let timestamp: [TimeInterval]
    let force: [CGFloat]
    let x: [CGFloat]
    let y: [CGFloat]
    let altitudeAngle: [CGFloat]
    let azimuthAngle: [CGFloat]
    
    init(from line: Line) {
        var sequenceNumber: [Int] = []
        var timestamp: [TimeInterval] = []
        var force: [CGFloat] = []
        var x: [CGFloat] = []
        var y: [CGFloat] = []
        var altitudeAngle: [CGFloat] = []
        var azimuthAngle: [CGFloat] = []
        
        let count = line.points.count
        sequenceNumber.reserveCapacity(count)
        timestamp.reserveCapacity(count)
        force.reserveCapacity(count)
        x.reserveCapacity(count)
        y.reserveCapacity(count)
        altitudeAngle.reserveCapacity(count)
        azimuthAngle.reserveCapacity(count)
        
        for point in line.committedPoints {
            sequenceNumber.append(point.sequenceNumber)
            timestamp.append(point.timestamp)
            force.append(point.force)
            x.append(point.location.x)
            y.append(point.location.y)
            altitudeAngle.append(point.altitudeAngle)
            azimuthAngle.append(point.azimuthAngle)
        }
        
        self.sequenceNumber = sequenceNumber
        self.timestamp = timestamp
        self.force = force
        self.x = x
        self.y = y
        self.altitudeAngle = altitudeAngle
        self.azimuthAngle = azimuthAngle
    }
    
    func line() -> Line {
        var sequenceNumberIterator = sequenceNumber.makeIterator()
        var timestampIterator = timestamp.makeIterator()
        var forceIterator = force.makeIterator()
        var xIterator = x.makeIterator()
        var yIterator = y.makeIterator()
        var altitudeAngleIterator = altitudeAngle.makeIterator()
        var azimuthAngleIterator = azimuthAngle.makeIterator()
        
        var points: [LinePoint] = []
        points.reserveCapacity(sequenceNumber.count)
        
        while(true) {
            guard
                let sequenceNumber = sequenceNumberIterator.next(),
                let timestamp = timestampIterator.next(),
                let force = forceIterator.next(),
                let x = xIterator.next(),
                let y = yIterator.next(),
                let altitudeAngle = altitudeAngleIterator.next(),
                let azimuthAngle = azimuthAngleIterator.next()
            else {
                break
            }
            let point = LinePoint(sequenceNumber: sequenceNumber,
                                  timestamp: timestamp,
                                  force: force,
                                  x: x,
                                  y: y,
                                  altitudeAngle: altitudeAngle,
                                  azimuthAngle: azimuthAngle)
            points.append(point)
        }
        let line = Line()
        line.committedPoints = points
        return line
    }
}

struct LinePointCodable: Codable {
    let sequenceNumber: Int
    let timestamp: TimeInterval
    let force: CGFloat
    let x: CGFloat
    let y: CGFloat
    let altitudeAngle: CGFloat
    let azimuthAngle: CGFloat
    
    init(from linePoint: LinePoint) {
        sequenceNumber = linePoint.sequenceNumber
        timestamp = linePoint.timestamp
        force = linePoint.force
        x = linePoint.location.x
        y = linePoint.location.y
        altitudeAngle = linePoint.altitudeAngle
        azimuthAngle = linePoint.azimuthAngle
    }

    func linePoint() -> LinePoint {
        return LinePoint(sequenceNumber: sequenceNumber,
                         timestamp: timestamp,
                         force: force,
                         x: x,
                         y: y,
                         altitudeAngle: altitudeAngle,
                         azimuthAngle: azimuthAngle)
    }
}
