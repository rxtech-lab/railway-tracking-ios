//
//  JSONExporter.swift
//  railway-train-track
//
//  Created by Qiwei Li on 12/6/25.
//

import Foundation

final class JSONExporter {

    /// Default batch size for streaming exports
    static let defaultBatchSize = 1000

    // MARK: - Export Data Structures (Codable for validation/reparsing)

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

    // MARK: - Streaming Export Methods

    /// Export locations using streaming file writes for memory efficiency
    /// - Parameters:
    ///   - session: The tracking session to export
    ///   - filename: Output filename (without extension)
    ///   - batchSize: Number of locations to process per batch (default: 1000)
    ///   - progress: Progress callback (0.0 to 1.0)
    /// - Returns: URL of the exported file
    func exportLocations(
        session: TrackingSession,
        filename: String,
        batchSize: Int = defaultBatchSize,
        progress: @escaping (Double) -> Void
    ) async throws -> URL {
        let points = session.sortedLocationPoints
        let fileURL = try createFileURL(filename: filename)

        // Create empty file
        FileManager.default.createFile(atPath: fileURL.path, contents: nil)
        let fileHandle = try FileHandle(forWritingTo: fileURL)

        defer {
            try? fileHandle.close()
        }

        // Write opening JSON structure with metadata
        let metadata = buildLocationMetadata(session: session)
        try fileHandle.write(contentsOf: metadata)

        // Handle empty dataset
        guard !points.isEmpty else {
            // Close the locations array and JSON object
            let closing = "  ]\n}"
            if let closingData = closing.data(using: .utf8) {
                try fileHandle.write(contentsOf: closingData)
            }
            await MainActor.run { progress(1.0) }
            return fileURL
        }

        // Process locations in batches
        let totalPoints = points.count
        var isFirstItem = true

        for batchStart in stride(from: 0, to: totalPoints, by: batchSize) {
            let batchEnd = min(batchStart + batchSize, totalPoints)
            let batch = points[batchStart..<batchEnd]

            // Build batch JSON content
            var batchContent = ""
            for point in batch {
                if !isFirstItem {
                    batchContent += ",\n"
                }
                isFirstItem = false

                let locationJSON = buildLocationJSON(point: point)
                batchContent += locationJSON
            }

            // Write batch to file
            if let batchData = batchContent.data(using: .utf8) {
                try fileHandle.write(contentsOf: batchData)
            }

            // Update progress
            await MainActor.run {
                progress(Double(batchEnd) / Double(totalPoints))
            }
        }

        // Close the locations array and JSON object
        let closing = "\n  ]\n}"
        if let closingData = closing.data(using: .utf8) {
            try fileHandle.write(contentsOf: closingData)
        }

        return fileURL
    }

    /// Export stations using streaming file writes for memory efficiency
    /// - Parameters:
    ///   - session: The tracking session to export
    ///   - filename: Output filename (without extension)
    ///   - batchSize: Number of stations to process per batch (default: 1000)
    ///   - progress: Progress callback (0.0 to 1.0)
    /// - Returns: URL of the exported file
    func exportStations(
        session: TrackingSession,
        filename: String,
        batchSize: Int = defaultBatchSize,
        progress: @escaping (Double) -> Void
    ) async throws -> URL {
        let events = session.stationPassEvents.sorted { $0.timestamp < $1.timestamp }
        let fileURL = try createFileURL(filename: filename)

        // Create empty file
        FileManager.default.createFile(atPath: fileURL.path, contents: nil)
        let fileHandle = try FileHandle(forWritingTo: fileURL)

        defer {
            try? fileHandle.close()
        }

        // Write opening JSON structure with metadata
        let metadata = buildStationMetadata(session: session)
        try fileHandle.write(contentsOf: metadata)

        // Handle empty dataset
        guard !events.isEmpty else {
            let closing = "  ]\n}"
            if let closingData = closing.data(using: .utf8) {
                try fileHandle.write(contentsOf: closingData)
            }
            await MainActor.run { progress(1.0) }
            return fileURL
        }

        // Process stations in batches
        let totalEvents = events.count
        var isFirstItem = true

        for batchStart in stride(from: 0, to: totalEvents, by: batchSize) {
            let batchEnd = min(batchStart + batchSize, totalEvents)
            let batch = events[batchStart..<batchEnd]

            // Build batch JSON content
            var batchContent = ""
            for event in batch {
                guard let station = event.station else { continue }

                if !isFirstItem {
                    batchContent += ",\n"
                }
                isFirstItem = false

                let stationJSON = buildStationJSON(station: station, event: event)
                batchContent += stationJSON
            }

            // Write batch to file
            if let batchData = batchContent.data(using: .utf8) {
                try fileHandle.write(contentsOf: batchData)
            }

            // Update progress
            await MainActor.run {
                progress(Double(batchEnd) / Double(totalEvents))
            }
        }

        // Close the stations array and JSON object
        let closing = "\n  ]\n}"
        if let closingData = closing.data(using: .utf8) {
            try fileHandle.write(contentsOf: closingData)
        }

        return fileURL
    }

    // MARK: - Private Helpers

    /// Build the opening JSON structure with session metadata for locations
    private func buildLocationMetadata(session: TrackingSession) -> Data {
        var json = "{\n"
        json += "  \"sessionId\": \"\(session.id.uuidString)\",\n"
        json += "  \"sessionName\": \"\(escapeJSON(session.name))\",\n"
        json += "  \"startTime\": \"\(session.startTime.ISO8601Format())\",\n"

        if let endTime = session.endTime {
            json += "  \"endTime\": \"\(endTime.ISO8601Format())\",\n"
        } else {
            json += "  \"endTime\": null,\n"
        }

        if let totalDistance = session.totalDistance {
            json += "  \"totalDistance\": \(totalDistance),\n"
        } else {
            json += "  \"totalDistance\": null,\n"
        }

        if let averageSpeed = session.averageSpeed {
            json += "  \"averageSpeed\": \(averageSpeed),\n"
        } else {
            json += "  \"averageSpeed\": null,\n"
        }

        json += "  \"locations\": [\n"

        return json.data(using: .utf8)!
    }

    /// Build the opening JSON structure with session metadata for stations
    private func buildStationMetadata(session: TrackingSession) -> Data {
        var json = "{\n"
        json += "  \"sessionId\": \"\(session.id.uuidString)\",\n"
        json += "  \"sessionName\": \"\(escapeJSON(session.name))\",\n"
        json += "  \"stations\": [\n"

        return json.data(using: .utf8)!
    }

    /// Build JSON for a single location point
    private func buildLocationJSON(point: LocationPoint) -> String {
        var json = "    {\n"
        json += "      \"timestamp\": \"\(point.timestamp.ISO8601Format())\",\n"
        json += "      \"latitude\": \(point.latitude),\n"
        json += "      \"longitude\": \(point.longitude),\n"
        json += "      \"altitude\": \(point.altitude),\n"
        json += "      \"speed\": \(point.speed),\n"
        json += "      \"course\": \(point.course),\n"
        json += "      \"horizontalAccuracy\": \(point.horizontalAccuracy),\n"
        json += "      \"verticalAccuracy\": \(point.verticalAccuracy)\n"
        json += "    }"
        return json
    }

    /// Build JSON for a single station
    private func buildStationJSON(station: TrainStation, event: StationPassEvent) -> String {
        var json = "    {\n"
        json += "      \"stationName\": \"\(escapeJSON(station.name))\",\n"
        json += "      \"stationLatitude\": \(station.latitude),\n"
        json += "      \"stationLongitude\": \(station.longitude),\n"

        if let stationType = station.stationType {
            json += "      \"stationType\": \"\(escapeJSON(stationType))\",\n"
        } else {
            json += "      \"stationType\": null,\n"
        }

        if let operatorName = station.operatorName {
            json += "      \"operatorName\": \"\(escapeJSON(operatorName))\",\n"
        } else {
            json += "      \"operatorName\": null,\n"
        }

        json += "      \"passedAt\": \"\(event.timestamp.ISO8601Format())\",\n"
        json += "      \"distanceFromStation\": \(event.distanceFromStation)\n"
        json += "    }"
        return json
    }

    /// Escape special characters for JSON strings
    private func escapeJSON(_ string: String) -> String {
        var result = string
        result = result.replacingOccurrences(of: "\\", with: "\\\\")
        result = result.replacingOccurrences(of: "\"", with: "\\\"")
        result = result.replacingOccurrences(of: "\n", with: "\\n")
        result = result.replacingOccurrences(of: "\r", with: "\\r")
        result = result.replacingOccurrences(of: "\t", with: "\\t")
        return result
    }

    /// Create a sanitized file URL for the JSON export
    private func createFileURL(filename: String) throws -> URL {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let sanitizedFilename = filename
            .replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "/", with: "-")
        return documentsURL.appendingPathComponent("\(sanitizedFilename).json")
    }
}
