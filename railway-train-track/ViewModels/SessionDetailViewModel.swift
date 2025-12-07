//
//  SessionDetailViewModel.swift
//  railway-train-track
//
//  Created by Qiwei Li on 12/6/25.
//

import CoreLocation
import Foundation
import MapKit
import SwiftData
import SwiftUI

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

    // Location playback state (legacy index-based)
    var selectedLocationIndex: Int = 0
    var isPlayingAnimation: Bool = false
    var showPlaybackMarker: Bool = false

    // Time-based playback state
    var playbackDurationSeconds: Double = 30.0  // User-editable total playback duration
    var playbackElapsedTime: Double = 0.0       // Current elapsed time in playback
    var interpolatedCoordinate: CLLocationCoordinate2D?  // Smoothly interpolated position
    var positionUpdateFrequency: TimeInterval = 1.0  // How often to update position during playback

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
    private var timeBasedPlaybackTimer: Timer?

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

    // MARK: - Time-Based Playback Computed Properties

    /// Duration of the original journey in seconds
    var journeyDuration: TimeInterval {
        let points = sortedLocationPoints
        guard let first = points.first?.timestamp,
              let last = points.last?.timestamp else {
            return 0
        }
        return last.timeIntervalSince(first)
    }

    /// Current playback progress (0.0 to 1.0)
    var currentPlaybackProgress: Double {
        guard playbackDurationSeconds > 0 else { return 0 }
        return min(1.0, playbackElapsedTime / playbackDurationSeconds)
    }

    /// Formatted elapsed time display (e.g., "0:15 / 0:30")
    var formattedPlaybackTime: String {
        let elapsed = Int(playbackElapsedTime)
        let total = Int(playbackDurationSeconds)
        return String(format: "%d:%02d / %d:%02d", elapsed / 60, elapsed % 60, total / 60, total % 60)
    }

    /// Formatted original journey duration
    var formattedJourneyDuration: String {
        let duration = journeyDuration
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        let seconds = Int(duration) % 60
        if hours > 0 {
            return String(format: "%dh %dm %ds", hours, minutes, seconds)
        } else if minutes > 0 {
            return String(format: "%dm %ds", minutes, seconds)
        } else {
            return String(format: "%ds", seconds)
        }
    }

    /// Animation duration for smooth transitions between position updates
    var playbackAnimationDuration: Double {
        // Use a portion of the update frequency for smooth animation
        positionUpdateFrequency * 0.8
    }

    /// Traveled coordinates up to the current interpolated position
    var traveledCoordinatesForPlayback: [CLLocationCoordinate2D] {
        let points = sortedLocationPoints
        guard points.count >= 2,
              let journeyStart = points.first?.timestamp else {
            return []
        }

        let targetTimestamp = calculateTargetTimestamp()

        // Collect all points up to the target time
        var coords: [CLLocationCoordinate2D] = []
        for point in points {
            if point.timestamp <= targetTimestamp {
                coords.append(point.coordinate)
            } else {
                break
            }
        }

        // Append interpolated position if different from last point
        if let interpolated = interpolatedCoordinate {
            if coords.isEmpty {
                coords.append(interpolated)
            } else if let last = coords.last,
                      last.latitude != interpolated.latitude || last.longitude != interpolated.longitude {
                coords.append(interpolated)
            }
        }

        return coords
    }

    /// Static markers for the map (start, end, stations)
    var staticMarkers: [TrackingPoint] {
        var markers: [TrackingPoint] = []

        // Start marker
        if let first = sortedLocationPoints.first {
            markers.append(.startMarker(from: first))
        }

        // End marker (always show title since we're using time-based playback)
        if let last = sortedLocationPoints.last, sortedLocationPoints.count > 1 {
            markers.append(.endMarker(from: last, showTitle: true))
        }

        // Station markers
        for event in sortedStationEvents {
            if let station = event.station {
                markers.append(.from(station: station, timestamp: event.timestamp))
            }
        }

        return markers
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

        // Reset to beginning if at the end
        if selectedLocationIndex >= totalLocationPoints - 1 {
            selectedLocationIndex = 0
        }

        isPlayingAnimation = true
        showPlaybackMarker = true

        let interval = 0.3 // ~3 points per second
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
        showPlaybackMarker = true
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
            showPlaybackMarker = false
            // Don't reset index here - marker is hidden anyway
        }
    }

    private func updateMapForCurrentLocation() {
        guard let point = currentLocationPoint else { return }
        mapCameraPosition = .camera(
            MapCamera(centerCoordinate: point.coordinate, distance: 2000)
        )
    }

    // MARK: - Time-Based Playback

    /// Calculate the target timestamp in the original journey based on playback progress
    private func calculateTargetTimestamp() -> Date {
        let points = sortedLocationPoints
        guard let journeyStart = points.first?.timestamp else {
            return Date()
        }

        let targetTimeOffset = journeyDuration * currentPlaybackProgress
        return journeyStart.addingTimeInterval(targetTimeOffset)
    }

    /// Calculate the interpolated coordinate based on elapsed playback time
    func calculateInterpolatedPosition() -> CLLocationCoordinate2D? {
        let points = sortedLocationPoints
        guard points.count >= 2,
              let journeyStart = points.first?.timestamp,
              journeyDuration > 0 else {
            return points.first?.coordinate
        }

        let targetTimestamp = calculateTargetTimestamp()

        // Find the two GPS points to interpolate between
        var beforePoint: LocationPoint?
        var afterPoint: LocationPoint?

        for point in points {
            if point.timestamp <= targetTimestamp {
                beforePoint = point
            }
            if point.timestamp > targetTimestamp {
                afterPoint = point
                break
            }
        }

        // Handle edge cases
        guard let before = beforePoint else {
            return points.first?.coordinate
        }
        guard let after = afterPoint else {
            return points.last?.coordinate
        }

        // Linear interpolation between the two points
        let segmentDuration = after.timestamp.timeIntervalSince(before.timestamp)
        guard segmentDuration > 0 else {
            return before.coordinate
        }

        let segmentProgress = targetTimestamp.timeIntervalSince(before.timestamp) / segmentDuration

        let interpolatedLat = before.latitude + (after.latitude - before.latitude) * segmentProgress
        let interpolatedLon = before.longitude + (after.longitude - before.longitude) * segmentProgress

        return CLLocationCoordinate2D(latitude: interpolatedLat, longitude: interpolatedLon)
    }

    /// Start time-based playback with configurable position update frequency
    /// - Parameter currentPositionUpdateFrequency: How often to update the position (in seconds). Default is 1.0 second.
    func startTimeBasedPlayback(currentPositionUpdateFrequency: TimeInterval = 1.0) {
        guard !sortedLocationPoints.isEmpty else { return }

        // Reset if at end
        if playbackElapsedTime >= playbackDurationSeconds {
            playbackElapsedTime = 0
        }

        isPlayingAnimation = true
        showPlaybackMarker = true
        positionUpdateFrequency = currentPositionUpdateFrequency

        // Use Timer with specified frequency
        timeBasedPlaybackTimer = Timer.scheduledTimer(
            withTimeInterval: currentPositionUpdateFrequency,
            repeats: true
        ) { [weak self] _ in
            self?.updatePlaybackFrame()
        }

        // Initial position update
        interpolatedCoordinate = calculateInterpolatedPosition()
    }

    /// Pause time-based playback
    func pauseTimeBasedPlayback() {
        isPlayingAnimation = false
        timeBasedPlaybackTimer?.invalidate()
        timeBasedPlaybackTimer = nil
    }

    /// Update playback frame (called by Timer at the configured frequency)
    /// Internal for testing purposes
    func updatePlaybackFrame() {
        guard isPlayingAnimation else {
            timeBasedPlaybackTimer?.invalidate()
            timeBasedPlaybackTimer = nil
            return
        }

        // Advance elapsed time by the update frequency
        playbackElapsedTime += positionUpdateFrequency

        // Update interpolated position
        interpolatedCoordinate = calculateInterpolatedPosition()

        // Check if playback is complete
        if playbackElapsedTime >= playbackDurationSeconds {
            playbackElapsedTime = playbackDurationSeconds
            pauseTimeBasedPlayback()
            showPlaybackMarker = false
        }
    }

    /// Seek to a specific time in the playback
    func seekToTime(_ time: Double) {
        playbackElapsedTime = max(0, min(time, playbackDurationSeconds))
        interpolatedCoordinate = calculateInterpolatedPosition()
        showPlaybackMarker = true

        // Update map camera to follow interpolated position
        if let coord = interpolatedCoordinate {
            mapCameraPosition = .camera(
                MapCamera(centerCoordinate: coord, distance: 2000)
            )
        }
    }

    /// Seek to a progress value (0.0 to 1.0)
    func seekToProgress(_ progress: Double) {
        seekToTime(progress * playbackDurationSeconds)
    }

    /// Toggle time-based playback
    func toggleTimeBasedPlayback() {
        if isPlayingAnimation {
            pauseTimeBasedPlayback()
        } else {
            startTimeBasedPlayback()
        }
    }

    /// Seek to the beginning of playback
    func seekToBeginningTimeBased() {
        seekToTime(0)
    }

    /// Seek to the end of playback
    func seekToEndTimeBased() {
        seekToTime(playbackDurationSeconds)
        showPlaybackMarker = false
    }

    // MARK: - Station Playback

    func startStationPlayback() {
        guard !sortedStationEvents.isEmpty else { return }
        isPlayingStationAnimation = true

        // 2 seconds per station
        let interval = 2.0
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
        timeBasedPlaybackTimer?.invalidate()
    }
}
