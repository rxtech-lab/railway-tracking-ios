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
            // Background Map using unified AnimatedTrackingMapView
            AnimatedTrackingMapView(
                cameraPosition: $viewModel.mapCameraPosition,
                currentCoordinate: viewModel.interpolatedCoordinate,
                animationDuration: viewModel.playbackAnimationDuration,
                routeCoordinates: viewModel.session.coordinates,
                traveledCoordinates: viewModel.traveledCoordinates,
                markers: viewModel.staticMarkers,
                railwayRoutes: viewModel.stationDataViewModel.railwayRoutes,
                markerStyle: .currentPosition,
                showCurrentPositionMarker: viewModel.showPlaybackMarker,
                showRoutePolyline: false,
                cameraDistance: viewModel.playbackCameraDistance,
                onCameraDistanceChanged: { newDistance in
                    viewModel.playbackCameraDistance = newDistance
                }
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
            .presentationDetents(content == .tabBar ? [.height(300), .medium, .large] : [.medium, .large])
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
            switch viewModel.selectedTab {
            case .locations:
                LocationsTabView(viewModel: viewModel)
                    .tag(SessionTab.locations)
            case .stations:
                StationsTabView(viewModel: viewModel)
                    .tag(SessionTab.stations)
            }
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
