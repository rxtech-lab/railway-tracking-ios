//
//  SessionDetailViewModel.swift
//  railway-train-track
//
//  Created by Qiwei Li on 12/6/25.
//

import Foundation
import SwiftUI
import SwiftData
import MapKit

enum SessionTab: String, CaseIterable {
    case locations = "Locations"
    case stations = "Stations"
}

enum SheetContent: Identifiable {
    case tabBar
    case playbackSettings
    case stationSearch
    case exportCSV
    case exportJSON
    case exportVideo

    var id: String {
        switch self {
        case .tabBar: return "tabBar"
        case .playbackSettings: return "playbackSettings"
        case .stationSearch: return "stationSearch"
        case .exportCSV: return "exportCSV"
        case .exportJSON: return "exportJSON"
        case .exportVideo: return "exportVideo"
        }
    }
}

@Observable
final class SessionDetailViewModel {
    // Session
    var session: TrackingSession

    // Tab state
    var selectedTab: SessionTab = .locations

    // Location playback state
    var selectedLocationIndex: Int = 0
    var isPlayingAnimation: Bool = false
    var playbackSpeed: Double = 1.0

    // Sheet state
    var sheetContent: SheetContent = .tabBar

    // Station playback state
    var selectedStationIndex: Int = 0
    var isPlayingStationAnimation: Bool = false

    // Analysis state
    var isAnalyzingStations: Bool = false
    var analysisProgress: Double = 0
    var analysisError: String?

    // Station management state
    var stationToDelete: StationPassEvent?
    var showDeleteConfirmation: Bool = false

    // Station data (unified ViewModel for search and railway routes)
    var stationDataViewModel = StationDataViewModel()

    // Map state
    var mapCameraPosition: MapCameraPosition = .automatic

    // Services
    private let stationService: TrainStationService
    private let analysisService: StationAnalysisService
    private var modelContext: ModelContext?
    private var playbackTimer: Timer?
    private var stationPlaybackTimer: Timer?

    init(
        session: TrackingSession,
        stationService: TrainStationService = TrainStationService(),
        analysisService: StationAnalysisService = StationAnalysisService()
    ) {
        self.session = session
        self.stationService = stationService
        self.analysisService = analysisService
        setupInitialMapRegion()
    }

    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
    }

    // MARK: - Computed Properties

    var sortedLocationPoints: [LocationPoint] {
        session.sortedLocationPoints
    }

    var sortedStationEvents: [StationPassEvent] {
        session.stationPassEvents.sorted {
            // First by displayOrder, then by timestamp as fallback
            if $0.displayOrder != $1.displayOrder {
                return $0.displayOrder < $1.displayOrder
            }
            return $0.timestamp < $1.timestamp
        }
    }

    var currentLocationPoint: LocationPoint? {
        let points = sortedLocationPoints
        guard selectedLocationIndex < points.count else { return nil }
        return points[selectedLocationIndex]
    }

    var totalLocationPoints: Int {
        session.locationPoints.count
    }

    var playbackProgress: Double {
        guard totalLocationPoints > 1 else { return 0 }
        return Double(selectedLocationIndex) / Double(totalLocationPoints - 1)
    }

    var currentStationEvent: StationPassEvent? {
        let events = sortedStationEvents
        guard selectedStationIndex < events.count else { return nil }
        return events[selectedStationIndex]
    }

    var totalStations: Int {
        sortedStationEvents.count
    }

    // MARK: - Map Region

    private func setupInitialMapRegion() {
        let coordinates = session.coordinates
        guard !coordinates.isEmpty else { return }

        let region = calculateRegion(for: coordinates)
        mapCameraPosition = .region(region)
    }

    private func calculateRegion(for coordinates: [CLLocationCoordinate2D]) -> MKCoordinateRegion {
        guard !coordinates.isEmpty else {
            return MKCoordinateRegion()
        }

        var minLat = coordinates[0].latitude
        var maxLat = coordinates[0].latitude
        var minLon = coordinates[0].longitude
        var maxLon = coordinates[0].longitude

        for coord in coordinates {
            minLat = min(minLat, coord.latitude)
            maxLat = max(maxLat, coord.latitude)
            minLon = min(minLon, coord.longitude)
            maxLon = max(maxLon, coord.longitude)
        }

        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )

        let span = MKCoordinateSpan(
            latitudeDelta: max(0.01, (maxLat - minLat) * 1.3),
            longitudeDelta: max(0.01, (maxLon - minLon) * 1.3)
        )

        return MKCoordinateRegion(center: center, span: span)
    }

    // MARK: - Playback Animation

    func startPlayback() {
        guard !sortedLocationPoints.isEmpty else { return }
        isPlayingAnimation = true

        let interval = (1.0 / playbackSpeed) * 0.1 // 10 points per second at 1x speed
        playbackTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.advancePlayback()
        }
    }

    func pausePlayback() {
        isPlayingAnimation = false
        playbackTimer?.invalidate()
        playbackTimer = nil
    }

    func togglePlayback() {
        if isPlayingAnimation {
            pausePlayback()
        } else {
            startPlayback()
        }
    }

    func seekTo(index: Int) {
        selectedLocationIndex = max(0, min(index, totalLocationPoints - 1))
        updateMapForCurrentLocation()
    }

    func seekToBeginning() {
        seekTo(index: 0)
    }

    func seekToEnd() {
        seekTo(index: totalLocationPoints - 1)
    }

    private func advancePlayback() {
        if selectedLocationIndex < totalLocationPoints - 1 {
            selectedLocationIndex += 1
            // Camera animation handled by mapCameraKeyframeAnimator in view
        } else {
            pausePlayback()
            selectedLocationIndex = 0
        }
    }

    private func updateMapForCurrentLocation() {
        guard let point = currentLocationPoint else { return }
        mapCameraPosition = .camera(
            MapCamera(centerCoordinate: point.coordinate, distance: 2000)
        )
    }

    // MARK: - Station Playback

    func startStationPlayback() {
        guard !sortedStationEvents.isEmpty else { return }
        isPlayingStationAnimation = true

        // 2 seconds per station at 1x speed
        let interval = 2.0 / playbackSpeed
        stationPlaybackTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.advanceStationPlayback()
        }
    }

    func pauseStationPlayback() {
        isPlayingStationAnimation = false
        stationPlaybackTimer?.invalidate()
        stationPlaybackTimer = nil
    }

    func toggleStationPlayback() {
        if isPlayingStationAnimation {
            pauseStationPlayback()
        } else {
            startStationPlayback()
        }
    }

    func seekToStation(index: Int) {
        selectedStationIndex = max(0, min(index, totalStations - 1))
        updateMapForCurrentStation()
    }

    func seekToFirstStation() {
        seekToStation(index: 0)
    }

    func seekToLastStation() {
        seekToStation(index: totalStations - 1)
    }

    private func advanceStationPlayback() {
        if selectedStationIndex < totalStations - 1 {
            selectedStationIndex += 1
            updateMapForCurrentStation()
        } else {
            pauseStationPlayback()
            selectedStationIndex = 0
        }
    }

    private func updateMapForCurrentStation() {
        guard let event = currentStationEvent,
              let station = event.station else { return }
        mapCameraPosition = .camera(
            MapCamera(centerCoordinate: station.coordinate, distance: 5000)
        )
    }

    // MARK: - Railway Routes

    func fetchRailwayRoutes() async {
        let stations = sortedStationEvents.compactMap { $0.station }
        await stationDataViewModel.fetchRailwayRoutes(between: stations)
    }

    // MARK: - Station Analysis

    func analyzeStations() async {
        guard !session.stationAnalysisCompleted else { return }

        isAnalyzingStations = true
        analysisProgress = 0
        analysisError = nil

        do {
            // Fetch stations along route
            await MainActor.run { analysisProgress = 0.2 }

            let stations = try await stationService.fetchStationsAlongRoute(
                coordinates: session.coordinates,
                radiusMeters: 500
            )

            await MainActor.run { analysisProgress = 0.5 }

            // Analyze pass events
            let passEvents = analysisService.detectStationPasses(
                locationPoints: sortedLocationPoints,
                stations: stations,
                proximityThreshold: 200
            )

            await MainActor.run { analysisProgress = 0.8 }

            // Save to SwiftData
            if let context = modelContext {
                for station in stations {
                    context.insert(station)
                }
                for event in passEvents {
                    event.session = session
                    session.stationPassEvents.append(event)
                }

                session.stationAnalysisCompleted = true
                session.stationAnalysisTimestamp = Date()
                try context.save()
            }

            await MainActor.run { analysisProgress = 1.0 }
        } catch {
            await MainActor.run {
                analysisError = error.localizedDescription
            }
        }

        await MainActor.run {
            isAnalyzingStations = false
        }
    }

    // MARK: - Station Management

    func moveStationEvents(from source: IndexSet, to destination: Int) {
        var events = sortedStationEvents
        events.move(fromOffsets: source, toOffset: destination)

        // Update displayOrder for all events
        for (index, event) in events.enumerated() {
            event.displayOrder = index
        }

        try? modelContext?.save()
    }

    func confirmDeleteStation(_ event: StationPassEvent) {
        stationToDelete = event
        showDeleteConfirmation = true
    }

    func executeDeleteStation() {
        guard let event = stationToDelete else { return }
        deleteStationEvent(event)
        stationToDelete = nil
    }

    func deleteStationEvent(_ event: StationPassEvent) {
        session.stationPassEvents.removeAll { $0.id == event.id }
        modelContext?.delete(event)
        try? modelContext?.save()
    }

    func addStationFromMapItem(_ mapItem: MKMapItem) {
        guard let context = modelContext,
              let coordinate = mapItem.placemark.location?.coordinate else { return }

        // Create or find TrainStation
        let station = TrainStation(
            osmId: Int64(mapItem.hash),  // Use hash as pseudo-ID for Apple Maps results
            name: mapItem.name ?? "Unknown Station",
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            stationType: "station"
        )
        context.insert(station)

        // Create StationPassEvent (manual addition)
        let event = StationPassEvent(
            timestamp: Date(),
            distanceFromStation: 0,
            entryPointIndex: selectedLocationIndex,
            displayOrder: sortedStationEvents.count  // Add at end
        )
        event.station = station
        event.session = session
        session.stationPassEvents.append(event)

        try? context.save()
    }

    func calculateSearchRegion() -> MKCoordinateRegion {
        calculateRegion(for: session.coordinates)
    }

    // MARK: - Cleanup

    deinit {
        playbackTimer?.invalidate()
        stationPlaybackTimer?.invalidate()
    }
}
