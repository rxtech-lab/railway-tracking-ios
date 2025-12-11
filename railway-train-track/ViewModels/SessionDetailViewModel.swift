//
//  SessionDetailViewModel.swift
//  railway-train-track
//
//  Created by Qiwei Li on 12/6/25.
//

import CoreLocation
import Foundation
import MapKit
import QuartzCore
import SwiftData
import SwiftUI

let cameraAnimationDuration: TimeInterval = 0.5

/// Defines the source of route data for playback visualization
enum RouteSourceMode: String, Codable, CaseIterable {
    case gps = "GPS"
    case railway = "Railway"

    var displayName: String {
        rawValue
    }

    var description: String {
        switch self {
        case .gps:
            return "Follow actual GPS location path"
        case .railway:
            return "Follow railway line between stations"
        }
    }
}

enum SessionTab: String, CaseIterable {
    case locations = "Locations"
    case stations = "Stations"
    case notes = "Notes"
}

struct NoteEditorContext: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
    let linkedStationEvent: StationPassEvent?
    let linkedStation: TrainStation?
    let existingNote: SessionNote?

    var isEditing: Bool { existingNote != nil }
}

enum SheetContent: Identifiable {
    case tabBar
    case playbackSettings
    case stationSearch
    case exportCSV
    case exportJSON
    case exportVideo
    case noteEditor(NoteEditorContext)
    case noteDetail(SessionNote)

    var id: String {
        switch self {
        case .tabBar: return "tabBar"
        case .playbackSettings: return "playbackSettings"
        case .stationSearch: return "stationSearch"
        case .exportCSV: return "exportCSV"
        case .exportJSON: return "exportJSON"
        case .exportVideo: return "exportVideo"
        case .noteEditor(let context): return "noteEditor-\(context.id)"
        case .noteDetail(let note): return "noteDetail-\(note.id)"
        }
    }

    var isTabBar: Bool {
        if case .tabBar = self { return true }
        return false
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
    var playbackDurationSeconds: Double {
        get { session.playbackDuration }
        set { session.playbackDuration = newValue }
    }

    var playbackCameraDistance: Double {
        get { session.playbackCameraDistance }
        set { session.playbackCameraDistance = newValue }
    }

    // MARK: - Display Options (proxied from session for persistence)

    var showRailroad: Bool {
        get { session.showRailroad }
        set { session.showRailroad = newValue }
    }

    var showStationMarkers: Bool {
        get { session.showStationMarkers }
        set { session.showStationMarkers = newValue }
    }

    var showGPSLocationMarker: Bool {
        get { session.showGPSLocationMarker }
        set { session.showGPSLocationMarker = newValue }
    }

    var routeSourceMode: RouteSourceMode {
        get { session.routeSourceMode }
        set { session.routeSourceMode = newValue }
    }

    // MARK: - Railway Mode State

    /// The index of the last station passed (for railway mode)
    var currentStationPassIndex: Int = -1

    /// The coordinate of the current station in railway mode
    var currentStationCoordinate: CLLocationCoordinate2D? {
        guard currentStationPassIndex >= 0,
              currentStationPassIndex < sortedStationEvents.count,
              let station = sortedStationEvents[currentStationPassIndex].station
        else { return nil }
        return station.coordinate
    }

    var playbackElapsedTime: Double = 0.0 // Current elapsed time in playback
    var interpolatedCoordinate: CLLocationCoordinate2D? // Smoothly interpolated position
    var traveledCoordinates: [CLLocationCoordinate2D] = [] // Traveled path up to current position
    var positionUpdateFrequency: TimeInterval = 1.0 // How often to update position during playback

    // Sheet state
    var sheetContent: SheetContent = .tabBar

    // Station playback state
    var selectedStationIndex: Int = 0
    var isPlayingStationAnimation: Bool = false

    // Selected station marker for visual feedback
    var selectedStationMarkerId: UUID?

    // Analysis state
    var isAnalyzingStations: Bool = false
    var analysisProgress: Double = 0
    var analysisError: String?

    // Station management state
    var stationToDelete: StationPassEvent?
    var showDeleteConfirmation: Bool = false
    var showRegenerateConfirmation: Bool = false

    // Station data (unified ViewModel for search and railway routes)
    var stationDataViewModel = StationDataViewModel()

    // Map state
    var mapCameraPosition: MapCameraPosition = .automatic
    var cameraTrigger: Int = 0

    // Services
    private let stationService: TrainStationService
    private let analysisService: StationAnalysisService
    private let simplificationService = CoordinateSimplificationService()
    private var modelContext: ModelContext?
    private var playbackTimer: Timer?
    private var stationPlaybackTimer: Timer?
    private var timeBasedPlaybackTimer: Timer?
    private var displayLink: CADisplayLink?
    private var lastDisplayLinkTimestamp: CFTimeInterval = 0
    // Timestamp of last line update
    private var lastTraveledCoordinatesUpdate: CFTimeInterval = 0
    // Timestamp of last camera update
    private var lastCameraUpdate: CFTimeInterval = 0

    // Coordinate simplification cache
    // Key: epsilon value, Value: simplified coordinates
    private var simplifiedCoordinatesCache: [Double: [CLLocationCoordinate2D]] = [:]
    private var currentEpsilon: Double = 0.0001

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
        modelContext = context
    }

    // MARK: - Computed Properties

    var sortedLocationPoints: [LocationPoint] {
        session.sortedLocationPoints
    }

    // MARK: - Simplified Coordinates for Display

    /// Simplified coordinates for map display (based on current zoom level)
    /// Uses Douglas-Peucker algorithm to reduce point count while preserving shape
    var displayCoordinates: [CLLocationCoordinate2D] {
        getSimplifiedCoordinates(for: playbackCameraDistance)
    }

    /// Traveled coordinates for map display during playback
    /// Note: In GPS mode, these are already simplified via displayCoordinates
    var simplifiedTraveledCoordinates: [CLLocationCoordinate2D] {
        traveledCoordinates
    }

    /// Get simplified coordinates from cache or compute them
    private func getSimplifiedCoordinates(for cameraDistance: Double) -> [CLLocationCoordinate2D] {
        let epsilon = CoordinateSimplificationService.SimplificationConfig.epsilon(for: cameraDistance)

        // Return cached version if available
        if let cached = simplifiedCoordinatesCache[epsilon] {
            return cached
        }

        // Compute and cache
        let fullCoordinates = session.coordinates
        let simplified = simplificationService.simplify(coordinates: fullCoordinates, epsilon: epsilon)
        simplifiedCoordinatesCache[epsilon] = simplified
        return simplified
    }

    /// Invalidate the coordinate cache (call when session data changes)
    func invalidateCoordinateCache() {
        simplifiedCoordinatesCache.removeAll()
    }

    /// Handle camera distance changes to update epsilon if needed
    func handleCameraDistanceChange(_ newDistance: Double) {
        let newEpsilon = CoordinateSimplificationService.SimplificationConfig.epsilon(for: newDistance)
        if newEpsilon != currentEpsilon {
            currentEpsilon = newEpsilon
            // Cache will be populated lazily on next displayCoordinates access
        }
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
              let last = points.last?.timestamp
        else {
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

    /// Calculate traveled coordinates based on current route source mode
    private func calculateTraveledCoordinates() -> [CLLocationCoordinate2D] {
        switch routeSourceMode {
        case .gps:
            return calculateGPSTraveledCoordinates()
        case .railway:
            return calculateRailwayTraveledCoordinates()
        }
    }

    /// GPS-based traveled coordinates using simplified path
    private func calculateGPSTraveledCoordinates() -> [CLLocationCoordinate2D] {
        let simplified = displayCoordinates
        guard simplified.count >= 2 else { return simplified }

        // Calculate the index position based on playback progress
        let progress = currentPlaybackProgress
        let maxIndex = Double(simplified.count - 1)
        let exactIndex = progress * maxIndex
        let floorIndex = Int(exactIndex)

        // Collect all simplified points up to and including floorIndex
        var coords: [CLLocationCoordinate2D] = []
        for i in 0 ... min(floorIndex, simplified.count - 1) {
            coords.append(simplified[i])
        }

        // Append interpolated position if different from last point
        if let interpolated = interpolatedCoordinate {
            if coords.isEmpty {
                coords.append(interpolated)
            } else if let last = coords.last,
                      last.latitude != interpolated.latitude || last.longitude != interpolated.longitude
            {
                coords.append(interpolated)
            }
        }

        return coords
    }

    /// Railway-based traveled coordinates
    private func calculateRailwayTraveledCoordinates() -> [CLLocationCoordinate2D] {
        // Update current station pass index based on playback progress
        updateCurrentStationPassIndex()

        guard currentStationPassIndex >= 0 else { return [] }

        // Collect railway segments up to (and including) the current station
        var coords: [CLLocationCoordinate2D] = []

        // Get stations passed so far
        let passedStations = Array(sortedStationEvents.prefix(currentStationPassIndex + 1))
        let passedStationCoords = passedStations.compactMap { $0.station?.coordinate }

        // For each railway route segment, check if it connects passed stations
        for route in stationDataViewModel.railwayRoutes {
            if shouldIncludeRailwaySegment(route, forPassedStations: passedStationCoords) {
                coords.append(contentsOf: route)
            }
        }

        return coords
    }

    /// Update the current station pass index based on playback timestamp
    private func updateCurrentStationPassIndex() {
        let targetTimestamp = calculateTargetTimestamp()
        let events = sortedStationEvents

        // Find the last station event that has been passed
        var lastPassedIndex = -1
        for (index, event) in events.enumerated() {
            if event.timestamp <= targetTimestamp {
                lastPassedIndex = index
            } else {
                break
            }
        }

        currentStationPassIndex = lastPassedIndex
    }

    /// Determine if a railway segment should be included based on passed stations
    private func shouldIncludeRailwaySegment(
        _ segment: [CLLocationCoordinate2D],
        forPassedStations passedStations: [CLLocationCoordinate2D]
    ) -> Bool {
        guard !segment.isEmpty, !passedStations.isEmpty else { return false }

        // A segment is included if its endpoints are near any of the passed stations
        let threshold: CLLocationDistance = 500 // meters

        let segmentStart = CLLocation(latitude: segment.first!.latitude, longitude: segment.first!.longitude)
        let segmentEnd = CLLocation(latitude: segment.last!.latitude, longitude: segment.last!.longitude)

        var startsNearStation = false
        var endsNearStation = false

        for stationCoord in passedStations {
            let stationLocation = CLLocation(latitude: stationCoord.latitude, longitude: stationCoord.longitude)
            if segmentStart.distance(from: stationLocation) < threshold {
                startsNearStation = true
            }
            if segmentEnd.distance(from: stationLocation) < threshold {
                endsNearStation = true
            }
        }

        return startsNearStation && endsNearStation
    }

    /// Static markers for the map (start, end, stations, notes)
    var staticMarkers: [TrackingPoint] {
        var markers: [TrackingPoint] = []

        // Start marker (always show)
        if let first = sortedLocationPoints.first {
            markers.append(.startMarker(from: first))
        }

        // End marker (always show title since we're using time-based playback)
        if let last = sortedLocationPoints.last, sortedLocationPoints.count > 1 {
            markers.append(.endMarker(from: last, showTitle: true))
        }

        // Station markers (only if showStationMarkers is enabled)
        if showStationMarkers {
            for event in sortedStationEvents {
                if let station = event.station {
                    var marker = TrackingPoint.from(station: station, timestamp: event.timestamp, eventId: event.id)
                    marker.isSelected = (event.id == selectedStationMarkerId)
                    markers.append(marker)
                }
            }
        }

        // Note markers
        for note in sortedNotes {
            markers.append(.from(note: note))
        }

        return markers
    }

    /// Sorted notes for the session
    var sortedNotes: [SessionNote] {
        session.sortedNotes
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

    func pausePlayback() {
        isPlayingAnimation = false
        playbackTimer?.invalidate()
        playbackTimer = nil
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

    private func updateMapForCurrentLocation() {
        guard let point = currentLocationPoint else { return }
        mapCameraPosition = .camera(
            MapCamera(centerCoordinate: point.coordinate, distance: playbackCameraDistance)
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

    /// Calculate the interpolated coordinate based on elapsed playback time and route source mode
    func calculateInterpolatedPosition() -> CLLocationCoordinate2D? {
        switch routeSourceMode {
        case .gps:
            return calculateGPSInterpolatedPosition()
        case .railway:
            return calculateRailwayInterpolatedPosition()
        }
    }

    /// GPS-based interpolation using simplified coordinates
    private func calculateGPSInterpolatedPosition() -> CLLocationCoordinate2D? {
        let simplified = displayCoordinates
        guard simplified.count >= 2 else {
            return simplified.first
        }

        // Use playback progress to determine position along simplified path
        let progress = currentPlaybackProgress
        let maxIndex = Double(simplified.count - 1)
        let exactIndex = progress * maxIndex

        // Get the two points to interpolate between
        let floorIndex = Int(exactIndex)
        let ceilIndex = min(floorIndex + 1, simplified.count - 1)

        // Handle edge cases
        if floorIndex >= simplified.count - 1 {
            return simplified.last
        }

        let before = simplified[floorIndex]
        let after = simplified[ceilIndex]

        // Calculate interpolation factor within the segment
        let segmentProgress = exactIndex - Double(floorIndex)

        // Linear interpolation between the two simplified points
        let interpolatedLat = before.latitude + (after.latitude - before.latitude) * segmentProgress
        let interpolatedLon = before.longitude + (after.longitude - before.longitude) * segmentProgress

        return CLLocationCoordinate2D(latitude: interpolatedLat, longitude: interpolatedLon)
    }

    /// Railway mode: snap to current station coordinate
    /// If user's position leaves the railway, keep position at the last station
    private func calculateRailwayInterpolatedPosition() -> CLLocationCoordinate2D? {
        updateCurrentStationPassIndex()

        // Return the current station coordinate (snap to station)
        // If no station has been passed yet, return first station
        if currentStationPassIndex < 0 {
            return sortedStationEvents.first?.station?.coordinate
        }

        return currentStationCoordinate
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

        // Initial position and traveled path update
        interpolatedCoordinate = calculateInterpolatedPosition()
        traveledCoordinates = calculateTraveledCoordinates()

        // Use DisplayLink for smooth 60fps animation
        lastDisplayLinkTimestamp = 0
        displayLink = CADisplayLink(target: self, selector: #selector(displayLinkUpdate))
        displayLink?.add(to: .main, forMode: .common)
    }

    private func stopDisplayLink() {
        displayLink?.invalidate()
        displayLink = nil
        lastDisplayLinkTimestamp = 0
    }

    /// Pause time-based playback
    func pauseTimeBasedPlayback() {
        isPlayingAnimation = false
        stopDisplayLink()
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
        traveledCoordinates = calculateTraveledCoordinates()
        showPlaybackMarker = true

        // Update map camera to follow interpolated position
        if let coord = interpolatedCoordinate {
            mapCameraPosition = .camera(
                MapCamera(centerCoordinate: coord, distance: playbackCameraDistance)
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
            MapCamera(centerCoordinate: station.coordinate, distance: playbackCameraDistance)
        )
    }

    // MARK: - Railway Routes

    func fetchRailwayRoutes() async {
        let stations = sortedStationEvents.compactMap { $0.station }
        await stationDataViewModel.fetchRailwayRoutes(between: stations)
    }

    // MARK: - Station Analysis

    func analyzeStations() async {
        isAnalyzingStations = true
        analysisProgress = 0
        analysisError = nil

        // Clear existing station pass events to prevent duplicates
        for event in session.stationPassEvents {
            modelContext?.delete(event)
        }
        session.stationPassEvents.removeAll()

        do {
            // Fetch stations along route
            await MainActor.run { analysisProgress = 0.2 }

            let stations = try await stationService.fetchStationsAlongRoute(
                coordinates: session.coordinates,
                radiusMeters: 500
            )

            let deduplicatedStations = TrainStationService.deduplicateByName(stations)

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
                for station in deduplicatedStations {
                    print("Station name: \(station.name ?? "Unknown")")
                    context.insert(station)
                }
                for event in passEvents {
                    event.session = session
                    session.stationPassEvents.append(event)
                }

                try context.save()
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

    func resetStationAnalysis() {
        // Clear existing station pass events
        for event in session.stationPassEvents {
            modelContext?.delete(event)
        }
        session.stationPassEvents.removeAll()

        // Reset flags
        session.stationAnalysisCompleted = false
        session.stationAnalysisTimestamp = nil
        analysisError = nil

        try? modelContext?.save()
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

    func confirmRegenerateStations() {
        showRegenerateConfirmation = true
    }

    func executeRegenerateStations() async {
        resetStationAnalysis()
        await analyzeStations()
    }

    func addStationFromMapItem(_ mapItem: MKMapItem) {
        guard let context = modelContext,
              let coordinate = mapItem.placemark.location?.coordinate else { return }

        // Create or find TrainStation
        let station = TrainStation(
            osmId: Int64(mapItem.hash), // Use hash as pseudo-ID for Apple Maps results
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
            displayOrder: sortedStationEvents.count // Add at end
        )
        event.station = station
        event.session = session
        session.stationPassEvents.append(event)

        try? context.save()
    }

    func calculateSearchRegion() -> MKCoordinateRegion {
        calculateRegion(for: session.coordinates)
    }

    // MARK: - Note Management

    func addNoteAtCurrentPlaybackPosition() {
        guard let coord = interpolatedCoordinate ?? sortedLocationPoints.first?.coordinate else { return }
        let context = NoteEditorContext(
            coordinate: coord,
            linkedStationEvent: nil,
            linkedStation: nil,
            existingNote: nil
        )
        sheetContent = .noteEditor(context)
    }

    func addNoteAtCoordinate(_ coordinate: CLLocationCoordinate2D) {
        let context = NoteEditorContext(
            coordinate: coordinate,
            linkedStationEvent: nil,
            linkedStation: nil,
            existingNote: nil
        )
        sheetContent = .noteEditor(context)
    }

    func addNoteForStation(_ event: StationPassEvent) {
        guard let station = event.station else { return }

        // Set selected marker for visual feedback
        selectedStationMarkerId = event.id

        // Check if note already exists for this station
        if let existingNote = sortedNotes.first(where: { $0.linkedStationEventId == event.id }) {
            sheetContent = .noteDetail(existingNote)
        } else {
            let context = NoteEditorContext(
                coordinate: station.coordinate,
                linkedStationEvent: event,
                linkedStation: station,
                existingNote: nil
            )
            sheetContent = .noteEditor(context)
        }
    }

    func editNote(_ note: SessionNote) {
        let context = NoteEditorContext(
            coordinate: note.coordinate,
            linkedStationEvent: nil,
            linkedStation: note.linkedStation,
            existingNote: note
        )
        sheetContent = .noteEditor(context)
    }

    func clearStationSelection() {
        selectedStationMarkerId = nil
    }

    func viewNoteDetail(_ note: SessionNote) {
        sheetContent = .noteDetail(note)
    }

    func handleMarkerTap(_ marker: TrackingPoint) {
        switch marker.type {
        case .trainStation:
            // Find the station event and show note editor
            if let event = sortedStationEvents.first(where: { $0.id == marker.id }) {
                addNoteForStation(event)
            }
        case .note:
            // Show existing note detail
            if let note = sortedNotes.first(where: { $0.id == marker.id }) {
                sheetContent = .noteDetail(note)
            }
        default:
            break
        }
    }

    func handleMapLongPress(_ coordinate: CLLocationCoordinate2D) {
        addNoteAtCoordinate(coordinate)
    }

    func deleteNote(_ note: SessionNote) {
        session.notes.removeAll { $0.id == note.id }
        modelContext?.delete(note)
        try? modelContext?.save()
    }

    func deleteNotes(at indexSet: IndexSet) {
        let notesToDelete = indexSet.map { sortedNotes[$0] }
        for note in notesToDelete {
            deleteNote(note)
        }
    }

    // MARK: - Cleanup

    deinit {
        playbackTimer?.invalidate()
        stationPlaybackTimer?.invalidate()
        timeBasedPlaybackTimer?.invalidate()
        displayLink?.invalidate()
    }
}

// MARK: Display link animation

extension SessionDetailViewModel {
    @objc private func displayLinkUpdate(_ link: CADisplayLink) {
        guard isPlayingAnimation else {
            stopDisplayLink()
            return
        }

        // Calculate delta time
        let deltaTime: Double
        if lastDisplayLinkTimestamp == 0 {
            deltaTime = link.targetTimestamp - link.timestamp
        } else {
            deltaTime = link.targetTimestamp - lastDisplayLinkTimestamp
        }
        lastDisplayLinkTimestamp = link.targetTimestamp

        // Advance elapsed time
        playbackElapsedTime += deltaTime

        // Check completion
        if playbackElapsedTime >= playbackDurationSeconds {
            playbackElapsedTime = playbackDurationSeconds
            interpolatedCoordinate = calculateInterpolatedPosition()
            traveledCoordinates = calculateTraveledCoordinates()
            cameraTrigger += 1 // Trigger final camera animation
            pauseTimeBasedPlayback()
            showPlaybackMarker = false
            return
        }

        // Update position every frame for smooth marker movement
        interpolatedCoordinate = calculateInterpolatedPosition()

        // Update traveled path and trigger camera animation periodically
        if link.timestamp - lastTraveledCoordinatesUpdate > 0.2 {
            traveledCoordinates = calculateTraveledCoordinates()
            lastTraveledCoordinatesUpdate = link.timestamp
        }

        // give some time for the animation to complete before triggering another
        if link.timestamp - lastCameraUpdate > cameraAnimationDuration + 0.1 {
            cameraTrigger += 1
            lastCameraUpdate = link.timestamp
        }
    }
}
