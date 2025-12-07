//
//  RailwayRoute.swift
//  railway-train-track
//
//  Created by Qiwei Li on 12/7/25.
//

import Foundation
import SwiftData
import CoreLocation

@Model
final class RailwayRoute {
    var id: UUID
    var osmWayId: Int64
    var startStationOsmId: Int64
    var endStationOsmId: Int64
    var coordinates: Data  // JSON-encoded [[lat, lon]]
    var fetchedAt: Date

    init(
        osmWayId: Int64,
        startStationOsmId: Int64,
        endStationOsmId: Int64,
        coordinates: [[Double]]
    ) {
        self.id = UUID()
        self.osmWayId = osmWayId
        self.startStationOsmId = startStationOsmId
        self.endStationOsmId = endStationOsmId
        self.coordinates = (try? JSONEncoder().encode(coordinates)) ?? Data()
        self.fetchedAt = Date()
    }

    var decodedCoordinates: [CLLocationCoordinate2D] {
        guard let coords = try? JSONDecoder().decode([[Double]].self, from: coordinates) else {
            return []
        }
        return coords.map { CLLocationCoordinate2D(latitude: $0[0], longitude: $0[1]) }
    }
}
