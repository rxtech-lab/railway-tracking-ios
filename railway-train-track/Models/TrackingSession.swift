//
//  TrackingSession.swift
//  railway-train-track
//
//  Created by Qiwei Li on 12/6/25.
//

import Foundation
import SwiftData
import CoreLocation

@Model
final class TrackingSession {
    var id: UUID
    var name: String
    var startTime: Date
    var endTime: Date?
    var recordingInterval: Double // seconds between recordings (default: 1.0)
    var isActive: Bool

    // Cached analysis results
    var stationAnalysisCompleted: Bool = false
    var stationAnalysisTimestamp: Date?

    // Cached stats
    var totalDistance: Double? // meters
    var averageSpeed: Double? // m/s

    // Playback settings
    var playbackDuration: Double = 30.0 // seconds for playback animation

    @Relationship(deleteRule: .cascade, inverse: \LocationPoint.session)
    var locationPoints: [LocationPoint] = []

    @Relationship(deleteRule: .cascade, inverse: \StationPassEvent.session)
    var stationPassEvents: [StationPassEvent] = []

    init(
        name: String = "",
        startTime: Date = Date(),
        recordingInterval: Double = 1.0
    ) {
        self.id = UUID()
        self.name = name.isEmpty ? "Session \(startTime.formatted(date: .abbreviated, time: .shortened))" : name
        self.startTime = startTime
        self.recordingInterval = recordingInterval
        self.isActive = true
    }

    // MARK: - Computed Properties

    var duration: TimeInterval {
        (endTime ?? Date()).timeIntervalSince(startTime)
    }

    var sortedLocationPoints: [LocationPoint] {
        locationPoints.sorted { $0.timestamp < $1.timestamp }
    }

    var coordinates: [CLLocationCoordinate2D] {
        sortedLocationPoints.map { $0.coordinate }
    }

    var formattedDuration: String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: duration) ?? "0s"
    }

    var formattedDistance: String {
        guard let distance = totalDistance else { return "-- m" }
        if distance >= 1000 {
            return String(format: "%.2f km", distance / 1000)
        }
        return String(format: "%.0f m", distance)
    }
}
