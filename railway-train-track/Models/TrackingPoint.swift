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
    case note

    var iconName: String {
        switch self {
        case .start: return "flag.fill"
        case .end: return "flag.checkered"
        case .trainStation: return "train.side.front.car"
        case .waypoint: return "mappin"
        case .note: return "note.text"
        }
    }

    var backgroundColor: Color {
        switch self {
        case .start: return .green
        case .end: return .red
        case .trainStation: return .orange
        case .waypoint: return .blue
        case .note: return .purple
        }
    }

    var iconColor: Color {
        .white
    }

    var markerSize: CGFloat {
        switch self {
        case .trainStation: return 24
        case .start, .end: return 20
        case .waypoint, .note: return 16
        }
    }

    var iconSize: CGFloat {
        switch self {
        case .trainStation: return 12
        case .start, .end: return 10
        case .waypoint, .note: return 8
        }
    }

    var selectedMarkerSize: CGFloat {
        switch self {
        case .trainStation: return 36
        case .start, .end: return 28
        case .waypoint, .note: return 22
        }
    }

    var selectedIconSize: CGFloat {
        switch self {
        case .trainStation: return 18
        case .start, .end: return 14
        case .waypoint, .note: return 11
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
    var isSelected: Bool

    init(
        id: UUID = UUID(),
        title: String? = nil,
        type: TrackingPointType,
        location: CLLocationCoordinate2D,
        timestamp: Date,
        isSelected: Bool = false
    ) {
        self.id = id
        self.title = title
        self.type = type
        self.location = location
        self.timestamp = timestamp
        self.isSelected = isSelected
    }

    static func == (lhs: TrackingPoint, rhs: TrackingPoint) -> Bool {
        lhs.id == rhs.id && lhs.isSelected == rhs.isSelected
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

    /// Create a TrackingPoint from a SessionNote
    static func from(note: SessionNote) -> TrackingPoint {
        TrackingPoint(
            id: note.id,
            title: note.previewText,
            type: .note,
            location: note.coordinate,
            timestamp: note.timestamp
        )
    }
}
