//
//  StationDataViewModel.swift
//  railway-train-track
//
//  Created by Qiwei Li on 12/7/25.
//
//  Unified ViewModel for station search and railway routes.
//  Uses protocol-based providers for easy server migration in the future.
//

import CoreLocation
import Foundation
import MapKit
import SwiftUI

// MARK: - Protocols for Future Server Migration

protocol StationSearchProviding {
    func search(query: String, region: MKCoordinateRegion) async throws -> [MKMapItem]
}

// MARK: - Railway Route Segment

struct RailwayRouteSegment {
    let coordinates: [CLLocationCoordinate2D]
}

protocol RailwayRouteProviding {
    func fetchRoutes(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) async throws -> [RailwayRouteSegment]
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

// MARK: - OpenRailway Route Provider

final class OpenRailwayProvider: RailwayRouteProviding {
    private let baseURL = "https://routing.openrailrouting.org/route"

    private struct OpenRailwayResponse: Decodable {
        let paths: [OpenRailwayPath]
    }

    private struct OpenRailwayPath: Decodable {
        let points: OpenRailwayPoints
    }

    private struct OpenRailwayPoints: Decodable {
        let coordinates: [[Double]] // [[lon, lat], ...]
    }

    func fetchRoutes(from startCoord: CLLocationCoordinate2D, to endCoord: CLLocationCoordinate2D) async throws -> [RailwayRouteSegment] {
        var components = URLComponents(string: baseURL)
        components?.queryItems = [
            URLQueryItem(name: "point", value: "\(startCoord.latitude),\(startCoord.longitude)"),
            URLQueryItem(name: "point", value: "\(endCoord.latitude),\(endCoord.longitude)"),
            URLQueryItem(name: "profile", value: "all_tracks"),
            URLQueryItem(name: "locale", value: "en"),
            URLQueryItem(name: "elevation", value: "false"),
            URLQueryItem(name: "instructions", value: "false"),
            URLQueryItem(name: "points_encoded", value: "false")
        ]

        guard let url = components?.url else {
            throw URLError(.badURL)
        }

        let (data, response) = try await URLSession.shared.data(from: url)

        if let httpResponse = response as? HTTPURLResponse,
           !(200 ... 299).contains(httpResponse.statusCode)
        {
            throw URLError(.badServerResponse)
        }

        let openRailwayResponse = try JSONDecoder().decode(OpenRailwayResponse.self, from: data)

        guard let firstPath = openRailwayResponse.paths.first else {
            return []
        }

        // Convert [[lon, lat]] to [CLLocationCoordinate2D]
        let coordinates = firstPath.points.coordinates.map { coord in
            CLLocationCoordinate2D(latitude: coord[1], longitude: coord[0])
        }

        return [RailwayRouteSegment(coordinates: coordinates)]
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
        railwayProvider: RailwayRouteProviding = OpenRailwayProvider()
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

        for i in 0 ..< (stations.count - 1) {
            let start = stations[i].coordinate
            let end = stations[i + 1].coordinate

            do {
                let fetchedRoutes = try await railwayProvider.fetchRoutes(from: start, to: end)
                for route in fetchedRoutes {
                    routes.append(route.coordinates)
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
