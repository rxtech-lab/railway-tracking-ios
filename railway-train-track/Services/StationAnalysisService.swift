//
//  StationAnalysisService.swift
//  railway-train-track
//
//  Created by Qiwei Li on 12/6/25.
//

import Foundation
import CoreLocation

final class StationAnalysisService {

    /// Detects when the user passed by train stations
    func detectStationPasses(
        locationPoints: [LocationPoint],
        stations: [TrainStation],
        proximityThreshold: Double = 200 // meters
    ) -> [StationPassEvent] {
        var passEvents: [StationPassEvent] = []

        for station in stations {
            var entryIndex: Int?
            var closestDistance: Double = .infinity
            var closestTime: Date?

            for (index, point) in locationPoints.enumerated() {
                let distance = point.clLocation.distance(from: station.clLocation)

                if distance <= proximityThreshold {
                    // Within proximity
                    if entryIndex == nil {
                        entryIndex = index
                    }
                    if distance < closestDistance {
                        closestDistance = distance
                        closestTime = point.timestamp
                    }
                } else if let entry = entryIndex {
                    // Exited proximity
                    if let time = closestTime {
                        let event = StationPassEvent(
                            timestamp: time,
                            distanceFromStation: closestDistance,
                            entryPointIndex: entry,
                            exitPointIndex: index
                        )
                        event.station = station
                        passEvents.append(event)
                    }

                    // Reset for potential re-entry
                    entryIndex = nil
                    closestDistance = .infinity
                    closestTime = nil
                }
            }

            // Handle case where route ends within proximity
            if let entry = entryIndex, let time = closestTime {
                let event = StationPassEvent(
                    timestamp: time,
                    distanceFromStation: closestDistance,
                    entryPointIndex: entry,
                    exitPointIndex: locationPoints.count - 1
                )
                event.station = station
                passEvents.append(event)
            }
        }

        // Sort by timestamp
        return passEvents.sorted { $0.timestamp < $1.timestamp }
    }
}
