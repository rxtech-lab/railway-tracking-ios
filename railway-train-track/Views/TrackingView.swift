//
//  TrackingView.swift
//  railway-train-track
//
//  Created by Qiwei Li on 12/6/25.
//

import MapKit
import SwiftUI

struct TrackingView: View {
    @Environment(TrackingViewModel.self) private var viewModel
    @State private var sessionName: String = ""
    @State private var showNameInput: Bool = false
    @State private var mapCameraPosition: MapCameraPosition = .automatic
    @State private var markerLatitude: Double = 0
    @State private var markerLongitude: Double = 0

    private var markerCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: markerLatitude, longitude: markerLongitude)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Authorization Status
                if !viewModel.canTrack {
                    VStack(spacing: 12) {
                        Image(systemName: "location.slash.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(.orange)

                        Text(viewModel.authorizationMessage)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.secondary)

                        Button("Request Permission") {
                            viewModel.requestLocationPermission()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                } else if viewModel.hasRecoverableSession {
                    // Recoverable session view
                    recoverableSessionView
                } else if viewModel.isTracking {
                    // Active tracking view
                    activeTrackingView
                } else {
                    // Start tracking view
                    startTrackingView
                }

                Spacer()

                // Error message
                if let error = viewModel.errorMessage {
                    Text(error)
                        .foregroundStyle(.red)
                        .font(.caption)
                        .padding()
                }
            }
            .padding()
            .navigationTitle("Track Journey")
            .sheet(isPresented: $showNameInput) {
                sessionNameSheet
            }
        }
    }

    // MARK: - Recoverable Session View

    private var recoverableSessionView: some View {
        VStack(spacing: 24) {
            Image(systemName: "arrow.clockwise.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.orange)

            Text("Session Found")
                .font(.title2)
                .fontWeight(.semibold)

            Text("You have an active recording session that was interrupted.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            if let session = viewModel.recoverableSession {
                VStack(spacing: 8) {
                    Text(session.name)
                        .font(.headline)

                    HStack(spacing: 16) {
                        Label("\(session.locationPoints.count) points", systemImage: "mappin.and.ellipse")
                        Label(session.formattedDuration, systemImage: "clock")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)

                    Text("Started: \(session.startTime.formatted(date: .abbreviated, time: .shortened))")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .padding()
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            HStack(spacing: 16) {
                Button {
                    viewModel.discardRecoveredSession()
                } label: {
                    Label("Discard", systemImage: "trash")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.red)

                Button {
                    viewModel.resumeRecoveredSession()
                } label: {
                    Label("Resume", systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    // MARK: - Start Tracking View

    private var startTrackingView: some View {
        VStack(spacing: 24) {
            Image(systemName: "train.side.front.car")
                .font(.system(size: 64))
                .foregroundStyle(.blue)

            Text("Ready to Track")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Record your train journey with GPS tracking.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            VStack(spacing: 8) {
                Text("Recording Interval")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack {
                    Text("\(viewModel.recordingInterval, specifier: "%.1f")s")
                        .font(.headline)
                        .frame(width: 50)

                    Slider(value: Binding(
                        get: { viewModel.recordingInterval },
                        set: { viewModel.updateRecordingInterval($0) }
                    ), in: 0.5 ... 10, step: 0.5)
                }
                .padding(.horizontal)
            }
            .padding()
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))

            Button {
                showNameInput = true
            } label: {
                Label("Start Tracking", systemImage: "play.fill")
            }
            .buttonStyle(.borderedProminent)
        }
    }

    // MARK: - Active Tracking View

    private var activeTrackingView: some View {
        VStack(spacing: 24) {
            // Status indicator
            HStack {
                Circle()
                    .fill(viewModel.isPaused ? .orange : .red)
                    .frame(width: 12, height: 12)

                Text(viewModel.isPaused ? "Paused" : "Recording")
                    .font(.headline)
            }

            // Session info
            if let session = viewModel.currentSession {
                VStack(spacing: 8) {
                    Text(session.name)
                        .font(.title3)
                        .fontWeight(.semibold)

                    Text("Started: \(session.startTime.formatted(date: .omitted, time: .shortened))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // Stats
            VStack(spacing: 16) {
                HStack(spacing: 32) {
                    statItem(title: "Points", value: "\(viewModel.pointCount)")
                    statItem(title: "Duration", value: viewModel.currentSession?.formattedDuration ?? "--")
                }

                if let location = viewModel.lastLocation {
                    HStack(spacing: 32) {
                        statItem(title: "Speed", value: String(format: "%.1f km/h", max(0, location.speed * 3.6)))
                        statItem(title: "Altitude", value: String(format: "%.0f m", location.altitude))
                    }
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))

            // Map preview
            if viewModel.lastLocation != nil {
                Map(position: $mapCameraPosition) {
                    // Route polyline
                    if viewModel.sampledRouteCoordinates.count > 1 {
                        MapPolyline(coordinates: viewModel.sampledRouteCoordinates)
                            .stroke(.blue.opacity(0.7), lineWidth: 3)
                    }

                    // Current location marker (uses animated coordinates)
                    Annotation("Current", coordinate: markerCoordinate) {
                        Circle()
                            .fill(.blue)
                            .frame(width: 16, height: 16)
                            .overlay(
                                Circle()
                                    .stroke(.white, lineWidth: 2)
                            )
                    }
                }
                .frame(height: 150)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .mapCameraKeyframeAnimator(trigger: viewModel.lastLocation) { initialCamera in
                    KeyframeTrack(\.centerCoordinate) {
                        if let location = viewModel.lastLocation {
                            CubicKeyframe(location.coordinate, duration: 0.5)
                        } else {
                            CubicKeyframe(initialCamera.centerCoordinate, duration: 0.5)
                        }
                    }
                }
                .onChange(of: viewModel.lastLocation) { _, newLocation in
                    guard let location = newLocation else { return }
                    withAnimation(.easeInOut(duration: 1)) {
                        markerLatitude = location.coordinate.latitude
                        markerLongitude = location.coordinate.longitude
                    }
                }
                .onAppear {
                    if let location = viewModel.lastLocation {
                        markerLatitude = location.coordinate.latitude
                        markerLongitude = location.coordinate.longitude
                        mapCameraPosition = .camera(MapCamera(
                            centerCoordinate: location.coordinate,
                            distance: 1000
                        ))
                    }
                }
            }

            // Controls
            HStack(spacing: 20) {
                Button {
                    if viewModel.isPaused {
                        viewModel.resumeSession()
                    } else {
                        viewModel.pauseSession()
                    }
                } label: {
                    Label(
                        viewModel.isPaused ? "Resume" : "Pause",
                        systemImage: viewModel.isPaused ? "play.fill" : "pause.fill"
                    )
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                Button(role: .destructive) {
                    viewModel.stopSession()
                } label: {
                    Label("Stop", systemImage: "stop.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func statItem(title: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2)
                .fontWeight(.semibold)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(minWidth: 80)
    }

    // MARK: - Session Name Sheet

    private var sessionNameSheet: some View {
        NavigationStack {
            Form {
                Section("Session Name") {
                    TextField("Enter session name", text: $sessionName)
                }

                Section {
                    Text("Leave empty to use default name with timestamp")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("New Session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showNameInput = false
                        sessionName = ""
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Start") {
                        viewModel.startNewSession(name: sessionName)
                        showNameInput = false
                        sessionName = ""
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

#Preview {
    TrackingView()
        .environment(TrackingViewModel())
}
