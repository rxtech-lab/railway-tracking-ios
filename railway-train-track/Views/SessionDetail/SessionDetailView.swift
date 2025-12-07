//
//  SessionDetailView.swift
//  railway-train-track
//
//  Created by Qiwei Li on 12/6/25.
//

import MapKit
import SwiftData
import SwiftUI

struct SessionDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(TrackingViewModel.self) private var trackingViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: SessionDetailViewModel
    @State private var exportViewModel = ExportViewModel()

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
        .sheet(item: Binding(
            get: { viewModel.sheetContent },
            set: { viewModel.sheetContent = $0 ?? .tabBar }
        )) { content in
            SheetContentView(
                content: content,
                viewModel: viewModel,
                exportViewModel: exportViewModel
            )
            .presentationDetents(content == .tabBar ? [.height(200), .medium, .large] : [.medium, .large])
            .presentationDragIndicator(.visible)
            .presentationBackgroundInteraction(content == .tabBar ? .enabled : .disabled)
            .interactiveDismissDisabled()
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 16) {
                    Button {
                        viewModel.sheetContent = .playbackSettings
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                    }

                    ExportMenuButton(
                        viewModel: viewModel,
                        exportViewModel: exportViewModel
                    )
                }
            }
        }
        .navigationTitle(viewModel.session.name)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.setModelContext(modelContext)
            exportViewModel.setDefaultFilename(from: viewModel.session)
        }
    }
}

// MARK: - Sheet Content View

struct SheetContentView: View {
    let content: SheetContent
    @Bindable var viewModel: SessionDetailViewModel
    @Bindable var exportViewModel: ExportViewModel

    var body: some View {
        switch content {
        case .tabBar:
            SessionSheetContent(viewModel: viewModel, exportViewModel: exportViewModel)

        case .playbackSettings:
            NavigationStack {
                PlaybackSettingsContent(viewModel: viewModel)
                    .navigationTitle("Playback Settings")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") {
                                viewModel.sheetContent = .tabBar
                            }
                        }
                    }
            }

        case .stationSearch:
            NavigationStack {
                StationSearchContent(
                    viewModel: viewModel,
                    stationDataViewModel: viewModel.stationDataViewModel
                )
                .navigationTitle("Add Station")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close") {
                            viewModel.sheetContent = .tabBar
                        }
                    }
                }
            }

        case .exportCSV:
            NavigationStack {
                CSVExportContent(
                    session: viewModel.session,
                    exportType: viewModel.selectedTab,
                    exportViewModel: exportViewModel
                )
                .navigationTitle("Export CSV")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close") {
                            viewModel.sheetContent = .tabBar
                        }
                    }
                }
            }

        case .exportJSON:
            NavigationStack {
                JSONExportContent(
                    session: viewModel.session,
                    exportType: viewModel.selectedTab,
                    exportViewModel: exportViewModel
                )
                .navigationTitle("Export JSON")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close") {
                            viewModel.sheetContent = .tabBar
                        }
                    }
                }
            }

        case .exportVideo:
            NavigationStack {
                VideoExportContent(
                    session: viewModel.session,
                    exportViewModel: exportViewModel
                )
                .navigationTitle("Export Video")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close") {
                            viewModel.sheetContent = .tabBar
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Session Map View

struct SessionMapView: View {
    @Bindable var viewModel: SessionDetailViewModel

    // Animated marker state (separate lat/lon for SwiftUI animation)
    @State private var markerLatitude: Double = 0
    @State private var markerLongitude: Double = 0

    private var markerCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: markerLatitude, longitude: markerLongitude)
    }

    // Computed traveled coordinates including animated position
    private var traveledCoordinates: [CLLocationCoordinate2D] {
        guard viewModel.selectedLocationIndex > 0 || markerLatitude != 0 else { return [] }
        var coords = Array(viewModel.session.coordinates.prefix(viewModel.selectedLocationIndex + 1))
        // Append animated marker position if it differs from last point
        if let lastCoord = coords.last,
           lastCoord.latitude != markerLatitude || lastCoord.longitude != markerLongitude
        {
            coords.append(markerCoordinate)
        }
        return coords
    }

    var body: some View {
        Map(position: $viewModel.mapCameraPosition) {
            // Full route polyline
            if viewModel.session.coordinates.count > 1 {
                MapPolyline(coordinates: viewModel.session.coordinates)
                    .stroke(.blue.opacity(0.5), lineWidth: 3)
            }

            // Traveled route (up to current playback position with animation)
            if traveledCoordinates.count > 1 {
                MapPolyline(coordinates: traveledCoordinates)
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

            // Current position marker (animated)
            if viewModel.currentLocationPoint != nil {
                Annotation("Current", coordinate: markerCoordinate) {
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
               viewModel.sortedLocationPoints.count > 1
            {
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
        .mapCameraKeyframeAnimator(trigger: viewModel.currentLocationPoint?.id) { initialCamera in
            KeyframeTrack(\.centerCoordinate) {
                if let point = viewModel.currentLocationPoint {
                    CubicKeyframe(point.coordinate, duration: 0.1 / viewModel.playbackSpeed)
                } else {
                    CubicKeyframe(initialCamera.centerCoordinate, duration: 0.1)
                }
            }
        }
        .onChange(of: viewModel.currentLocationPoint?.id) { _, _ in
            guard let point = viewModel.currentLocationPoint else { return }
            let duration = 0.1 / viewModel.playbackSpeed
            withAnimation(.linear(duration: duration)) {
                markerLatitude = point.coordinate.latitude
                markerLongitude = point.coordinate.longitude
            }
        }
        .onAppear {
            if let point = viewModel.currentLocationPoint {
                markerLatitude = point.coordinate.latitude
                markerLongitude = point.coordinate.longitude
            }
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
