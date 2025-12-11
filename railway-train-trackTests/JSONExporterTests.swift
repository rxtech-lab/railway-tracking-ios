//
//  JSONExporterTests.swift
//  railway-train-trackTests
//
//  Created by Claude on 12/12/25.
//

@testable import railway_train_track
import Foundation
import Testing

struct JSONExporterTests {
    let exporter = JSONExporter()

    // MARK: - Helper Functions

    /// Create a session with location points for testing
    private func createSessionWithPoints(count: Int) -> TrackingSession {
        let session = TrackingSession(name: "Test Session")
        session.totalDistance = 5000.0
        session.averageSpeed = 15.5
        let startDate = Date()
        session.endTime = startDate.addingTimeInterval(TimeInterval(count))

        for i in 0..<count {
            let point = LocationPoint(
                timestamp: startDate.addingTimeInterval(TimeInterval(i)),
                latitude: 35.0 + Double(i) * 0.001,
                longitude: 139.0 + Double(i) * 0.001,
                altitude: 10.0 + Double(i),
                horizontalAccuracy: 5.0,
                verticalAccuracy: 10.0,
                speed: 10.0,
                course: 45.0
            )
            session.locationPoints.append(point)
        }
        return session
    }

    // MARK: - Empty Session Tests

    @Test func exportLocations_emptySession_createsValidJSON() async throws {
        let session = TrackingSession(name: "Empty Session")
        var progressValues: [Double] = []

        let url = try await exporter.exportLocations(
            session: session,
            filename: "test_empty_json"
        ) { progress in
            progressValues.append(progress)
        }

        // Verify file exists
        #expect(FileManager.default.fileExists(atPath: url.path))

        // Read and verify it can be parsed as JSON
        let data = try Data(contentsOf: url)
        let parsed = try JSONDecoder().decode(JSONExporter.LocationExport.self, from: data)

        #expect(parsed.sessionName == "Empty Session")
        #expect(parsed.locations.isEmpty)

        // Progress should reach 1.0
        #expect(progressValues.last == 1.0)

        // Cleanup
        try? FileManager.default.removeItem(at: url)
    }

    // MARK: - Small Dataset Tests

    @Test func exportLocations_smallDataset_canBeReparsed() async throws {
        let session = createSessionWithPoints(count: 50)

        let url = try await exporter.exportLocations(
            session: session,
            filename: "test_small_json",
            batchSize: 1000
        ) { _ in }

        // Parse the exported JSON
        let data = try Data(contentsOf: url)
        let parsed = try JSONDecoder().decode(JSONExporter.LocationExport.self, from: data)

        // Verify metadata
        #expect(parsed.sessionId == session.id.uuidString)
        #expect(parsed.sessionName == "Test Session")
        #expect(parsed.totalDistance == 5000.0)
        #expect(parsed.averageSpeed == 15.5)

        // Verify location count
        #expect(parsed.locations.count == 50)

        // Verify first location data
        let firstLocation = parsed.locations[0]
        #expect(firstLocation.latitude >= 35.0 && firstLocation.latitude <= 35.1)
        #expect(firstLocation.longitude >= 139.0 && firstLocation.longitude <= 139.1)
        #expect(firstLocation.altitude == 10.0)
        #expect(firstLocation.speed == 10.0)
        #expect(firstLocation.course == 45.0)

        // Cleanup
        try? FileManager.default.removeItem(at: url)
    }

    // MARK: - Large Dataset Tests (multiple batches)

    @Test func exportLocations_largeDataset_canBeReparsed() async throws {
        let session = createSessionWithPoints(count: 2500)
        var progressValues: [Double] = []

        let url = try await exporter.exportLocations(
            session: session,
            filename: "test_large_json",
            batchSize: 1000
        ) { progress in
            progressValues.append(progress)
        }

        // Parse the exported JSON
        let data = try Data(contentsOf: url)
        let parsed = try JSONDecoder().decode(JSONExporter.LocationExport.self, from: data)

        // Verify all locations were exported
        #expect(parsed.locations.count == 2500)

        // Verify progress had multiple updates
        #expect(progressValues.count >= 3)
        #expect(progressValues.last == 1.0)

        // Cleanup
        try? FileManager.default.removeItem(at: url)
    }

    @Test func exportLocations_allPointsPreserved() async throws {
        let session = createSessionWithPoints(count: 1500)

        let url = try await exporter.exportLocations(
            session: session,
            filename: "test_preserved_json",
            batchSize: 500
        ) { _ in }

        // Parse the exported JSON
        let data = try Data(contentsOf: url)
        let parsed = try JSONDecoder().decode(JSONExporter.LocationExport.self, from: data)

        // Verify exact count
        #expect(parsed.locations.count == session.locationPoints.count)

        // Verify data integrity - check a few random points
        for i in [0, 500, 1000, 1499] {
            let original = session.sortedLocationPoints[i]
            let exported = parsed.locations[i]

            #expect(exported.latitude == original.latitude)
            #expect(exported.longitude == original.longitude)
            #expect(exported.altitude == original.altitude)
        }

        // Cleanup
        try? FileManager.default.removeItem(at: url)
    }

    // MARK: - Metadata Preservation Tests

    @Test func exportLocations_preservesMetadata() async throws {
        let session = TrackingSession(name: "Metadata Test Session")
        session.totalDistance = 12345.67
        session.averageSpeed = 25.5
        session.endTime = Date().addingTimeInterval(3600)

        // Add one point
        let point = LocationPoint(
            timestamp: Date(),
            latitude: 35.5,
            longitude: 139.5,
            altitude: 100
        )
        session.locationPoints.append(point)

        let url = try await exporter.exportLocations(
            session: session,
            filename: "test_metadata_json"
        ) { _ in }

        // Parse and verify
        let data = try Data(contentsOf: url)
        let parsed = try JSONDecoder().decode(JSONExporter.LocationExport.self, from: data)

        #expect(parsed.sessionId == session.id.uuidString)
        #expect(parsed.sessionName == "Metadata Test Session")
        #expect(parsed.totalDistance == 12345.67)
        #expect(parsed.averageSpeed == 25.5)
        #expect(parsed.endTime != nil)
        #expect(parsed.startTime != nil)

        // Cleanup
        try? FileManager.default.removeItem(at: url)
    }

    @Test func exportLocations_handlesNilMetadata() async throws {
        let session = TrackingSession(name: "Nil Metadata")
        // totalDistance and averageSpeed are nil by default
        // endTime is nil by default

        let point = LocationPoint(timestamp: Date(), latitude: 35.0, longitude: 139.0, altitude: 10)
        session.locationPoints.append(point)

        let url = try await exporter.exportLocations(
            session: session,
            filename: "test_nil_metadata"
        ) { _ in }

        // Parse and verify null handling
        let data = try Data(contentsOf: url)
        let parsed = try JSONDecoder().decode(JSONExporter.LocationExport.self, from: data)

        #expect(parsed.totalDistance == nil)
        #expect(parsed.averageSpeed == nil)
        #expect(parsed.endTime == nil)

        // Cleanup
        try? FileManager.default.removeItem(at: url)
    }

    // MARK: - Progress Callback Tests

    @Test func exportLocations_progressIsMonotonic() async throws {
        let session = createSessionWithPoints(count: 3000)
        var progressValues: [Double] = []

        _ = try await exporter.exportLocations(
            session: session,
            filename: "test_progress_json",
            batchSize: 1000
        ) { progress in
            progressValues.append(progress)
        }

        // Progress should be monotonically increasing
        for i in 1..<progressValues.count {
            #expect(progressValues[i] >= progressValues[i-1], "Progress should increase")
        }

        // Final progress should be 1.0
        #expect(progressValues.last == 1.0)

        // Cleanup
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let testFile = documentsURL.appendingPathComponent("test_progress_json.json")
        try? FileManager.default.removeItem(at: testFile)
    }

    // MARK: - Station Export Tests

    @Test func exportStations_canBeReparsed() async throws {
        let session = TrackingSession(name: "Station Test")

        // Create stations with pass events
        for i in 0..<3 {
            let station = TrainStation(
                osmId: Int64(10000 + i),
                name: "Station \(i)",
                latitude: 35.0 + Double(i) * 0.1,
                longitude: 139.0 + Double(i) * 0.1,
                stationType: "station"
            )
            station.operatorName = "Test Railway"

            let event = StationPassEvent(
                timestamp: Date().addingTimeInterval(TimeInterval(i * 600)),
                distanceFromStation: Double(50 + i * 10),
                entryPointIndex: i
            )
            event.station = station
            session.stationPassEvents.append(event)
        }

        let url = try await exporter.exportStations(
            session: session,
            filename: "test_stations_json"
        ) { _ in }

        // Parse and verify
        let data = try Data(contentsOf: url)
        let parsed = try JSONDecoder().decode(JSONExporter.StationExport.self, from: data)

        #expect(parsed.sessionId == session.id.uuidString)
        #expect(parsed.sessionName == "Station Test")
        #expect(parsed.stations.count == 3)

        // Verify station data
        let firstStation = parsed.stations[0]
        #expect(firstStation.stationName == "Station 0")
        #expect(firstStation.stationLatitude == 35.0)
        #expect(firstStation.stationType == "station")
        #expect(firstStation.operatorName == "Test Railway")

        // Cleanup
        try? FileManager.default.removeItem(at: url)
    }

    @Test func exportStations_emptyStations_createsValidJSON() async throws {
        let session = TrackingSession(name: "Empty Stations")

        let url = try await exporter.exportStations(
            session: session,
            filename: "test_empty_stations_json"
        ) { _ in }

        // Parse and verify
        let data = try Data(contentsOf: url)
        let parsed = try JSONDecoder().decode(JSONExporter.StationExport.self, from: data)

        #expect(parsed.stations.isEmpty)
        #expect(parsed.sessionName == "Empty Stations")

        // Cleanup
        try? FileManager.default.removeItem(at: url)
    }

    // MARK: - Special Characters Test

    @Test func exportLocations_handlesSpecialCharacters() async throws {
        let session = TrackingSession(name: "Test \"Session\" with\nnewlines")

        let point = LocationPoint(timestamp: Date(), latitude: 35.0, longitude: 139.0, altitude: 10)
        session.locationPoints.append(point)

        let url = try await exporter.exportLocations(
            session: session,
            filename: "test_special_chars"
        ) { _ in }

        // Should be valid JSON that can be parsed
        let data = try Data(contentsOf: url)
        let parsed = try JSONDecoder().decode(JSONExporter.LocationExport.self, from: data)

        #expect(parsed.sessionName == "Test \"Session\" with\nnewlines")

        // Cleanup
        try? FileManager.default.removeItem(at: url)
    }

    // MARK: - Batch Boundary Tests

    @Test func exportLocations_exactlyOneBatch() async throws {
        let session = createSessionWithPoints(count: 1000)
        var progressUpdates = 0

        let url = try await exporter.exportLocations(
            session: session,
            filename: "test_one_batch",
            batchSize: 1000
        ) { _ in
            progressUpdates += 1
        }

        // Should have exactly one progress update
        #expect(progressUpdates == 1)

        // Verify all data exported
        let data = try Data(contentsOf: url)
        let parsed = try JSONDecoder().decode(JSONExporter.LocationExport.self, from: data)
        #expect(parsed.locations.count == 1000)

        // Cleanup
        try? FileManager.default.removeItem(at: url)
    }

    @Test func exportLocations_justOverOneBatch() async throws {
        let session = createSessionWithPoints(count: 1001)
        var progressUpdates = 0

        let url = try await exporter.exportLocations(
            session: session,
            filename: "test_over_batch",
            batchSize: 1000
        ) { _ in
            progressUpdates += 1
        }

        // Should have two progress updates
        #expect(progressUpdates == 2)

        // Verify all data exported
        let data = try Data(contentsOf: url)
        let parsed = try JSONDecoder().decode(JSONExporter.LocationExport.self, from: data)
        #expect(parsed.locations.count == 1001)

        // Cleanup
        try? FileManager.default.removeItem(at: url)
    }
}
