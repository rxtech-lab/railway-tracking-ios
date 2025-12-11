//
//  TrackingViewModel.swift
//  railway-train-track
//
//  Created by Qiwei Li on 12/6/25.
//

import CoreLocation
import Foundation
import SwiftData
import SwiftUI

@Observable
final class TrackingViewModel {
    // State
    var isTracking: Bool = false
    var isPaused: Bool = false
    var currentSession: TrackingSession?
    var recordingInterval: Double = 1.0 // Default 1 second
    var locationAuthorizationStatus: CLAuthorizationStatus = .notDetermined
    var lastLocation: CLLocation?
    var errorMessage: String?
    var pointCount: Int = 0

    // Recoverable session state
    var hasRecoverableSession: Bool = false
    var recoverableSession: TrackingSession?

    // Persisted active session ID (survives app restart)
    @ObservationIgnored
    @AppStorage("activeSessionId") private var activeSessionIdString: String = ""

    private var activeSessionId: UUID? {
        get { UUID(uuidString: activeSessionIdString) }
        set { activeSessionIdString = newValue?.uuidString ?? "" }
    }

    // Dependencies
    private let locationManager: LocationManager
    private var modelContext: ModelContext?

    init(locationManager: LocationManager = LocationManager()) {
        self.locationManager = locationManager
        self.locationAuthorizationStatus = locationManager.authorizationStatus
        setupLocationCallbacks()
    }

    func setModelContext(_ context: ModelContext) {
        modelContext = context
    }

    private func setupLocationCallbacks() {
        locationManager.onLocationUpdate = { [weak self] location in
            self?.handleNewLocation(location)
        }
        locationManager.onAuthorizationChange = { [weak self] status in
            self?.locationAuthorizationStatus = status
        }
        locationManager.onError = { [weak self] error in
            self?.errorMessage = error.localizedDescription
        }
    }

    // MARK: - Authorization

    func requestLocationPermission() {
        locationManager.requestAuthorization()
    }

    var canTrack: Bool {
        #if os(iOS)
        return locationAuthorizationStatus == .authorizedAlways ||
            locationAuthorizationStatus == .authorizedWhenInUse
        #else
        return locationAuthorizationStatus == .authorizedAlways
        #endif
    }

    var hasActiveSession: Bool {
        isTracking && currentSession != nil
    }

    var authorizationMessage: String {
        switch locationAuthorizationStatus {
        case .notDetermined:
            return "Location permission required"
        case .restricted:
            return "Location access is restricted"
        case .denied:
            return "Location access denied. Please enable in Settings."
        #if os(iOS)
        case .authorizedWhenInUse:
            return "For background tracking, please allow 'Always' access"
        #endif
        case .authorizedAlways:
            return "Ready to track"
        @unknown default:
            return "Unknown authorization status"
        }
    }

    // MARK: - Session Control

    func startNewSession(name: String = "") {
        guard let context = modelContext else {
            errorMessage = "Model context not available"
            return
        }

        let session = TrackingSession(
            name: name,
            recordingInterval: recordingInterval
        )
        context.insert(session)
        currentSession = session
        pointCount = 0

        // Store session ID for recovery on app restart
        activeSessionId = session.id

        isTracking = true
        isPaused = false
        locationManager.startTracking(interval: recordingInterval)

        // Clear recoverable session state
        hasRecoverableSession = false
        recoverableSession = nil

        try? context.save()
    }

    func pauseSession() {
        isPaused = true
        locationManager.pauseTracking()
    }

    func resumeSession() {
        isPaused = false
        locationManager.resumeTracking()
    }

    func stopSession() {
        currentSession?.endTime = Date()
        currentSession?.isActive = false
        calculateSessionStats()

        isTracking = false
        isPaused = false
        locationManager.stopTracking()

        // Clear stored session ID
        activeSessionId = nil

        try? modelContext?.save()
        currentSession = nil
    }

    func clearSessionIfDeleted(_ session: TrackingSession) {
        // Clear tracking state if this is the current session
        if currentSession?.id == session.id {
            isTracking = false
            isPaused = false
            currentSession = nil
            activeSessionId = nil
            locationManager.stopTracking()
        }

        // Clear recovery state if this is the recoverable session
        if recoverableSession?.id == session.id {
            hasRecoverableSession = false
            recoverableSession = nil
            activeSessionId = nil
        }
    }

    private func handleNewLocation(_ location: CLLocation) {
        guard isTracking, !isPaused, let session = currentSession else { return }

        let point = LocationPoint(from: location)
        point.session = session
        session.locationPoints.append(point)
        lastLocation = location
        pointCount = session.locationPoints.count

        // Save periodically (every 10 points)
        if pointCount % 10 == 0 {
            try? modelContext?.save()
        }
    }

    private func calculateSessionStats() {
        guard let session = currentSession else { return }
        let points = session.sortedLocationPoints

        // Calculate total distance
        var totalDistance: Double = 0
        for i in 1..<points.count {
            let prev = points[i - 1].clLocation
            let curr = points[i].clLocation
            totalDistance += curr.distance(from: prev)
        }
        session.totalDistance = totalDistance

        // Calculate average speed
        if session.duration > 0 {
            session.averageSpeed = totalDistance / session.duration
        }
    }

    // MARK: - Route Data

    var sampledRouteCoordinates: [CLLocationCoordinate2D] {
        guard let session = currentSession else { return [] }
        let coords = session.coordinates
        guard coords.count > 1 else { return coords }

        let maxPoints = 100
        if coords.count <= maxPoints {
            return coords
        }

        // Sample evenly, always include last point (current location)
        let step = Double(coords.count - 1) / Double(maxPoints - 1)
        var sampled: [CLLocationCoordinate2D] = []
        for i in 0..<(maxPoints - 1) {
            let index = Int(Double(i) * step)
            sampled.append(coords[index])
        }
        sampled.append(coords.last!)
        return sampled
    }

    var recentRouteCoordinates: [CLLocationCoordinate2D] {
        guard let session = currentSession else { return [] }
        let coords = session.coordinates
        return Array(coords.suffix(20))
    }

    // MARK: - Settings

    func updateRecordingInterval(_ interval: Double) {
        recordingInterval = max(0.1, min(60.0, interval))
        if isTracking, !isPaused {
            locationManager.updateInterval(recordingInterval)
        }
    }

    // MARK: - Session Recovery

    func checkForRecoverableSession() {
        guard let sessionId = activeSessionId,
              let context = modelContext
        else {
            return
        }

        // Query SwiftData for the session
        let descriptor = FetchDescriptor<TrackingSession>(
            predicate: #Predicate { session in
                session.id == sessionId && session.isActive
            }
        )

        do {
            let sessions = try context.fetch(descriptor)
            if let session = sessions.first {
                recoverableSession = session
                hasRecoverableSession = true
                pointCount = session.locationPoints.count
            } else {
                // Session not found or no longer active, clear stored ID
                activeSessionId = nil
                hasRecoverableSession = false
                recoverableSession = nil
            }
        } catch {
            errorMessage = "Failed to check for recoverable session: \(error.localizedDescription)"
        }
    }

    func resumeRecoveredSession() {
        guard let session = recoverableSession else { return }

        currentSession = session
        pointCount = session.locationPoints.count
        recordingInterval = session.recordingInterval

        isTracking = true
        isPaused = false
        locationManager.startTracking(interval: recordingInterval)

        hasRecoverableSession = false
        recoverableSession = nil
    }

    func discardRecoveredSession() {
        // Optionally mark session as ended
        if let session = recoverableSession {
            session.endTime = Date()
            session.isActive = false
            try? modelContext?.save()
        }

        activeSessionId = nil
        hasRecoverableSession = false
        recoverableSession = nil
    }

    func dismissRecoveryPrompt() {
        // Clear UI state only - session stays active for next app launch
        hasRecoverableSession = false
        recoverableSession = nil
        // Keep activeSessionId so it prompts again on next launch
    }

    // MARK: - Resume Finished Session

    func resumeFinishedSession(_ session: TrackingSession) {
        guard let context = modelContext else {
            errorMessage = "Model context not available"
            return
        }

        // Reactivate the session
        session.isActive = true
        session.endTime = nil
        currentSession = session
        pointCount = session.locationPoints.count
        recordingInterval = session.recordingInterval

        // Store session ID for recovery
        activeSessionId = session.id

        isTracking = true
        isPaused = false
        locationManager.startTracking(interval: recordingInterval)

        // Clear any recoverable session state
        hasRecoverableSession = false
        recoverableSession = nil

        try? context.save()
    }
}
