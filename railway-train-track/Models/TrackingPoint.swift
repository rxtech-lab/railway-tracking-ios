//
//  TrackingPoint.swift
//  railway-train-track
//
//  Created by Qiwei Li on 12/8/25.
//

import CoreLocation
import Foundation
import SwiftUI

/// Represents the type of a tracking point marker on the map
enum TrackingPointType: Equatable {
    case start
    case end
    case trainStation
    case waypoint

    var iconName: String {
        switch self {
        case .start: return "flag.fill"
        case .end: return "flag.checkered"
        case .trainStation: return "train.side.front.car"
        case .waypoint: return "mappin"
        }
    }

    var backgroundColor: Color {
        switch self {
        case .start: return .green
        case .end: return .red
        case .trainStation: return .orange
        case .waypoint: return .blue
        }
    }

    var iconColor: Color {
        .white
    }

    var markerSize: CGFloat {
        switch self {
        case .trainStation: return 24
        case .start, .end: return 20
        case .waypoint: return 16
        }
    }

    var iconSize: CGFloat {
        switch self {
        case .trainStation: return 12
        case .start, .end: return 10
        case .waypoint: return 8
        }
    }
}

/// A lightweight struct representing a point of interest on the map.
/// Used for both live tracking and playback scenarios.
struct TrackingPoint: Identifiable, Equatable {
    let id: UUID
    let title: String?
    let type: TrackingPointType
    let location: CLLocationCoordinate2D
    let timestamp: Date

    init(
        id: UUID = UUID(),
        title: String? = nil,
        type: TrackingPointType,
        location: CLLocationCoordinate2D,
        timestamp: Date
    ) {
        self.id = id
        self.title = title
        self.type = type
        self.location = location
        self.timestamp = timestamp
    }

    static func == (lhs: TrackingPoint, rhs: TrackingPoint) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Factory Methods

extension TrackingPoint {
    /// Create a TrackingPoint from a LocationPoint
    static func from(
        locationPoint: LocationPoint,
        type: TrackingPointType,
        title: String? = nil
    ) -> TrackingPoint {
        TrackingPoint(
            id: locationPoint.id,
            title: title,
            type: type,
            location: locationPoint.coordinate,
            timestamp: locationPoint.timestamp
        )
    }

    /// Create a TrackingPoint from a TrainStation
    static func from(station: TrainStation, timestamp: Date, eventId: UUID) -> TrackingPoint {
        TrackingPoint(
            id: eventId,
            title: station.name,
            type: .trainStation,
            location: station.coordinate,
            timestamp: timestamp
        )
    }

    /// Create a start marker from a LocationPoint
    static func startMarker(from point: LocationPoint) -> TrackingPoint {
        TrackingPoint(
            id: point.id,
            title: "Start",
            type: .start,
            location: point.coordinate,
            timestamp: point.timestamp
        )
    }

    /// Create an end marker from a LocationPoint
    static func endMarker(from point: LocationPoint, showTitle: Bool = true) -> TrackingPoint {
        TrackingPoint(
            id: point.id,
            title: showTitle ? "End" : nil,
            type: .end,
            location: point.coordinate,
            timestamp: point.timestamp
        )
    }
}
