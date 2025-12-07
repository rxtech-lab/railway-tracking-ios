//
//  TrainStation.swift
//  railway-train-track
//
//  Created by Qiwei Li on 12/6/25.
//

import Foundation
import SwiftData
import CoreLocation

@Model
final class TrainStation {
    @Attribute(.unique) var osmId: Int64 // OpenStreetMap ID
    var name: String
    var latitude: Double
    var longitude: Double
    var stationType: String? // railway, subway, tram, etc.
    var operatorName: String? // Train operator name
    var lastFetched: Date

    @Relationship(inverse: \StationPassEvent.station)
    var passEvents: [StationPassEvent] = []

    init(
        osmId: Int64,
        name: String,
        latitude: Double,
        longitude: Double,
        stationType: String? = nil,
        operatorName: String? = nil
    ) {
        self.osmId = osmId
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
        self.stationType = stationType
        self.operatorName = operatorName
        self.lastFetched = Date()
    }

    // MARK: - Computed Properties

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var clLocation: CLLocation {
        CLLocation(latitude: latitude, longitude: longitude)
    }

    var formattedCoordinate: String {
        String(format: "%.4f, %.4f", latitude, longitude)
    }

    var displayType: String {
        stationType?.capitalized ?? "Station"
    }
}
