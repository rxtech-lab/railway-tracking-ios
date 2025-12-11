//
//  CSVExporterTests.swift
//  railway-train-trackTests
//
//  Created by Claude on 12/12/25.
//

@testable import railway_train_track
import Foundation
import Testing

struct CSVExporterTests {
    let exporter = CSVExporter()

    // MARK: - Helper Functions

    /// Create a session with location points for testing
    private func createSessionWithPoints(count: Int) -> TrackingSession {
        let session = TrackingSession(name: "Test Session")
        let startDate = Date()

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

    /// Parse CSV content into rows and columns
    private func parseCSV(_ content: String) -> [[String]] {
        let lines = content.components(separatedBy: "\n").filter { !$0.isEmpty }
        return lines.map { line in
            // Simple CSV parsing (doesn't handle all edge cases but sufficient for tests)
            var columns: [String] = []
            var current = ""
            var inQuotes = false

            for char in line {
                if char == "\"" {
                    inQuotes.toggle()
                } else if char == "," && !inQuotes {
                    columns.append(current)
                    current = ""
                } else {
                    current.append(char)
                }
            }
            columns.append(current)
            return columns
        }
    }

    // MARK: - Empty Session Tests

    @Test func exportLocations_emptySession_createsFileWithHeaderOnly() async throws {
        let session = TrackingSession(name: "Empty Session")
        var progressValues: [Double] = []

        let url = try await exporter.exportLocations(
            session: session,
            filename: "test_empty"
        ) { progress in
            progressValues.append(progress)
        }

        // Verify file exists
        #expect(FileManager.default.fileExists(atPath: url.path))

        // Read and verify content
        let content = try String(contentsOf: url, encoding: .utf8)
        let rows = parseCSV(content)

        #expect(rows.count == 1) // Header only
        #expect(rows[0][0] == "timestamp")

        // Progress should reach 1.0
        #expect(progressValues.last == 1.0)

        // Cleanup
        try? FileManager.default.removeItem(at: url)
    }

    // MARK: - Small Dataset Tests (< batch size)

    @Test func exportLocations_smallDataset_exportsCorrectly() async throws {
        let session = createSessionWithPoints(count: 50)
        var progressValues: [Double] = []

        let url = try await exporter.exportLocations(
            session: session,
            filename: "test_small",
            batchSize: 1000
        ) { progress in
            progressValues.append(progress)
        }

        // Read and verify content
        let content = try String(contentsOf: url, encoding: .utf8)
        let rows = parseCSV(content)

        // Should have header + 50 data rows
        #expect(rows.count == 51)

        // Verify header columns
        let header = rows[0]
        #expect(header.contains("timestamp"))
        #expect(header.contains("latitude"))
        #expect(header.contains("longitude"))
        #expect(header.contains("altitude"))
        #expect(header.contains("speed"))

        // Verify a data row
        let firstDataRow = rows[1]
        #expect(firstDataRow.count == 8) // 8 columns

        // Verify latitude value
        let latValue = Double(firstDataRow[1])
        #expect(latValue != nil)
        #expect(latValue! >= 35.0 && latValue! <= 35.1)

        // Progress should end at 1.0
        #expect(progressValues.last == 1.0)

        // Cleanup
        try? FileManager.default.removeItem(at: url)
    }

    // MARK: - Large Dataset Tests (multiple batches)

    @Test func exportLocations_largeDataset_exportsAllRecords() async throws {
        let session = createSessionWithPoints(count: 2500)
        var progressValues: [Double] = []

        let url = try await exporter.exportLocations(
            session: session,
            filename: "test_large",
            batchSize: 1000
        ) { progress in
            progressValues.append(progress)
        }

        // Read and verify content
        let content = try String(contentsOf: url, encoding: .utf8)
        let rows = parseCSV(content)

        // Should have header + 2500 data rows
        #expect(rows.count == 2501)

        // Progress should have multiple updates (at least 3 batches)
        #expect(progressValues.count >= 3)
        #expect(progressValues.last == 1.0)

        // Cleanup
        try? FileManager.default.removeItem(at: url)
    }

    @Test func exportLocations_progressUpdatesCorrectly() async throws {
        let session = createSessionWithPoints(count: 3000)
        var progressValues: [Double] = []

        _ = try await exporter.exportLocations(
            session: session,
            filename: "test_progress",
            batchSize: 1000
        ) { progress in
            progressValues.append(progress)
        }

        // Should have progress updates at each batch boundary
        // With 3000 points and batch size 1000: updates at 1000/3000, 2000/3000, 3000/3000
        #expect(progressValues.count >= 3)

        // Progress should be monotonically increasing
        for i in 1..<progressValues.count {
            #expect(progressValues[i] >= progressValues[i-1])
        }

        // Final progress should be 1.0
        #expect(progressValues.last == 1.0)

        // Cleanup: find and remove test file
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let testFile = documentsURL.appendingPathComponent("test_progress.csv")
        try? FileManager.default.removeItem(at: testFile)
    }

    // MARK: - CSV Parsing Validation

    @Test func exportLocations_canBeParsedCorrectly() async throws {
        let session = createSessionWithPoints(count: 100)

        let url = try await exporter.exportLocations(
            session: session,
            filename: "test_parse"
        ) { _ in }

        // Read content
        let content = try String(contentsOf: url, encoding: .utf8)
        let rows = parseCSV(content)

        // Verify each row has correct number of columns
        for (index, row) in rows.enumerated() {
            #expect(row.count == 8, "Row \(index) has \(row.count) columns, expected 8")
        }

        // Verify numeric values can be parsed
        for row in rows.dropFirst() { // Skip header
            let lat = Double(row[1])
            let lon = Double(row[2])
            let alt = Double(row[3])

            #expect(lat != nil, "Latitude should be parseable")
            #expect(lon != nil, "Longitude should be parseable")
            #expect(alt != nil, "Altitude should be parseable")
        }

        // Cleanup
        try? FileManager.default.removeItem(at: url)
    }

    // MARK: - Filename Sanitization

    @Test func exportLocations_sanitizesFilename() async throws {
        let session = createSessionWithPoints(count: 5)

        let url = try await exporter.exportLocations(
            session: session,
            filename: "test file/with spaces"
        ) { _ in }

        // Filename should have spaces replaced with underscores and slashes with dashes
        #expect(url.lastPathComponent == "test_file-with_spaces.csv")

        // Cleanup
        try? FileManager.default.removeItem(at: url)
    }

    // MARK: - Station Export Tests

    @Test func exportStations_withStations_exportsCorrectly() async throws {
        let session = TrackingSession(name: "Station Test")

        // Create a station
        let station = TrainStation(
            osmId: 12345,
            name: "Test Station",
            latitude: 35.5,
            longitude: 139.5,
            stationType: "station"
        )

        // Create station pass event
        let event = StationPassEvent(
            timestamp: Date(),
            distanceFromStation: 50.0,
            entryPointIndex: 0
        )
        event.station = station
        session.stationPassEvents.append(event)

        var progressValues: [Double] = []

        let url = try await exporter.exportStations(
            session: session,
            filename: "test_stations"
        ) { progress in
            progressValues.append(progress)
        }

        // Read and verify content
        let content = try String(contentsOf: url, encoding: .utf8)
        let rows = parseCSV(content)

        // Should have header + 1 data row
        #expect(rows.count == 2)

        // Verify header
        #expect(rows[0].contains("station_name"))
        #expect(rows[0].contains("station_latitude"))

        // Verify data row contains station name
        let dataRow = rows[1]
        #expect(dataRow.contains("Test Station"))

        // Cleanup
        try? FileManager.default.removeItem(at: url)
    }

    @Test func exportStations_emptyStations_createsFileWithHeaderOnly() async throws {
        let session = TrackingSession(name: "Empty Stations")

        let url = try await exporter.exportStations(
            session: session,
            filename: "test_empty_stations"
        ) { _ in }

        let content = try String(contentsOf: url, encoding: .utf8)
        let rows = parseCSV(content)

        #expect(rows.count == 1) // Header only

        // Cleanup
        try? FileManager.default.removeItem(at: url)
    }
}
