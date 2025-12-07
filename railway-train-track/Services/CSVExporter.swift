//
//  CSVExporter.swift
//  railway-train-track
//
//  Created by Qiwei Li on 12/6/25.
//

import Foundation

final class CSVExporter {

    enum ExportType {
        case locations
        case stations
    }

    func exportLocations(
        session: TrackingSession,
        filename: String,
        progress: @escaping (Double) -> Void
    ) async throws -> URL {
        let points = session.sortedLocationPoints

        var csvContent = "timestamp,latitude,longitude,altitude,speed,course,horizontal_accuracy,vertical_accuracy\n"

        for (index, point) in points.enumerated() {
            let line = "\(point.timestamp.ISO8601Format()),\(point.latitude),\(point.longitude),\(point.altitude),\(point.speed),\(point.course),\(point.horizontalAccuracy),\(point.verticalAccuracy)\n"
            csvContent += line

            await MainActor.run {
                progress(Double(index + 1) / Double(points.count))
            }
        }

        return try saveToFile(content: csvContent, filename: filename)
    }

    func exportStations(
        session: TrackingSession,
        filename: String,
        progress: @escaping (Double) -> Void
    ) async throws -> URL {
        let events = session.stationPassEvents.sorted { $0.timestamp < $1.timestamp }

        var csvContent = "timestamp,station_name,station_latitude,station_longitude,distance_from_station,station_type\n"

        for (index, event) in events.enumerated() {
            let stationName = event.station?.name ?? "Unknown"
            let stationLat = event.station?.latitude ?? 0
            let stationLon = event.station?.longitude ?? 0
            let stationType = event.station?.stationType ?? ""

            let line = "\(event.timestamp.ISO8601Format()),\"\(stationName)\",\(stationLat),\(stationLon),\(event.distanceFromStation),\"\(stationType)\"\n"
            csvContent += line

            await MainActor.run {
                progress(Double(index + 1) / Double(events.count))
            }
        }

        return try saveToFile(content: csvContent, filename: filename)
    }

    private func saveToFile(content: String, filename: String) throws -> URL {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let sanitizedFilename = filename
            .replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "/", with: "-")
        let fileURL = documentsURL.appendingPathComponent("\(sanitizedFilename).csv")

        try content.write(to: fileURL, atomically: true, encoding: .utf8)

        return fileURL
    }
}
