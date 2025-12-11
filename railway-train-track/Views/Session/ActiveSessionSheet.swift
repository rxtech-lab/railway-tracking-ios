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
                        AnimatedTrackingMapView(
                            cameraPosition: $mapCameraPosition,
                            currentCoordinate: viewModel.lastLocation?.coordinate,
                            animationDuration: 0.5,
                            routeCoordinates: viewModel.recentRouteCoordinates,
                            traveledCoordinates: [],
                            markers: [],
                            railwayRoutes: [],
                            markerStyle: .liveTracking,
                            showCurrentPositionMarker: true
                        )
                        .frame(height: 200)
                        .listRowInsets(EdgeInsets())
                        .onAppear {
                            if let location = viewModel.lastLocation {
                                mapCameraPosition = .camera(MapCamera(
                                    centerCoordinate: location.coordinate,
                                    distance: 1000
                                ))
                            }
                        }
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
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
                #if os(iOS)
                ToolbarItemGroup(placement: .bottomBar) {
                    StopAndPauseTrackingButton()
                }
                #endif
            }
        }
        .interactiveDismissDisabled(false)
    }
}

#Preview {
    ActiveSessionSheet(session: TrackingSession(name: "Test Session"))
        .environment(TrackingViewModel())
}
