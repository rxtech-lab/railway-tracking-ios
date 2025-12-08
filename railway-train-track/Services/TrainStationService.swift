//
//  TrainStationService.swift
//  railway-train-track
//
//  Created by Qiwei Li on 12/6/25.
//

import Foundation
import CoreLocation

final class TrainStationService {
    private let baseURL = "https://overpass-api.de/api/interpreter"
    private let session = URLSession.shared

    struct OverpassResponse: Decodable {
        let elements: [OverpassElement]
    }

    struct OverpassElement: Decodable {
        let type: String
        let id: Int64
        let lat: Double?
        let lon: Double?
        let center: OverpassCenter?
        let tags: [String: String]?

        struct OverpassCenter: Decodable {
            let lat: Double
            let lon: Double
        }

        var latitude: Double? {
            lat ?? center?.lat
        }

        var longitude: Double? {
            lon ?? center?.lon
        }
    }

    /// Fetches train stations along a route
    func fetchStationsAlongRoute(
        coordinates: [CLLocationCoordinate2D],
        radiusMeters: Double = 500
    ) async throws -> [TrainStation] {
        guard !coordinates.isEmpty else { return [] }

        // Create bounding box with buffer
        guard let boundingBox = calculateBoundingBox(coordinates: coordinates, buffer: radiusMeters) else {
            return []
        }

        let query = """
        [out:json][timeout:30];
        (
          node["railway"="station"](\(boundingBox));
          node["railway"="halt"](\(boundingBox));
          node["public_transport"="station"]["train"="yes"](\(boundingBox));
          way["railway"="station"](\(boundingBox));
        );
        out center;
        """

        guard let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "\(baseURL)?data=\(encodedQuery)") else {
            throw URLError(.badURL)
        }

        let (data, response) = try await session.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }

        let overpassResponse = try JSONDecoder().decode(OverpassResponse.self, from: data)

        let stations = overpassResponse.elements.compactMap { element -> TrainStation? in
            guard let lat = element.latitude,
                  let lon = element.longitude,
                  let name = element.tags?["name"] else {
                return nil
            }

            return TrainStation(
                osmId: element.id,
                name: name,
                latitude: lat,
                longitude: lon,
                stationType: element.tags?["railway"] ?? element.tags?["station"],
                operatorName: element.tags?["operator"]
            )
        }

        // Deduplicate stations by name (large stations have multiple OSM nodes)
        // Keep one station per unique name
        var uniqueStations: [String: TrainStation] = [:]
        for station in stations {
            if uniqueStations[station.name] == nil {
                uniqueStations[station.name] = station
            }
        }

        return Array(uniqueStations.values)
    }

    /// Deduplicates stations by name, keeping only one station per unique name.
    /// This is useful because large stations have multiple OSM nodes (platforms, entrances).
    static func deduplicateByName(_ stations: [TrainStation]) -> [TrainStation] {
        var uniqueStations: [String: TrainStation] = [:]
        for station in stations {
            if uniqueStations[station.name] == nil {
                uniqueStations[station.name] = station
            }
        }
        return Array(uniqueStations.values)
    }

    private func calculateBoundingBox(
        coordinates: [CLLocationCoordinate2D],
        buffer: Double
    ) -> String? {
        guard !coordinates.isEmpty else { return nil }

        var minLat = coordinates[0].latitude
        var maxLat = coordinates[0].latitude
        var minLon = coordinates[0].longitude
        var maxLon = coordinates[0].longitude

        for coord in coordinates {
            minLat = min(minLat, coord.latitude)
            maxLat = max(maxLat, coord.latitude)
            minLon = min(minLon, coord.longitude)
            maxLon = max(maxLon, coord.longitude)
        }

        // Add buffer (approximate degrees for meters)
        let latBuffer = buffer / 111000.0 // ~111km per degree latitude
        let lonBuffer = buffer / (111000.0 * cos(minLat * .pi / 180))

        return "\(minLat - latBuffer),\(minLon - lonBuffer),\(maxLat + latBuffer),\(maxLon + lonBuffer)"
    }
}
