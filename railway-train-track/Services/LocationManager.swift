//
//  LocationManager.swift
//  railway-train-track
//
//  Created by Qiwei Li on 12/6/25.
//

import Foundation
import CoreLocation

final class LocationManager: NSObject {
    private let manager = CLLocationManager()
    #if os(iOS)
    private var backgroundSession: CLBackgroundActivitySession?
    #endif
    private var updateTask: Task<Void, Never>?
    private var recordingInterval: Double = 1.0
    private var isPaused: Bool = false
    private var accuracyThreshold: Double = 50.0 // meters - filter out locations with accuracy worse than this

    // Callbacks
    var onLocationUpdate: ((CLLocation) -> Void)?
    var onAuthorizationChange: ((CLAuthorizationStatus) -> Void)?
    var onError: ((Error) -> Void)?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = 5.0 // meters - only report location changes >= 5m
        #if os(iOS)
        manager.allowsBackgroundLocationUpdates = true
        manager.pausesLocationUpdatesAutomatically = false
        manager.showsBackgroundLocationIndicator = true
        #endif
    }

    var authorizationStatus: CLAuthorizationStatus {
        manager.authorizationStatus
    }

    func requestAuthorization() {
        #if os(iOS)
        if manager.authorizationStatus == .notDetermined {
            manager.requestWhenInUseAuthorization()
        } else if manager.authorizationStatus == .authorizedWhenInUse {
            manager.requestAlwaysAuthorization()
        }
        #elseif os(macOS)
        if manager.authorizationStatus == .notDetermined {
            manager.requestAlwaysAuthorization()
        }
        #endif
    }

    func startTracking(interval: Double) {
        recordingInterval = interval
        isPaused = false

        #if os(iOS)
        // Start background session for background updates
        backgroundSession = CLBackgroundActivitySession()
        #endif

        // Use new async location updates API
        startLocationUpdates()
    }

    func pauseTracking() {
        isPaused = true
    }

    func resumeTracking() {
        isPaused = false
    }

    func stopTracking() {
        updateTask?.cancel()
        updateTask = nil
        #if os(iOS)
        backgroundSession?.invalidate()
        backgroundSession = nil
        #endif
        isPaused = false
    }

    func updateInterval(_ interval: Double) {
        recordingInterval = max(0.1, min(60.0, interval))
    }

    func updateAccuracyThreshold(_ threshold: Double) {
        accuracyThreshold = max(1.0, min(200.0, threshold))
    }

    func updateDistanceFilter(_ distance: Double) {
        manager.distanceFilter = max(0, min(100.0, distance))
    }

    private func startLocationUpdates() {
        updateTask = Task { [weak self] in
            guard let self = self else { return }

            let updates = CLLocationUpdate.liveUpdates()
            var lastRecordedTime: Date?

            do {
                for try await update in updates {
                    guard !Task.isCancelled else { break }

                    // Skip if paused
                    if self.isPaused { continue }

                    guard let location = update.location else { continue }

                    // Filter out inaccurate locations
                    // horizontalAccuracy < 0 means invalid, > threshold means too inaccurate
                    if location.horizontalAccuracy < 0 || location.horizontalAccuracy > self.accuracyThreshold {
                        continue
                    }

                    // Throttle based on recording interval
                    let now = Date()
                    if let lastTime = lastRecordedTime,
                       now.timeIntervalSince(lastTime) < self.recordingInterval {
                        continue
                    }

                    lastRecordedTime = now

                    await MainActor.run {
                        self.onLocationUpdate?(location)
                    }
                }
            } catch {
                await MainActor.run {
                    self.onError?(error)
                }
            }
        }
    }
}

// MARK: - CLLocationManagerDelegate

extension LocationManager: CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        onAuthorizationChange?(manager.authorizationStatus)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        onError?(error)
    }
}
