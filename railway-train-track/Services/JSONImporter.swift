//
//  JSONImporter.swift
//  railway-train-track
//
//  Created by Claude on 12/12/25.
//

import Foundation

enum JSONImportError: LocalizedError {
    case invalidFormat
    case missingRequiredField(String)
    case invalidTimestamp(String)
    case noLocations

    var errorDescription: String? {
        switch self {
        case .invalidFormat:
            return "The file is not a valid session export format."
        case .missingRequiredField(let field):
            return "Missing required field: \(field)"
        case .invalidTimestamp(let value):
            return "Invalid timestamp format: \(value)"
        case .noLocations:
            return "The file contains no location data."
        }
    }
}

struct ImportedSession {
    let name: String
    let startTime: Date
    let endTime: Date?
    let totalDistance: Double?
    let averageSpeed: Double?
    let locationPoints: [ImportedLocationPoint]
}

struct ImportedLocationPoint {
    let timestamp: Date
    let latitude: Double
    let longitude: Double
    let altitude: Double
    let speed: Double
    let course: Double
    let horizontalAccuracy: Double
    let verticalAccuracy: Double
}

final class JSONImporter {

    func importSession(from url: URL) throws -> ImportedSession {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()

        let export = try decoder.decode(JSONExporter.LocationExport.self, from: data)

        guard !export.locations.isEmpty else {
            throw JSONImportError.noLocations
        }

        guard let startTime = parseISO8601(export.startTime) else {
            throw JSONImportError.invalidTimestamp(export.startTime)
        }

        var endTime: Date? = nil
        if let endTimeString = export.endTime {
            endTime = parseISO8601(endTimeString)
        }

        var locationPoints: [ImportedLocationPoint] = []
        for locationData in export.locations {
            guard let timestamp = parseISO8601(locationData.timestamp) else {
                throw JSONImportError.invalidTimestamp(locationData.timestamp)
            }

            let point = ImportedLocationPoint(
                timestamp: timestamp,
                latitude: locationData.latitude,
                longitude: locationData.longitude,
                altitude: locationData.altitude,
                speed: locationData.speed,
                course: locationData.course,
                horizontalAccuracy: locationData.horizontalAccuracy,
                verticalAccuracy: locationData.verticalAccuracy
            )
            locationPoints.append(point)
        }

        return ImportedSession(
            name: export.sessionName,
            startTime: startTime,
            endTime: endTime,
            totalDistance: export.totalDistance,
            averageSpeed: export.averageSpeed,
            locationPoints: locationPoints
        )
    }

    private func parseISO8601(_ string: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: string) {
            return date
        }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: string)
    }
}
