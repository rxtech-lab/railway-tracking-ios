//
//  StationDataViewModel.swift
//  railway-train-track
//
//  Created by Qiwei Li on 12/7/25.
//
//  Unified ViewModel for station search and railway routes.
//  Uses protocol-based providers for easy server migration in the future.
//

import Foundation
import SwiftUI
import MapKit
import CoreLocation

// MARK: - Protocols for Future Server Migration

protocol StationSearchProviding {
    func search(query: String, region: MKCoordinateRegion) async throws -> [MKMapItem]
}

protocol RailwayRouteProviding {
    func fetchRoutes(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D, buffer: Double) async throws -> [[[Double]]]
}

// MARK: - Apple Maps Station Provider

final class AppleMapsStationProvider: StationSearchProviding {
    func search(query: String, region: MKCoordinateRegion) async throws -> [MKMapItem] {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = "\(query) train station"
        request.region = region
        request.resultTypes = .pointOfInterest

        let search = MKLocalSearch(request: request)
        let response = try await search.start()

        // Filter for railway-related POIs
        return response.mapItems.filter { item in
            item.pointOfInterestCategory == .publicTransport ||
            item.name?.lowercased().contains("station") == true ||
            item.name?.lowercased().contains("railway") == true ||
            item.name?.lowercased().contains("train") == true
        }
    }
}

// MARK: - Overpass Railway Provider

final class OverpassRailwayProvider: RailwayRouteProviding {
    private let baseURL = "https://overpass-api.de/api/interpreter"

    struct OverpassWayResponse: Decodable {
        let elements: [OverpassWayElement]
    }

    struct OverpassWayElement: Decodable {
        let type: String
        let id: Int64
        let geometry: [OverpassNode]?
        let tags: [String: String]?
    }

    struct OverpassNode: Decodable {
        let lat: Double
        let lon: Double
    }

    func fetchRoutes(from startCoord: CLLocationCoordinate2D, to endCoord: CLLocationCoordinate2D, buffer: Double = 1000) async throws -> [[[Double]]] {
        // Calculate bounding box
        let minLat = min(startCoord.latitude, endCoord.latitude)
        let maxLat = max(startCoord.latitude, endCoord.latitude)
        let minLon = min(startCoord.longitude, endCoord.longitude)
        let maxLon = max(startCoord.longitude, endCoord.longitude)

        let latBuffer = buffer / 111000.0
        let lonBuffer = buffer / (111000.0 * cos(minLat * .pi / 180))

        let bbox = "\(minLat - latBuffer),\(minLon - lonBuffer),\(maxLat + latBuffer),\(maxLon + lonBuffer)"

        let query = """
        [out:json][timeout:30];
        way["railway"="rail"](\(bbox));
        out geom;
        """

        guard let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "\(baseURL)?data=\(encodedQuery)") else {
            throw URLError(.badURL)
        }

        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode(OverpassWayResponse.self, from: data)

        return response.elements.compactMap { element -> [[Double]]? in
            guard let geometry = element.geometry, !geometry.isEmpty else { return nil }
            return geometry.map { [$0.lat, $0.lon] }
        }
    }
}

// MARK: - Station Data ViewModel

@Observable
final class StationDataViewModel {
    // Search state
    var searchQuery: String = ""
    var searchResults: [MKMapItem] = []
    var isSearching: Bool = false
    var searchError: String?

    // Railway route state
    var railwayRoutes: [[CLLocationCoordinate2D]] = []
    var isFetchingRailways: Bool = false
    var railwayError: String?

    // Protocol-based providers (swap for server implementations later)
    private let stationProvider: StationSearchProviding
    private let railwayProvider: RailwayRouteProviding

    init(
        stationProvider: StationSearchProviding = AppleMapsStationProvider(),
        railwayProvider: RailwayRouteProviding = OverpassRailwayProvider()
    ) {
        self.stationProvider = stationProvider
        self.railwayProvider = railwayProvider
    }

    // MARK: - Station Search

    func searchStations(region: MKCoordinateRegion) async {
        guard !searchQuery.isEmpty else {
            searchResults = []
            return
        }

        isSearching = true
        searchError = nil

        do {
            searchResults = try await stationProvider.search(query: searchQuery, region: region)
        } catch {
            searchError = error.localizedDescription
            searchResults = []
        }

        isSearching = false
    }

    func clearSearch() {
        searchQuery = ""
        searchResults = []
        searchError = nil
    }

    // MARK: - Railway Routes

    func fetchRailwayRoutes(between stations: [TrainStation]) async {
        guard stations.count >= 2 else {
            railwayRoutes = []
            return
        }

        isFetchingRailways = true
        railwayError = nil
        var routes: [[CLLocationCoordinate2D]] = []

        for i in 0..<(stations.count - 1) {
            let start = stations[i].coordinate
            let end = stations[i + 1].coordinate

            do {
                let wayCoords = try await railwayProvider.fetchRoutes(from: start, to: end, buffer: 1000)
                for coords in wayCoords {
                    routes.append(coords.map { CLLocationCoordinate2D(latitude: $0[0], longitude: $0[1]) })
                }
            } catch {
                // Continue with next pair, log error
                print("Failed to fetch railway between stations: \(error.localizedDescription)")
            }
        }

        await MainActor.run {
            self.railwayRoutes = routes
            self.isFetchingRailways = false
        }
    }

    func clearRailwayRoutes() {
        railwayRoutes = []
        railwayError = nil
    }
}
