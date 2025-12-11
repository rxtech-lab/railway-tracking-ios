//
//  CoordinateSimplificationServiceTests.swift
//  railway-train-trackTests
//
//  Created by Claude on 12/12/25.
//

@testable import railway_train_track
import CoreLocation
import Testing

struct CoordinateSimplificationServiceTests {
    let service = CoordinateSimplificationService()

    // MARK: - Empty and Edge Cases

    @Test func simplify_emptyArray_returnsEmpty() {
        let result = service.simplify(coordinates: [], epsilon: 0.0001)
        #expect(result.isEmpty)
    }

    @Test func simplify_singlePoint_returnsSamePoint() {
        let coords = [CLLocationCoordinate2D(latitude: 35.0, longitude: 139.0)]
        let result = service.simplify(coordinates: coords, epsilon: 0.0001)
        #expect(result.count == 1)
        #expect(result[0].latitude == 35.0)
        #expect(result[0].longitude == 139.0)
    }

    @Test func simplify_twoPoints_returnsBothPoints() {
        let coords = [
            CLLocationCoordinate2D(latitude: 35.0, longitude: 139.0),
            CLLocationCoordinate2D(latitude: 35.1, longitude: 139.1)
        ]
        let result = service.simplify(coordinates: coords, epsilon: 0.0001)
        #expect(result.count == 2)
    }

    // MARK: - Douglas-Peucker Algorithm Tests

    @Test func simplify_straightLine_reducesToEndpoints() {
        // Create a perfectly straight line with many points
        var coords: [CLLocationCoordinate2D] = []
        for i in 0...10 {
            coords.append(CLLocationCoordinate2D(
                latitude: 35.0 + Double(i) * 0.01,
                longitude: 139.0 + Double(i) * 0.01
            ))
        }

        let result = service.simplify(coordinates: coords, epsilon: 0.001)

        // A perfectly straight line should reduce to just start and end points
        #expect(result.count == 2)
        #expect(result.first?.latitude == coords.first?.latitude)
        #expect(result.last?.latitude == coords.last?.latitude)
    }

    @Test func simplify_rightAngleTurn_keepsCorner() {
        // Create an L-shaped path: horizontal then vertical
        let coords = [
            CLLocationCoordinate2D(latitude: 35.0, longitude: 139.0),
            CLLocationCoordinate2D(latitude: 35.0, longitude: 139.05),
            CLLocationCoordinate2D(latitude: 35.0, longitude: 139.1),  // Corner point
            CLLocationCoordinate2D(latitude: 35.05, longitude: 139.1),
            CLLocationCoordinate2D(latitude: 35.1, longitude: 139.1)
        ]

        let result = service.simplify(coordinates: coords, epsilon: 0.0001)

        // Should keep start, corner, and end (at least 3 points)
        #expect(result.count >= 3)
        // First and last should be preserved
        #expect(result.first?.latitude == 35.0)
        #expect(result.last?.latitude == 35.1)
    }

    @Test func simplify_zigzagPattern_retainsPeaks() {
        // Create a zigzag pattern
        let coords = [
            CLLocationCoordinate2D(latitude: 35.0, longitude: 139.0),
            CLLocationCoordinate2D(latitude: 35.1, longitude: 139.05),  // Peak
            CLLocationCoordinate2D(latitude: 35.0, longitude: 139.1),
            CLLocationCoordinate2D(latitude: 35.1, longitude: 139.15),  // Peak
            CLLocationCoordinate2D(latitude: 35.0, longitude: 139.2)
        ]

        let result = service.simplify(coordinates: coords, epsilon: 0.0001)

        // Should retain all significant points in a zigzag
        #expect(result.count >= 3)
    }

    @Test func simplify_highEpsilon_moreAggressive() {
        var coords: [CLLocationCoordinate2D] = []
        for i in 0...100 {
            // Create a slightly wavy line
            let lat = 35.0 + Double(i) * 0.001
            let lon = 139.0 + Double(i) * 0.001 + sin(Double(i) / 5) * 0.0001
            coords.append(CLLocationCoordinate2D(latitude: lat, longitude: lon))
        }

        let resultLowEpsilon = service.simplify(coordinates: coords, epsilon: 0.00001)
        let resultHighEpsilon = service.simplify(coordinates: coords, epsilon: 0.001)

        // Higher epsilon should produce fewer points
        #expect(resultHighEpsilon.count < resultLowEpsilon.count)
        // But both should have at least start and end
        #expect(resultHighEpsilon.count >= 2)
        #expect(resultLowEpsilon.count >= 2)
    }

    // MARK: - Zoom Tier Configuration Tests

    @Test func zoomTier_veryClose_returnsSmallestEpsilon() {
        let epsilon = CoordinateSimplificationService.SimplificationConfig.epsilon(for: 300)
        #expect(epsilon == 0.00001)
    }

    @Test func zoomTier_close_returnsLightEpsilon() {
        let epsilon = CoordinateSimplificationService.SimplificationConfig.epsilon(for: 1000)
        #expect(epsilon == 0.00005)
    }

    @Test func zoomTier_medium_returnsMediumEpsilon() {
        let epsilon = CoordinateSimplificationService.SimplificationConfig.epsilon(for: 3000)
        #expect(epsilon == 0.0001)
    }

    @Test func zoomTier_far_returnsAggressiveEpsilon() {
        let epsilon = CoordinateSimplificationService.SimplificationConfig.epsilon(for: 8000)
        #expect(epsilon == 0.0002)
    }

    @Test func zoomTier_veryFar_returnsMaxEpsilon() {
        let epsilon = CoordinateSimplificationService.SimplificationConfig.epsilon(for: 50000)
        #expect(epsilon == 0.0005)
    }

    // MARK: - Camera Distance Convenience Method Tests

    @Test func simplifyForCameraDistance_usesCorrectEpsilon() {
        var coords: [CLLocationCoordinate2D] = []
        for i in 0...50 {
            coords.append(CLLocationCoordinate2D(
                latitude: 35.0 + Double(i) * 0.0005,
                longitude: 139.0 + Double(i) * 0.0005
            ))
        }

        let resultClose = service.simplify(coordinates: coords, forCameraDistance: 500)
        let resultFar = service.simplify(coordinates: coords, forCameraDistance: 20000)

        // Far zoom should produce fewer points due to higher epsilon
        #expect(resultFar.count <= resultClose.count)
    }

    // MARK: - Preservation Tests

    @Test func simplify_preservesFirstAndLastPoints() {
        var coords: [CLLocationCoordinate2D] = []
        for i in 0...20 {
            coords.append(CLLocationCoordinate2D(
                latitude: 35.0 + Double(i) * 0.01 + Double.random(in: -0.001...0.001),
                longitude: 139.0 + Double(i) * 0.01 + Double.random(in: -0.001...0.001)
            ))
        }

        let result = service.simplify(coordinates: coords, epsilon: 0.01)

        // First and last points must always be preserved
        #expect(result.first?.latitude == coords.first?.latitude)
        #expect(result.first?.longitude == coords.first?.longitude)
        #expect(result.last?.latitude == coords.last?.latitude)
        #expect(result.last?.longitude == coords.last?.longitude)
    }

    @Test func simplify_resultCountNeverExceedsInput() {
        var coords: [CLLocationCoordinate2D] = []
        for i in 0...100 {
            coords.append(CLLocationCoordinate2D(
                latitude: 35.0 + Double(i) * 0.001,
                longitude: 139.0 + Double(i) * 0.001
            ))
        }

        let result = service.simplify(coordinates: coords, epsilon: 0.0001)

        #expect(result.count <= coords.count)
    }
}
