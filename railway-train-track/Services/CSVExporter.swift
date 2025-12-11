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

    /// Default batch size for streaming exports
    static let defaultBatchSize = 1000

    /// Export locations using streaming file writes for memory efficiency
    /// - Parameters:
    ///   - session: The tracking session to export
    ///   - filename: Output filename (without extension)
    ///   - batchSize: Number of points to process per batch (default: 1000)
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

        // Write header
        let header = "timestamp,latitude,longitude,altitude,speed,course,horizontal_accuracy,vertical_accuracy\n"
        if let headerData = header.data(using: .utf8) {
            try fileHandle.write(contentsOf: headerData)
        }

        // Handle empty dataset
        guard !points.isEmpty else {
            await MainActor.run { progress(1.0) }
            return fileURL
        }

        // Process in batches for memory efficiency
        let totalPoints = points.count
        for batchStart in stride(from: 0, to: totalPoints, by: batchSize) {
            let batchEnd = min(batchStart + batchSize, totalPoints)
            let batch = points[batchStart..<batchEnd]

            // Build batch content
            var batchContent = ""
            for point in batch {
                let line = "\(point.timestamp.ISO8601Format()),\(point.latitude),\(point.longitude),\(point.altitude),\(point.speed),\(point.course),\(point.horizontalAccuracy),\(point.verticalAccuracy)\n"
                batchContent += line
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

        return fileURL
    }

    /// Export stations using streaming file writes for memory efficiency
    /// - Parameters:
    ///   - session: The tracking session to export
    ///   - filename: Output filename (without extension)
    ///   - batchSize: Number of events to process per batch (default: 1000)
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

        // Write header
        let header = "timestamp,station_name,station_latitude,station_longitude,distance_from_station,station_type\n"
        if let headerData = header.data(using: .utf8) {
            try fileHandle.write(contentsOf: headerData)
        }

        // Handle empty dataset
        guard !events.isEmpty else {
            await MainActor.run { progress(1.0) }
            return fileURL
        }

        // Process in batches for memory efficiency
        let totalEvents = events.count
        for batchStart in stride(from: 0, to: totalEvents, by: batchSize) {
            let batchEnd = min(batchStart + batchSize, totalEvents)
            let batch = events[batchStart..<batchEnd]

            // Build batch content
            var batchContent = ""
            for event in batch {
                let stationName = event.station?.name ?? "Unknown"
                let stationLat = event.station?.latitude ?? 0
                let stationLon = event.station?.longitude ?? 0
                let stationType = event.station?.stationType ?? ""

                // Escape quotes in station name
                let escapedName = stationName.replacingOccurrences(of: "\"", with: "\"\"")
                let escapedType = stationType.replacingOccurrences(of: "\"", with: "\"\"")

                let line = "\(event.timestamp.ISO8601Format()),\"\(escapedName)\",\(stationLat),\(stationLon),\(event.distanceFromStation),\"\(escapedType)\"\n"
                batchContent += line
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

        return fileURL
    }

    /// Create a sanitized file URL for the CSV export
    private func createFileURL(filename: String) throws -> URL {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let sanitizedFilename = filename
            .replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "/", with: "-")
        return documentsURL.appendingPathComponent("\(sanitizedFilename).csv")
    }
}
