//
//  CoordinateSimplificationService.swift
//  railway-train-track
//
//  Created by Claude on 12/12/25.
//

import CoreLocation
import Foundation

/// Service for simplifying coordinate arrays using Douglas-Peucker algorithm
/// with zoom-level-aware epsilon configuration
final class CoordinateSimplificationService {

    /// Configuration for zoom-level-based simplification
    struct SimplificationConfig {
        /// Zoom tiers mapping camera distance (meters) to epsilon value
        /// Lower epsilon = more points retained, higher epsilon = more aggressive simplification
        static let zoomTiers: [(maxDistance: Double, epsilon: Double)] = [
            (500, 0.00001),       // Very close: minimal simplification (~100m precision)
            (2000, 0.00005),      // Close: light simplification (~500m precision)
            (5000, 0.0001),       // Medium: moderate simplification (~1km precision)
            (10000, 0.0002),      // Far: aggressive simplification (~2km precision)
            (.infinity, 0.0005)   // Very far: maximum simplification (~5km precision)
        ]

        /// Get the appropriate epsilon value for a given camera distance
        static func epsilon(for cameraDistance: Double) -> Double {
            zoomTiers.first { cameraDistance <= $0.maxDistance }?.epsilon ?? 0.0005
        }
    }

    // MARK: - Public Methods

    /// Simplify coordinates using Douglas-Peucker algorithm with specified epsilon
    /// - Parameters:
    ///   - coordinates: Array of coordinates to simplify
    ///   - epsilon: Tolerance value for simplification (in decimal degrees)
    /// - Returns: Simplified array of coordinates
    func simplify(
        coordinates: [CLLocationCoordinate2D],
        epsilon: Double
    ) -> [CLLocationCoordinate2D] {
        guard coordinates.count > 2 else {
            return coordinates
        }

        return douglasPeucker(coordinates: coordinates, epsilon: epsilon)
    }

    /// Simplify coordinates using zoom-level-aware epsilon
    /// - Parameters:
    ///   - coordinates: Array of coordinates to simplify
    ///   - cameraDistance: Current camera distance in meters
    /// - Returns: Simplified array of coordinates
    func simplify(
        coordinates: [CLLocationCoordinate2D],
        forCameraDistance cameraDistance: Double
    ) -> [CLLocationCoordinate2D] {
        let epsilon = SimplificationConfig.epsilon(for: cameraDistance)
        return simplify(coordinates: coordinates, epsilon: epsilon)
    }

    // MARK: - Douglas-Peucker Algorithm

    /// Recursive Douglas-Peucker algorithm implementation
    private func douglasPeucker(
        coordinates: [CLLocationCoordinate2D],
        epsilon: Double
    ) -> [CLLocationCoordinate2D] {
        guard coordinates.count > 2 else {
            return coordinates
        }

        // Find the point with maximum distance from the line segment
        var maxDistance: Double = 0
        var maxIndex: Int = 0

        let start = coordinates.first!
        let end = coordinates.last!

        for i in 1..<(coordinates.count - 1) {
            let distance = perpendicularDistance(
                point: coordinates[i],
                lineStart: start,
                lineEnd: end
            )
            if distance > maxDistance {
                maxDistance = distance
                maxIndex = i
            }
        }

        // If max distance exceeds epsilon, recursively simplify
        if maxDistance > epsilon {
            // Recursively simplify both segments
            let leftSegment = Array(coordinates[0...maxIndex])
            let rightSegment = Array(coordinates[maxIndex...])

            let simplifiedLeft = douglasPeucker(coordinates: leftSegment, epsilon: epsilon)
            let simplifiedRight = douglasPeucker(coordinates: rightSegment, epsilon: epsilon)

            // Combine results (remove duplicate point at junction)
            return Array(simplifiedLeft.dropLast()) + simplifiedRight
        } else {
            // All intermediate points are within tolerance, return just endpoints
            return [start, end]
        }
    }

    /// Calculate perpendicular distance from a point to a line segment
    /// Uses simplified calculation suitable for small geographic distances
    private func perpendicularDistance(
        point: CLLocationCoordinate2D,
        lineStart: CLLocationCoordinate2D,
        lineEnd: CLLocationCoordinate2D
    ) -> Double {
        // Handle case where line is actually a point
        let dx = lineEnd.longitude - lineStart.longitude
        let dy = lineEnd.latitude - lineStart.latitude

        if dx == 0 && dy == 0 {
            // Line segment is a point, return distance to that point
            return euclideanDistance(from: point, to: lineStart)
        }

        // Calculate perpendicular distance using cross product method
        // This works well for small distances where we can approximate
        // the earth as flat (suitable for route simplification)
        let numerator = abs(
            dy * point.longitude -
            dx * point.latitude +
            lineEnd.longitude * lineStart.latitude -
            lineEnd.latitude * lineStart.longitude
        )
        let denominator = sqrt(dx * dx + dy * dy)

        return numerator / denominator
    }

    /// Simple Euclidean distance between two coordinates (in decimal degrees)
    private func euclideanDistance(
        from: CLLocationCoordinate2D,
        to: CLLocationCoordinate2D
    ) -> Double {
        let dx = to.longitude - from.longitude
        let dy = to.latitude - from.latitude
        return sqrt(dx * dx + dy * dy)
    }
}
