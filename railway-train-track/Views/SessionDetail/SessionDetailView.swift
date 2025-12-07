//
//  SessionDetailView.swift
//  railway-train-track
//
//  Created by Qiwei Li on 12/6/25.
//

import SwiftUI
import SwiftData
import MapKit

struct SessionDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(TrackingViewModel.self) private var trackingViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: SessionDetailViewModel
    @State private var exportViewModel = ExportViewModel()
    @State private var sheetPresented = true

    init(session: TrackingSession) {
        _viewModel = State(initialValue: SessionDetailViewModel(session: session))
    }

    var body: some View {
        ZStack {
            // Background Map showing full route
            SessionMapView(
                viewModel: viewModel
            )
            .ignoresSafeArea()
        }
        .sheet(isPresented: $sheetPresented) {
            SessionSheetContent(viewModel: viewModel, exportViewModel: exportViewModel)
                .presentationDetents([.height(200), .medium, .large])
                .presentationDragIndicator(.visible)
                .presentationBackgroundInteraction(.enabled)
                .interactiveDismissDisabled()
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 16) {
                    if !viewModel.session.isActive && !trackingViewModel.hasActiveSession {
                        Button {
                            trackingViewModel.resumeFinishedSession(viewModel.session)
                            dismiss()
                        } label: {
                            Image(systemName: "play.fill")
                        }
                    }

                    Button {
                        viewModel.showPlaybackSettingsSheet = true
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                    }

                    ExportMenuButton(
                        session: viewModel.session,
                        currentTab: viewModel.selectedTab,
                        exportViewModel: exportViewModel
                    )
                }
            }
        }
        .sheet(isPresented: $viewModel.showPlaybackSettingsSheet) {
            PlaybackSettingsSheet(viewModel: viewModel)
        }
        .navigationTitle(viewModel.session.name)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.setModelContext(modelContext)
            exportViewModel.setDefaultFilename(from: viewModel.session)
        }
    }
}

// MARK: - Session Map View

struct SessionMapView: View {
    @Bindable var viewModel: SessionDetailViewModel

    var body: some View {
        Map(position: $viewModel.mapCameraPosition) {
            // Full route polyline
            if viewModel.session.coordinates.count > 1 {
                MapPolyline(coordinates: viewModel.session.coordinates)
                    .stroke(.blue.opacity(0.5), lineWidth: 3)
            }

            // Traveled route (up to current playback position)
            if viewModel.selectedLocationIndex > 0 {
                let traveledCoords = Array(viewModel.session.coordinates.prefix(viewModel.selectedLocationIndex + 1))
                MapPolyline(coordinates: traveledCoords)
                    .stroke(.blue, lineWidth: 4)
            }

            // Railway track polylines
            ForEach(Array(viewModel.stationDataViewModel.railwayRoutes.enumerated()), id: \.offset) { _, route in
                MapPolyline(coordinates: route)
                    .stroke(.brown, style: StrokeStyle(lineWidth: 3, dash: [5, 3]))
            }

            // Station markers
            ForEach(viewModel.sortedStationEvents) { event in
                if let station = event.station {
                    Annotation(station.name, coordinate: station.coordinate) {
                        ZStack {
                            Circle()
                                .fill(.orange)
                                .frame(width: 24, height: 24)
                            Image(systemName: "train.side.front.car")
                                .font(.system(size: 12))
                                .foregroundStyle(.white)
                        }
                    }
                }
            }

            // Current position marker
            if let point = viewModel.currentLocationPoint {
                Annotation("Current", coordinate: point.coordinate) {
                    ZStack {
                        Circle()
                            .fill(.white)
                            .frame(width: 20, height: 20)
                        Circle()
                            .fill(.red)
                            .frame(width: 14, height: 14)
                    }
                }
            }

            // Start marker
            if let first = viewModel.sortedLocationPoints.first {
                Annotation("Start", coordinate: first.coordinate) {
                    ZStack {
                        Circle()
                            .fill(.green)
                            .frame(width: 20, height: 20)
                        Image(systemName: "flag.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(.white)
                    }
                }
            }

            // End marker
            if let last = viewModel.sortedLocationPoints.last,
               viewModel.sortedLocationPoints.count > 1 {
                Annotation("End", coordinate: last.coordinate) {
                    ZStack {
                        Circle()
                            .fill(.red)
                            .frame(width: 20, height: 20)
                        Image(systemName: "flag.checkered")
                            .font(.system(size: 10))
                            .foregroundStyle(.white)
                    }
                }
            }
        }
        .mapControls {
            MapCompass()
            MapScaleView()
            MapUserLocationButton()
        }
    }
}

// MARK: - Sheet Content

struct SessionSheetContent: View {
    @Bindable var viewModel: SessionDetailViewModel
    @Bindable var exportViewModel: ExportViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Tab picker
            Picker("Tab", selection: $viewModel.selectedTab) {
                ForEach(SessionTab.allCases, id: \.self) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding()

            // Tab content
            TabView(selection: $viewModel.selectedTab) {
                LocationsTabView(viewModel: viewModel)
                    .tag(SessionTab.locations)

                StationsTabView(viewModel: viewModel)
                    .tag(SessionTab.stations)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
        }
    }
}

#Preview {
    NavigationStack {
        SessionDetailView(session: TrackingSession(name: "Test Session"))
    }
    .modelContainer(for: [TrackingSession.self, LocationPoint.self, TrainStation.self, StationPassEvent.self], inMemory: true)
    .environment(TrackingViewModel())
}
