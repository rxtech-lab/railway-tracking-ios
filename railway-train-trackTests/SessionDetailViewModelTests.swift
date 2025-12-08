//
//  SessionDetailViewModelTests.swift
//  railway-train-trackTests
//
//  Created by Qiwei Li on 12/8/25.
//

@testable import railway_train_track
import CoreLocation
import Testing

@MainActor
struct SessionDetailViewModelTests {
    // MARK: - Helper Functions

    /// Create a session with location points for testing
    private func createSessionWithPoints(count: Int, intervalSeconds: TimeInterval = 1.0) -> TrackingSession {
        let session = TrackingSession(name: "Test Session")
        let startDate = Date()

        for i in 0..<count {
            let point = LocationPoint(
                timestamp: startDate.addingTimeInterval(TimeInterval(i) * intervalSeconds),
                latitude: 35.0 + Double(i) * 0.001,
                longitude: 139.0 + Double(i) * 0.001,
                altitude: 10.0
            )
            session.locationPoints.append(point)
        }
        return session
    }

    // MARK: - Playback Frequency Tests

    @Test func playback_30secondsDuration_1secondInterval_produces30Updates() async throws {
        // Arrange: Create session with 100 points over 100 seconds (1 point per second)
        let session = createSessionWithPoints(count: 100, intervalSeconds: 1.0)
        let viewModel = SessionDetailViewModel(session: session)
        viewModel.playbackDurationSeconds = 30.0

        // Act: Start playback with 1 second interval (but don't actually run the timer)
        viewModel.startTimeBasedPlayback(currentPositionUpdateFrequency: 1.0)

        // Pause immediately to stop the timer
        viewModel.pauseTimeBasedPlayback()

        // Reset elapsed time to 0
        viewModel.playbackElapsedTime = 0
        viewModel.isPlayingAnimation = true

        var updateCount = 0

        // Simulate 30 timer ticks manually
        while viewModel.isPlayingAnimation && updateCount < 50 { // safety limit
            viewModel.updatePlaybackFrame()
            updateCount += 1
        }

        // Assert: Should have exactly 30 updates (from 0 to 30 seconds)
        #expect(updateCount == 30)
        #expect(viewModel.playbackElapsedTime == 30.0)
        #expect(viewModel.isPlayingAnimation == false) // Should stop at end
    }

    @Test func playback_10secondsDuration_halfSecondInterval_produces20Updates() async throws {
        // Arrange
        let session = createSessionWithPoints(count: 100, intervalSeconds: 1.0)
        let viewModel = SessionDetailViewModel(session: session)
        viewModel.playbackDurationSeconds = 10.0

        // Act: Start with 0.5 second interval
        viewModel.startTimeBasedPlayback(currentPositionUpdateFrequency: 0.5)
        viewModel.pauseTimeBasedPlayback()

        // Reset for manual simulation
        viewModel.playbackElapsedTime = 0
        viewModel.isPlayingAnimation = true

        var updateCount = 0

        // Simulate timer ticks
        while viewModel.isPlayingAnimation && updateCount < 50 {
            viewModel.updatePlaybackFrame()
            updateCount += 1
        }

        // Assert: 10 seconds / 0.5 second interval = 20 updates
        #expect(updateCount == 20)
        #expect(viewModel.playbackElapsedTime == 10.0)
        #expect(viewModel.isPlayingAnimation == false)
    }

    @Test func playback_frequencyIsStored() async throws {
        // Arrange
        let session = createSessionWithPoints(count: 10)
        let viewModel = SessionDetailViewModel(session: session)

        // Act
        viewModel.startTimeBasedPlayback(currentPositionUpdateFrequency: 2.5)

        // Assert
        #expect(viewModel.positionUpdateFrequency == 2.5)

        // Cleanup
        viewModel.pauseTimeBasedPlayback()
    }

    @Test func playback_defaultFrequencyIs1Second() async throws {
        // Arrange
        let session = createSessionWithPoints(count: 10)
        let viewModel = SessionDetailViewModel(session: session)

        // Act: Start without specifying frequency
        viewModel.startTimeBasedPlayback()

        // Assert
        #expect(viewModel.positionUpdateFrequency == 1.0)

        // Cleanup
        viewModel.pauseTimeBasedPlayback()
    }

    // MARK: - Interpolation Tests

    @Test func interpolatedPosition_atBeginning_returnsFirstPoint() async throws {
        // Arrange: 10 points over 90 seconds
        let session = createSessionWithPoints(count: 10, intervalSeconds: 10.0)
        let viewModel = SessionDetailViewModel(session: session)
        viewModel.playbackDurationSeconds = 30.0

        // Act: At 0% progress (beginning)
        viewModel.playbackElapsedTime = 0
        let position = viewModel.calculateInterpolatedPosition()

        // Assert: Should be at first point
        #expect(position != nil)
        #expect(position!.latitude == 35.0)
        #expect(position!.longitude == 139.0)
    }

    @Test func interpolatedPosition_atEnd_returnsLastPoint() async throws {
        // Arrange: 10 points over 90 seconds
        let session = createSessionWithPoints(count: 10, intervalSeconds: 10.0)
        let viewModel = SessionDetailViewModel(session: session)
        viewModel.playbackDurationSeconds = 30.0

        // Act: At 100% progress (end)
        viewModel.playbackElapsedTime = 30.0
        let position = viewModel.calculateInterpolatedPosition()

        // Assert: Should be at last point (index 9)
        #expect(position != nil)
        #expect(abs(position!.latitude - (35.0 + 9 * 0.001)) < 0.0001)
        #expect(abs(position!.longitude - (139.0 + 9 * 0.001)) < 0.0001)
    }

    @Test func interpolatedPosition_atMiddle_interpolatesBetweenPoints() async throws {
        // Arrange: 10 points over 90 seconds (journey from 0 to 90 seconds)
        let session = createSessionWithPoints(count: 10, intervalSeconds: 10.0)
        let viewModel = SessionDetailViewModel(session: session)
        viewModel.playbackDurationSeconds = 90.0 // 1:1 playback

        // Act: At 50% progress (45 seconds into journey)
        // 45 seconds is between point 4 (40s) and point 5 (50s)
        viewModel.playbackElapsedTime = 45.0
        let position = viewModel.calculateInterpolatedPosition()

        // Assert: Should be interpolated between point 4 and 5
        // Point 4: lat=35.004, lon=139.004
        // Point 5: lat=35.005, lon=139.005
        // At 50% between them: lat=35.0045, lon=139.0045
        #expect(position != nil)
        #expect(abs(position!.latitude - 35.0045) < 0.0001)
        #expect(abs(position!.longitude - 139.0045) < 0.0001)
    }

    // MARK: - Playback State Tests

    @Test func startPlayback_setsPlayingState() async throws {
        // Arrange
        let session = createSessionWithPoints(count: 10)
        let viewModel = SessionDetailViewModel(session: session)

        // Act
        viewModel.startTimeBasedPlayback(currentPositionUpdateFrequency: 1.0)

        // Assert
        #expect(viewModel.isPlayingAnimation == true)
        #expect(viewModel.showPlaybackMarker == true)

        // Cleanup
        viewModel.pauseTimeBasedPlayback()
    }

    @Test func pausePlayback_clearsPlayingState() async throws {
        // Arrange
        let session = createSessionWithPoints(count: 10)
        let viewModel = SessionDetailViewModel(session: session)
        viewModel.startTimeBasedPlayback()

        // Act
        viewModel.pauseTimeBasedPlayback()

        // Assert
        #expect(viewModel.isPlayingAnimation == false)
    }

    @Test func togglePlayback_togglesState() async throws {
        // Arrange
        let session = createSessionWithPoints(count: 10)
        let viewModel = SessionDetailViewModel(session: session)

        // Act & Assert: Toggle on
        viewModel.toggleTimeBasedPlayback()
        #expect(viewModel.isPlayingAnimation == true)

        // Act & Assert: Toggle off
        viewModel.toggleTimeBasedPlayback()
        #expect(viewModel.isPlayingAnimation == false)
    }

    @Test func startPlayback_atEnd_resetsToBeginning() async throws {
        // Arrange
        let session = createSessionWithPoints(count: 10)
        let viewModel = SessionDetailViewModel(session: session)
        viewModel.playbackDurationSeconds = 30.0
        viewModel.playbackElapsedTime = 30.0 // At end

        // Act
        viewModel.startTimeBasedPlayback()

        // Assert: Should reset to beginning
        #expect(viewModel.playbackElapsedTime == 0)

        // Cleanup
        viewModel.pauseTimeBasedPlayback()
    }

    // MARK: - Seek Tests

    @Test func seekToTime_updatesElapsedTime() async throws {
        // Arrange
        let session = createSessionWithPoints(count: 10)
        let viewModel = SessionDetailViewModel(session: session)
        viewModel.playbackDurationSeconds = 30.0

        // Act
        viewModel.seekToTime(15.0)

        // Assert
        #expect(viewModel.playbackElapsedTime == 15.0)
        #expect(viewModel.showPlaybackMarker == true)
        #expect(viewModel.interpolatedCoordinate != nil)
    }

    @Test func seekToTime_clampsToValidRange() async throws {
        // Arrange
        let session = createSessionWithPoints(count: 10)
        let viewModel = SessionDetailViewModel(session: session)
        viewModel.playbackDurationSeconds = 30.0

        // Act: Try to seek beyond bounds
        viewModel.seekToTime(50.0)
        #expect(viewModel.playbackElapsedTime == 30.0)

        viewModel.seekToTime(-10.0)
        #expect(viewModel.playbackElapsedTime == 0)
    }

    @Test func seekToBeginning_resetsToZero() async throws {
        // Arrange
        let session = createSessionWithPoints(count: 10)
        let viewModel = SessionDetailViewModel(session: session)
        viewModel.playbackElapsedTime = 15.0

        // Act
        viewModel.seekToBeginningTimeBased()

        // Assert
        #expect(viewModel.playbackElapsedTime == 0)
    }

    @Test func seekToEnd_setsToMaxDuration() async throws {
        // Arrange
        let session = createSessionWithPoints(count: 10)
        let viewModel = SessionDetailViewModel(session: session)
        viewModel.playbackDurationSeconds = 30.0

        // Act
        viewModel.seekToEndTimeBased()

        // Assert
        #expect(viewModel.playbackElapsedTime == 30.0)
        #expect(viewModel.showPlaybackMarker == false)
    }

    // MARK: - Empty Session Tests

    @Test func playback_withEmptySession_doesNotStart() async throws {
        // Arrange
        let session = TrackingSession(name: "Empty")
        let viewModel = SessionDetailViewModel(session: session)

        // Act
        viewModel.startTimeBasedPlayback()

        // Assert
        #expect(viewModel.isPlayingAnimation == false)
    }

    @Test func interpolatedPosition_withEmptySession_returnsNil() async throws {
        // Arrange
        let session = TrackingSession(name: "Empty")
        let viewModel = SessionDetailViewModel(session: session)

        // Act
        let position = viewModel.calculateInterpolatedPosition()

        // Assert
        #expect(position == nil)
    }

    // MARK: - Animation Duration Tests

    @Test func playbackAnimationDuration_basedOnFrequency() async throws {
        // Arrange
        let session = createSessionWithPoints(count: 10)
        let viewModel = SessionDetailViewModel(session: session)

        // Act
        viewModel.startTimeBasedPlayback(currentPositionUpdateFrequency: 2.0)

        // Assert: Animation duration should be 80% of frequency
        #expect(viewModel.playbackAnimationDuration == 1.6)

        // Cleanup
        viewModel.pauseTimeBasedPlayback()
    }

    // MARK: - Playback Duration Persistence Tests

    @Test func playbackDuration_loadsFromSession() async throws {
        // Arrange: Create session with custom playback duration
        let session = createSessionWithPoints(count: 10)
        session.playbackDuration = 60.0

        // Act
        let viewModel = SessionDetailViewModel(session: session)

        // Assert: ViewModel should load duration from session
        #expect(viewModel.playbackDurationSeconds == 60.0)
    }

    @Test func playbackDuration_savesToSession() async throws {
        // Arrange
        let session = createSessionWithPoints(count: 10)
        let viewModel = SessionDetailViewModel(session: session)

        // Act: Change duration in ViewModel
        viewModel.playbackDurationSeconds = 120.0

        // Assert: Session model should be updated
        #expect(session.playbackDuration == 120.0)
    }

    @Test func playbackDuration_defaultsTo30Seconds() async throws {
        // Arrange: Create fresh session (default playbackDuration)
        let session = createSessionWithPoints(count: 10)

        // Act
        let viewModel = SessionDetailViewModel(session: session)

        // Assert: Default should be 30 seconds
        #expect(viewModel.playbackDurationSeconds == 30.0)
        #expect(session.playbackDuration == 30.0)
    }

    // MARK: - Route Source Selection Tests

    @Test func routeSourceMode_defaultsToGPS() async throws {
        // Arrange
        let session = createSessionWithPoints(count: 10)
        let viewModel = SessionDetailViewModel(session: session)

        // Assert
        #expect(viewModel.routeSourceMode == .gps)
    }

    @Test func routeSourceMode_persistsToSession() async throws {
        // Arrange
        let session = createSessionWithPoints(count: 10)
        let viewModel = SessionDetailViewModel(session: session)

        // Act
        viewModel.routeSourceMode = .railway

        // Assert
        #expect(session.routeSourceMode == .railway)
        #expect(session.routeSourceModeRawValue == "Railway")
    }

    @Test func routeSourceMode_loadsFromSession() async throws {
        // Arrange
        let session = createSessionWithPoints(count: 10)
        session.routeSourceModeRawValue = RouteSourceMode.railway.rawValue

        // Act
        let viewModel = SessionDetailViewModel(session: session)

        // Assert
        #expect(viewModel.routeSourceMode == .railway)
    }

    // MARK: - Railway Mode Behavior Tests

    @Test func railwayMode_positionSnapsToStation() async throws {
        // Arrange: Create session with stations
        let session = createSessionWithStationsAndPoints()
        let viewModel = SessionDetailViewModel(session: session)
        viewModel.routeSourceMode = .railway
        viewModel.playbackDurationSeconds = 100.0

        // Act: Seek to middle of playback (after first station)
        viewModel.seekToProgress(0.5)
        let position = viewModel.calculateInterpolatedPosition()

        // Assert: Position should match a station coordinate
        let stationCoords = session.stationPassEvents.compactMap { $0.station?.coordinate }
        let matchesStation = stationCoords.contains { coord in
            abs(coord.latitude - position!.latitude) < 0.0001 &&
                abs(coord.longitude - position!.longitude) < 0.0001
        }
        #expect(matchesStation == true)
    }

    @Test func railwayMode_positionStaysAtLastStationWhenPastAllStations() async throws {
        // Arrange
        let session = createSessionWithStationsAndPoints()
        let viewModel = SessionDetailViewModel(session: session)
        viewModel.routeSourceMode = .railway
        viewModel.playbackDurationSeconds = 100.0

        // Act: Seek to end (past all stations)
        viewModel.seekToProgress(1.0)
        let position = viewModel.calculateInterpolatedPosition()

        // Assert: Should be at last station
        let lastStation = session.stationPassEvents.sorted { $0.timestamp < $1.timestamp }.last?.station
        #expect(position?.latitude == lastStation?.latitude)
        #expect(position?.longitude == lastStation?.longitude)
    }

    @Test func railwayMode_currentStationIndexUpdatesWithProgress() async throws {
        // Arrange
        let session = createSessionWithStationsAndPoints()
        let viewModel = SessionDetailViewModel(session: session)
        viewModel.routeSourceMode = .railway
        viewModel.playbackDurationSeconds = 100.0

        // Act: At beginning - no station passed
        viewModel.seekToProgress(0.0)
        _ = viewModel.calculateInterpolatedPosition()
        let initialIndex = viewModel.currentStationPassIndex

        // Act: At end - all stations passed
        viewModel.seekToProgress(1.0)
        _ = viewModel.calculateInterpolatedPosition()
        let finalIndex = viewModel.currentStationPassIndex

        // Assert
        #expect(finalIndex > initialIndex)
    }

    // MARK: - Display Option Toggle Tests

    @Test func displayOptions_defaultValues() async throws {
        // Arrange
        let session = createSessionWithPoints(count: 10)
        let viewModel = SessionDetailViewModel(session: session)

        // Assert
        #expect(viewModel.showRailroad == true)
        #expect(viewModel.showStationMarkers == true)
        #expect(viewModel.showGPSLocationMarker == true)
    }

    @Test func displayOptions_persistToSession() async throws {
        // Arrange
        let session = createSessionWithPoints(count: 10)
        let viewModel = SessionDetailViewModel(session: session)

        // Act
        viewModel.showRailroad = false
        viewModel.showStationMarkers = false
        viewModel.showGPSLocationMarker = false

        // Assert
        #expect(session.showRailroad == false)
        #expect(session.showStationMarkers == false)
        #expect(session.showGPSLocationMarker == false)
    }

    @Test func displayOptions_loadFromSession() async throws {
        // Arrange
        let session = createSessionWithPoints(count: 10)
        session.showRailroad = false
        session.showStationMarkers = false
        session.showGPSLocationMarker = false

        // Act
        let viewModel = SessionDetailViewModel(session: session)

        // Assert
        #expect(viewModel.showRailroad == false)
        #expect(viewModel.showStationMarkers == false)
        #expect(viewModel.showGPSLocationMarker == false)
    }

    @Test func staticMarkers_excludesStationsWhenDisabled() async throws {
        // Arrange
        let session = createSessionWithStationsAndPoints()
        let viewModel = SessionDetailViewModel(session: session)

        // Act: With station markers enabled
        viewModel.showStationMarkers = true
        let markersWithStations = viewModel.staticMarkers

        // Act: With station markers disabled
        viewModel.showStationMarkers = false
        let markersWithoutStations = viewModel.staticMarkers

        // Assert: Should have fewer markers when stations disabled
        #expect(markersWithoutStations.count < markersWithStations.count)

        // Should still have start and end markers
        #expect(markersWithoutStations.contains { $0.type == .start })
        #expect(markersWithoutStations.contains { $0.type == .end })

        // Should not have station markers
        #expect(!markersWithoutStations.contains { $0.type == .trainStation })
    }

    // MARK: - Traveled Coordinates Mode Tests

    @Test func traveledCoordinates_gpsMode_returnsGPSPath() async throws {
        // Arrange
        let session = createSessionWithPoints(count: 50, intervalSeconds: 1.0)
        let viewModel = SessionDetailViewModel(session: session)
        viewModel.routeSourceMode = .gps
        viewModel.playbackDurationSeconds = 50.0

        // Act
        viewModel.seekToProgress(0.5)

        // Assert: Should have coordinates from GPS path
        let coords = viewModel.traveledCoordinates
        #expect(!coords.isEmpty)
        // First coordinate should match first GPS point
        #expect(abs(coords.first!.latitude - 35.0) < 0.0001)
    }

    @Test func traveledCoordinates_railwayMode_emptyWithoutRailwayRoutes() async throws {
        // Arrange
        let session = createSessionWithStationsAndPoints()
        let viewModel = SessionDetailViewModel(session: session)
        viewModel.routeSourceMode = .railway
        viewModel.playbackDurationSeconds = 100.0

        // Act: Seek to middle (railway routes not loaded)
        viewModel.seekToProgress(0.5)

        // Assert: Without railway routes loaded, traveled coordinates should be empty
        // (since stationDataViewModel.railwayRoutes is empty by default)
        let coords = viewModel.traveledCoordinates
        #expect(coords.isEmpty)
    }

    // MARK: - Helper: Create Session with Stations

    private func createSessionWithStationsAndPoints() -> TrackingSession {
        let session = createSessionWithPoints(count: 100, intervalSeconds: 1.0)
        let startDate = session.sortedLocationPoints.first!.timestamp

        for i in 0 ..< 3 {
            let station = TrainStation(
                osmId: Int64(i + 1000),
                name: "Station \(i + 1)",
                latitude: 35.0 + Double(i) * 0.01,
                longitude: 139.0 + Double(i) * 0.01
            )

            let event = StationPassEvent(
                timestamp: startDate.addingTimeInterval(Double(i + 1) * 30.0),
                distanceFromStation: 50,
                entryPointIndex: i * 30,
                displayOrder: i
            )
            event.station = station
            session.stationPassEvents.append(event)
        }

        return session
    }
}
