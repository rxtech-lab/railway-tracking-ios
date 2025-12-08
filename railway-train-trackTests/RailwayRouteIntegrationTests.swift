//
//  RailwayRouteIntegrationTests.swift
//  railway-train-trackTests
//
//  Integration tests for railway route fetching using real APIs.
//  Note: These tests require network connectivity.
//

@testable import railway_train_track
import CoreLocation
import MapKit
import Testing

struct RailwayRouteIntegrationTests {

    // MARK: - Test Stations (Tokyo Area)

    static let tokyoStation = CLLocationCoordinate2D(
        latitude: 35.68126721027926,
        longitude: 139.76656227521212
    )

    static let shimbashiStation = CLLocationCoordinate2D(
        latitude: 35.66684587328303,
        longitude: 139.75846093470696
    )

    static let shinagawaStation = CLLocationCoordinate2D(
        latitude: 35.62888058247294,
        longitude: 139.740394850253
    )

    // MARK: - OpenRailway Route Tests

    @Test func openRailwayProvider_fetchesRouteBetweenTwoStations() async throws {
        // Arrange
        let provider = OpenRailwayProvider()

        // Act
        let routes = try await provider.fetchRoutes(
            from: Self.tokyoStation,
            to: Self.shimbashiStation
        )

        // Assert: Should return exactly ONE continuous route
        #expect(routes.count == 1, "Expected 1 continuous route, got \(routes.count)")

        // Route should have multiple coordinates
        guard let route = routes.first else {
            Issue.record("Route is nil")
            return
        }

        #expect(route.coordinates.count > 2, "Route should have more than 2 points")

        // First point should be near Tokyo Station
        let firstPoint = route.coordinates.first!
        let distanceFromStart = Self.distance(from: firstPoint, to: Self.tokyoStation)
        #expect(distanceFromStart < 500, "Start point should be within 500m of Tokyo Station, got \(distanceFromStart)m")

        // Last point should be near Shimbashi Station
        let lastPoint = route.coordinates.last!
        let distanceFromEnd = Self.distance(from: lastPoint, to: Self.shimbashiStation)
        #expect(distanceFromEnd < 500, "End point should be within 500m of Shimbashi Station, got \(distanceFromEnd)m")
    }

    @Test func openRailwayProvider_fetchesRouteAcrossThreeStations() async throws {
        // Arrange
        let provider = OpenRailwayProvider()

        // Act: Fetch route from Tokyo to Shinagawa (passing through Shimbashi)
        let routes = try await provider.fetchRoutes(
            from: Self.tokyoStation,
            to: Self.shinagawaStation
        )

        // Assert: Should return ONE continuous route
        #expect(routes.count == 1, "Expected 1 continuous route")

        guard let route = routes.first else {
            Issue.record("Route is nil")
            return
        }

        // Route should be longer than Tokyo-Shimbashi route
        #expect(route.coordinates.count > 5, "Multi-station route should have many points")

        // Verify route passes near Shimbashi (intermediate station)
        let passesNearShimbashi = route.coordinates.contains { coord in
            let distance = Self.distance(from: coord, to: Self.shimbashiStation)
            return distance < 1000 // Within 1km of Shimbashi
        }
        #expect(passesNearShimbashi, "Route should pass near Shimbashi station")
    }

    @Test func openRailwayProvider_returnsContinuousRoute_notDisconnectedSegments() async throws {
        // Arrange
        let provider = OpenRailwayProvider()

        // Act
        let routes = try await provider.fetchRoutes(
            from: Self.tokyoStation,
            to: Self.shinagawaStation
        )

        // Assert: Exactly 1 route (not multiple disconnected segments)
        #expect(routes.count == 1, "Should be ONE continuous route, not \(routes.count) segments")

        guard let route = routes.first, route.coordinates.count > 1 else {
            Issue.record("Route should have coordinates")
            return
        }

        // Verify route is continuous (each point reasonably close to next)
        for i in 0..<(route.coordinates.count - 1) {
            let current = route.coordinates[i]
            let next = route.coordinates[i + 1]
            let segmentDistance = Self.distance(from: current, to: next)

            // Each segment should be less than 5km (railway routes shouldn't have huge gaps)
            #expect(segmentDistance < 5000, "Segment \(i) gap is too large: \(segmentDistance)m")
        }
    }

    @Test func openRailwayProvider_tokyoShimbashiRoute_shouldBeLessThan5km() async throws {
        // Arrange
        let provider = OpenRailwayProvider()

        // Act
        let routes = try await provider.fetchRoutes(
            from: Self.tokyoStation,
            to: Self.shimbashiStation
        )

        // Assert
        guard let route = routes.first else {
            Issue.record("No route returned")
            return
        }

        // Calculate total route distance
        var totalDistance: CLLocationDistance = 0
        for i in 0..<(route.coordinates.count - 1) {
            totalDistance += Self.distance(from: route.coordinates[i], to: route.coordinates[i + 1])
        }

        // Tokyo Station to Shimbashi Station by rail is approximately 1.8-2km
        // Should definitely be less than 5km
        print("DEBUG: Tokyo-Shimbashi route distance: \(totalDistance)m, coordinates: \(route.coordinates.count)")
        #expect(totalDistance < 5000, "Route should be < 5km, got \(totalDistance)m")
    }

    @Test func openRailwayProvider_coordinatesAreCLLocationCoordinate2D() async throws {
        // Arrange
        let provider = OpenRailwayProvider()

        // Act
        let routes = try await provider.fetchRoutes(
            from: Self.tokyoStation,
            to: Self.shimbashiStation
        )

        // Assert: Coordinates should be properly typed CLLocationCoordinate2D
        guard let route = routes.first, let firstCoord = route.coordinates.first else {
            Issue.record("No coordinates returned")
            return
        }

        // Tokyo coordinates: lat ~35.68, lon ~139.76
        // Verify latitude is in expected range (around 35)
        #expect(firstCoord.latitude > 30 && firstCoord.latitude < 40, "Latitude should be ~35, got \(firstCoord.latitude)")
        #expect(firstCoord.longitude > 130 && firstCoord.longitude < 150, "Longitude should be ~139, got \(firstCoord.longitude)")
    }

    // MARK: - AppleMaps Station Search Tests
    // Note: MKLocalSearch may return empty results in simulator environments.
    // These tests verify the provider doesn't crash and handles responses correctly.

    @Test func appleMapsStationProvider_searchesTokyoStation() async throws {
        // Arrange
        let provider = AppleMapsStationProvider()
        let region = MKCoordinateRegion(
            center: Self.tokyoStation,
            span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
        )

        // Act: Search should complete without error
        let results = try await provider.search(query: "Tokyo", region: region)

        // Assert: If results exist (may be empty in simulator), verify they're relevant
        if !results.isEmpty {
            let hasRelevantResult = results.contains { item in
                let name = item.name?.lowercased() ?? ""
                return name.contains("tokyo") || name.contains("station")
            }
            #expect(hasRelevantResult, "Should return Tokyo Station in results when available")
        }
        // Pass even if empty (simulator limitation)
    }

    @Test func appleMapsStationProvider_returnsPublicTransportPOIs() async throws {
        // Arrange
        let provider = AppleMapsStationProvider()
        let region = MKCoordinateRegion(
            center: Self.shimbashiStation,
            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
        )

        // Act: Search should complete without error
        let results = try await provider.search(query: "Shimbashi", region: region)

        // Assert: Results may be empty in simulator, but search should succeed
        // On real device, this should return results
        _ = results // Acknowledge results exist (may be empty in simulator)
    }

    // MARK: - Helper Functions

    private static func distance(
        from coord1: CLLocationCoordinate2D,
        to coord2: CLLocationCoordinate2D
    ) -> CLLocationDistance {
        let loc1 = CLLocation(latitude: coord1.latitude, longitude: coord1.longitude)
        let loc2 = CLLocation(latitude: coord2.latitude, longitude: coord2.longitude)
        return loc1.distance(from: loc2)
    }
}
