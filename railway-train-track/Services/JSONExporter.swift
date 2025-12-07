//
//  JSONExporter.swift
//  railway-train-track
//
//  Created by Qiwei Li on 12/6/25.
//

import Foundation

final class JSONExporter {

    struct LocationExport: Codable {
        let sessionId: String
        let sessionName: String
        let startTime: String
        let endTime: String?
        let totalDistance: Double?
        let averageSpeed: Double?
        let locations: [LocationData]

        struct LocationData: Codable {
            let timestamp: String
            let latitude: Double
            let longitude: Double
            let altitude: Double
            let speed: Double
            let course: Double
            let horizontalAccuracy: Double
            let verticalAccuracy: Double
        }
    }

    struct StationExport: Codable {
        let sessionId: String
        let sessionName: String
        let stations: [StationData]

        struct StationData: Codable {
            let stationName: String
            let stationLatitude: Double
            let stationLongitude: Double
            let stationType: String?
            let operatorName: String?
            let passedAt: String
            let distanceFromStation: Double
        }
    }

    func exportLocations(
        session: TrackingSession,
        filename: String,
        progress: @escaping (Double) -> Void
    ) async throws -> URL {
        let points = session.sortedLocationPoints

        var locationData: [LocationExport.LocationData] = []

        for (index, point) in points.enumerated() {
            locationData.append(LocationExport.LocationData(
                timestamp: point.timestamp.ISO8601Format(),
                latitude: point.latitude,
                longitude: point.longitude,
                altitude: point.altitude,
                speed: point.speed,
                course: point.course,
                horizontalAccuracy: point.horizontalAccuracy,
                verticalAccuracy: point.verticalAccuracy
            ))

            await MainActor.run {
                progress(Double(index + 1) / Double(points.count))
            }
        }

        let export = LocationExport(
            sessionId: session.id.uuidString,
            sessionName: session.name,
            startTime: session.startTime.ISO8601Format(),
            endTime: session.endTime?.ISO8601Format(),
            totalDistance: session.totalDistance,
            averageSpeed: session.averageSpeed,
            locations: locationData
        )

        return try saveToFile(export, filename: filename)
    }

    func exportStations(
        session: TrackingSession,
        filename: String,
        progress: @escaping (Double) -> Void
    ) async throws -> URL {
        let events = session.stationPassEvents.sorted { $0.timestamp < $1.timestamp }

        var stationData: [StationExport.StationData] = []

        for (index, event) in events.enumerated() {
            if let station = event.station {
                stationData.append(StationExport.StationData(
                    stationName: station.name,
                    stationLatitude: station.latitude,
                    stationLongitude: station.longitude,
                    stationType: station.stationType,
                    operatorName: station.operatorName,
                    passedAt: event.timestamp.ISO8601Format(),
                    distanceFromStation: event.distanceFromStation
                ))
            }

            await MainActor.run {
                progress(Double(index + 1) / Double(events.count))
            }
        }

        let export = StationExport(
            sessionId: session.id.uuidString,
            sessionName: session.name,
            stations: stationData
        )

        return try saveToFile(export, filename: filename)
    }

    private func saveToFile<T: Encodable>(_ data: T, filename: String) throws -> URL {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        let jsonData = try encoder.encode(data)

        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let sanitizedFilename = filename
            .replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "/", with: "-")
        let fileURL = documentsURL.appendingPathComponent("\(sanitizedFilename).json")

        try jsonData.write(to: fileURL)

        return fileURL
    }
}
