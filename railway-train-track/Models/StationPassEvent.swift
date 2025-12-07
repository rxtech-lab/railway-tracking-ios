//
//  StationPassEvent.swift
//  railway-train-track
//
//  Created by Qiwei Li on 12/6/25.
//

import Foundation
import SwiftData

@Model
final class StationPassEvent: Identifiable {
    var id: UUID
    var timestamp: Date // When passed the station (closest point)
    var distanceFromStation: Double // meters (closest distance)
    var entryPointIndex: Int // Index in locationPoints when entered proximity
    var exitPointIndex: Int? // Index when exited proximity
    var displayOrder: Int = 0 // For manual ordering within a journey

    var session: TrackingSession?
    var station: TrainStation?

    init(
        timestamp: Date,
        distanceFromStation: Double,
        entryPointIndex: Int,
        exitPointIndex: Int? = nil,
        displayOrder: Int = 0
    ) {
        self.id = UUID()
        self.timestamp = timestamp
        self.distanceFromStation = distanceFromStation
        self.entryPointIndex = entryPointIndex
        self.exitPointIndex = exitPointIndex
        self.displayOrder = displayOrder
    }

    // MARK: - Computed Properties

    var formattedDistance: String {
        String(format: "%.0f m", distanceFromStation)
    }

    var formattedTime: String {
        timestamp.formatted(date: .omitted, time: .standard)
    }

    var stationName: String {
        station?.name ?? "Unknown Station"
    }
}
