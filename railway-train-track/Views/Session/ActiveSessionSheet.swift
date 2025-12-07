//
//  ActiveSessionSheet.swift
//  railway-train-track
//
//  Created by Qiwei Li on 12/7/25.
//

import MapKit
import SwiftUI

struct ActiveSessionSheet: View {
    @Environment(TrackingViewModel.self) private var viewModel
    @Environment(\.dismiss) private var dismiss
    let session: TrackingSession
    @State private var mapCameraPosition: MapCameraPosition = .automatic
    @State private var markerLatitude: Double = 0
    @State private var markerLongitude: Double = 0

    private var markerCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: markerLatitude, longitude: markerLongitude)
    }

    var body: some View {
        NavigationStack {
            Form {
                // Status Section
                Section {
                    HStack {
                        Circle()
                            .fill(viewModel.isPaused ? .orange : .red)
                            .frame(width: 12, height: 12)
                        Text(viewModel.isPaused ? "Paused" : "Recording")
                            .font(.headline)
                        Spacer()
                    }

                    LabeledContent("Session", value: session.name)
                    LabeledContent("Started", value: session.startTime.formatted(date: .omitted, time: .shortened))
                }

                // Stats Section
                Section("Statistics") {
                    LabeledContent("Points", value: "\(viewModel.pointCount)")
                    LabeledContent("Duration", value: session.formattedDuration)

                    if let location = viewModel.lastLocation {
                        LabeledContent("Speed", value: String(format: "%.1f km/h", max(0, location.speed * 3.6)))
                        LabeledContent("Altitude", value: String(format: "%.0f m", location.altitude))
                    }
                }

                // Map Section
                if viewModel.lastLocation != nil {
                    Section("Current Location") {
                        Map(position: $mapCameraPosition) {
                            // Route polyline (last 20 points)
                            if viewModel.recentRouteCoordinates.count > 1 {
                                MapPolyline(coordinates: viewModel.recentRouteCoordinates)
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
                        .frame(height: 200)
                        .listRowInsets(EdgeInsets())
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
                            withAnimation(.easeInOut(duration: 0.5)) {
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
                }

                // Controls Section
                Section {
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
                    }

                    Button(role: .destructive) {
                        viewModel.stopSession()
                        dismiss()
                    } label: {
                        Label("Stop", systemImage: "stop.fill")
                            .foregroundStyle(.red)
                    }
                }

                // Error Section
                if let error = viewModel.errorMessage {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Tracking")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .interactiveDismissDisabled(false)
    }
}

#Preview {
    ActiveSessionSheet(session: TrackingSession(name: "Test Session"))
        .environment(TrackingViewModel())
}
