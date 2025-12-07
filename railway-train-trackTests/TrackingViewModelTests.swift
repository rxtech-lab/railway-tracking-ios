//
//  TrackingViewModelTests.swift
//  railway-train-trackTests
//
//  Created by Qiwei Li on 12/7/25.
//

@testable import railway_train_track
import SwiftData
import Testing

@MainActor
struct TrackingViewModelTests {
    // MARK: - dismissRecoveryPrompt Tests

    @Test func dismissRecoveryPrompt_clearsUIState() async throws {
        let viewModel = TrackingViewModel()

        // Setup: simulate recoverable session state
        viewModel.hasRecoverableSession = true
        viewModel.recoverableSession = TrackingSession(name: "Test Session")

        // Act
        viewModel.dismissRecoveryPrompt()

        // Assert: UI state cleared
        #expect(viewModel.hasRecoverableSession == false)
        #expect(viewModel.recoverableSession == nil)
    }

    @Test func dismissRecoveryPrompt_doesNotAffectTrackingState() async throws {
        let viewModel = TrackingViewModel()

        // Setup
        viewModel.hasRecoverableSession = true
        viewModel.recoverableSession = TrackingSession(name: "Test Session")
        let initialIsTracking = viewModel.isTracking
        let initialCurrentSession = viewModel.currentSession

        // Act
        viewModel.dismissRecoveryPrompt()

        // Assert: tracking state unchanged
        #expect(viewModel.isTracking == initialIsTracking)
        #expect(viewModel.currentSession === initialCurrentSession)
    }

    // MARK: - discardRecoveredSession Tests

    @Test func discardRecoveredSession_clearsAllRecoveryState() async throws {
        let viewModel = TrackingViewModel()
        let session = TrackingSession(name: "Test Session")

        // Setup
        viewModel.hasRecoverableSession = true
        viewModel.recoverableSession = session

        // Act
        viewModel.discardRecoveredSession()

        // Assert
        #expect(viewModel.hasRecoverableSession == false)
        #expect(viewModel.recoverableSession == nil)
        #expect(session.isActive == false)
        #expect(session.endTime != nil)
    }

    // MARK: - resumeRecoveredSession Tests

    @Test func resumeRecoveredSession_setsTrackingState() async throws {
        let viewModel = TrackingViewModel()
        let session = TrackingSession(name: "Test Session", recordingInterval: 2.0)

        // Setup
        viewModel.hasRecoverableSession = true
        viewModel.recoverableSession = session

        // Act
        viewModel.resumeRecoveredSession()

        // Assert
        #expect(viewModel.isTracking == true)
        #expect(viewModel.isPaused == false)
        #expect(viewModel.currentSession === session)
        #expect(viewModel.recordingInterval == 2.0)
        #expect(viewModel.hasRecoverableSession == false)
        #expect(viewModel.recoverableSession == nil)
    }

    @Test func resumeRecoveredSession_withNoSession_doesNothing() async throws {
        let viewModel = TrackingViewModel()

        // Setup: no recoverable session
        viewModel.hasRecoverableSession = false
        viewModel.recoverableSession = nil

        // Act
        viewModel.resumeRecoveredSession()

        // Assert: state unchanged
        #expect(viewModel.isTracking == false)
        #expect(viewModel.currentSession == nil)
    }

    // MARK: - hasActiveSession Tests

    @Test func hasActiveSession_returnsTrueWhenTracking() async throws {
        let viewModel = TrackingViewModel()
        let session = TrackingSession(name: "Test")

        // Setup: simulate active tracking
        viewModel.recoverableSession = session
        viewModel.hasRecoverableSession = true
        viewModel.resumeRecoveredSession()

        // Assert
        #expect(viewModel.hasActiveSession == true)
    }

    @Test func hasActiveSession_returnsFalseWhenNotTracking() async throws {
        let viewModel = TrackingViewModel()

        // Assert
        #expect(viewModel.hasActiveSession == false)
    }

    @Test func hasActiveSession_returnsFalseAfterDismissRecoveryPrompt() async throws {
        let viewModel = TrackingViewModel()

        // Setup
        viewModel.hasRecoverableSession = true
        viewModel.recoverableSession = TrackingSession(name: "Test")

        // Act
        viewModel.dismissRecoveryPrompt()

        // Assert: hasActiveSession should still be false because we didn't start tracking
        #expect(viewModel.hasActiveSession == false)
    }

    // MARK: - clearSessionIfDeleted Tests

    @Test func clearSessionIfDeleted_clearsStateWhenCurrentSession() async throws {
        let viewModel = TrackingViewModel()
        let session = TrackingSession(name: "Test")

        // Setup: simulate active tracking
        viewModel.recoverableSession = session
        viewModel.hasRecoverableSession = true
        viewModel.resumeRecoveredSession()

        #expect(viewModel.hasActiveSession == true)

        // Act
        viewModel.clearSessionIfDeleted(session)

        // Assert
        #expect(viewModel.isTracking == false)
        #expect(viewModel.isPaused == false)
        #expect(viewModel.currentSession == nil)
        #expect(viewModel.hasActiveSession == false)
    }

    @Test func clearSessionIfDeleted_doesNothingForDifferentSession() async throws {
        let viewModel = TrackingViewModel()
        let activeSession = TrackingSession(name: "Active")
        let otherSession = TrackingSession(name: "Other")

        // Setup: simulate active tracking
        viewModel.recoverableSession = activeSession
        viewModel.hasRecoverableSession = true
        viewModel.resumeRecoveredSession()

        // Act: delete a different session
        viewModel.clearSessionIfDeleted(otherSession)

        // Assert: tracking state unchanged
        #expect(viewModel.isTracking == true)
        #expect(viewModel.currentSession === activeSession)
        #expect(viewModel.hasActiveSession == true)
    }

    @Test func clearSessionIfDeleted_clearsRecoverableSession() async throws {
        let viewModel = TrackingViewModel()
        let session = TrackingSession(name: "Recoverable")

        // Setup: simulate recoverable session (not yet resumed)
        viewModel.hasRecoverableSession = true
        viewModel.recoverableSession = session

        // Act
        viewModel.clearSessionIfDeleted(session)

        // Assert
        #expect(viewModel.hasRecoverableSession == false)
        #expect(viewModel.recoverableSession == nil)
    }
}
