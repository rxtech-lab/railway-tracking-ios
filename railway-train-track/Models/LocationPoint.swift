//
//  LocationPoint.swift
//  railway-train-track
//
//  Created by Qiwei Li on 12/6/25.
//

import Foundation
import SwiftData
import CoreLocation

@Model
final class LocationPoint {
    var id: UUID
    var timestamp: Date
    var latitude: Double
    var longitude: Double
    var altitude: Double // height/elevation in meters
    var horizontalAccuracy: Double
    var verticalAccuracy: Double
    var speed: Double // m/s
    var course: Double // degrees

    var session: TrackingSession?

    init(
        timestamp: Date = Date(),
        latitude: Double,
        longitude: Double,
        altitude: Double,
        horizontalAccuracy: Double = 0,
        verticalAccuracy: Double = 0,
        speed: Double = 0,
        course: Double = 0
    ) {
        self.id = UUID()
        self.timestamp = timestamp
        self.latitude = latitude
        self.longitude = longitude
        self.altitude = altitude
        self.horizontalAccuracy = horizontalAccuracy
        self.verticalAccuracy = verticalAccuracy
        self.speed = speed
        self.course = course
    }

    convenience init(from location: CLLocation) {
        self.init(
            timestamp: location.timestamp,
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            altitude: location.altitude,
            horizontalAccuracy: location.horizontalAccuracy,
            verticalAccuracy: location.verticalAccuracy,
            speed: max(0, location.speed), // speed can be -1 if invalid
            course: location.course >= 0 ? location.course : 0
        )
    }

    // MARK: - Computed Properties

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var clLocation: CLLocation {
        CLLocation(
            coordinate: coordinate,
            altitude: altitude,
            horizontalAccuracy: horizontalAccuracy,
            verticalAccuracy: verticalAccuracy,
            course: course,
            speed: speed,
            timestamp: timestamp
        )
    }

    var formattedCoordinate: String {
        String(format: "%.6f, %.6f", latitude, longitude)
    }

    var formattedAltitude: String {
        String(format: "%.1f m", altitude)
    }

    var formattedSpeed: String {
        let kmh = speed * 3.6
        return String(format: "%.1f km/h", kmh)
    }
}
