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
    private var backgroundSession: CLBackgroundActivitySession?
    private var updateTask: Task<Void, Never>?
    private var recordingInterval: Double = 1.0
    private var isPaused: Bool = false

    // Callbacks
    var onLocationUpdate: ((CLLocation) -> Void)?
    var onAuthorizationChange: ((CLAuthorizationStatus) -> Void)?
    var onError: ((Error) -> Void)?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.allowsBackgroundLocationUpdates = true
        manager.pausesLocationUpdatesAutomatically = false
        manager.showsBackgroundLocationIndicator = true
    }

    var authorizationStatus: CLAuthorizationStatus {
        manager.authorizationStatus
    }

    func requestAuthorization() {
        if manager.authorizationStatus == .notDetermined {
            manager.requestWhenInUseAuthorization()
        } else if manager.authorizationStatus == .authorizedWhenInUse {
            manager.requestAlwaysAuthorization()
        }
    }

    func startTracking(interval: Double) {
        recordingInterval = interval
        isPaused = false

        // Start background session for background updates
        backgroundSession = CLBackgroundActivitySession()

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
        backgroundSession?.invalidate()
        backgroundSession = nil
        isPaused = false
    }

    func updateInterval(_ interval: Double) {
        recordingInterval = max(0.1, min(60.0, interval))
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
