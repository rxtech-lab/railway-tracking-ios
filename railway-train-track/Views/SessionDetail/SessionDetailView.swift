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

    private var sheetBinding: Binding<SheetContent?> {
        Binding<SheetContent?>(
            get: { viewModel.sheetContent },
            set: { viewModel.sheetContent = $0 ?? .tabBar }
        )
    }

    private var mapView: some View {
        AnimatedTrackingMapView(
            cameraPosition: $viewModel.mapCameraPosition,
            currentCoordinate: viewModel.interpolatedCoordinate,
            animationDuration: viewModel.playbackAnimationDuration,
            routeCoordinates: viewModel.session.coordinates,
            traveledCoordinates: viewModel.traveledCoordinates,
            markers: viewModel.staticMarkers,
            railwayRoutes: viewModel.showRailroad ? viewModel.stationDataViewModel.railwayRoutes : [],
            markerStyle: .currentPosition,
            showCurrentPositionMarker: viewModel.showPlaybackMarker && viewModel.showGPSLocationMarker,
            showRoutePolyline: false,
            cameraDistance: viewModel.playbackCameraDistance,
            onCameraDistanceChanged: { newDistance in
                viewModel.playbackCameraDistance = newDistance
            },
            onLongPress: { coordinate in
                viewModel.handleMapLongPress(coordinate)
            },
            onMarkerTap: { marker in
                viewModel.handleMarkerTap(marker)
            }
        )
        .ignoresSafeArea()
    }

    private var toolbarContent: some View {
        HStack(spacing: 16) {
            Button {
                viewModel.addNoteAtCurrentPlaybackPosition()
            } label: {
                Image(systemName: "note.text.badge.plus")
            }

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

    var body: some View {
        ZStack {
            mapView
        }
        .sheet(item: sheetBinding) { content in
            sheetView(for: content)
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                toolbarContent
            }
        }
        .navigationTitle(viewModel.session.name)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.setModelContext(modelContext)
            exportViewModel.setDefaultFilename(from: viewModel.session)
        }
    }

    @ViewBuilder
    private func sheetView(for content: SheetContent) -> some View {
        SheetContentView(
            content: content,
            viewModel: viewModel,
            exportViewModel: exportViewModel
        )
        .presentationDetents(content.isTabBar ? [.height(300), .medium, .large] : [.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationBackgroundInteraction(content.isTabBar ? .enabled : .disabled)
        .interactiveDismissDisabled()
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

        case .noteEditor(let context):
            NoteEditorView(context: context, viewModel: viewModel)

        case .noteDetail(let note):
            NoteDetailView(note: note, viewModel: viewModel)
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
            case .notes:
                NotesTabView(viewModel: viewModel)
                    .tag(SessionTab.notes)
            }
        }
    }
}

#Preview {
    NavigationStack {
        SessionDetailView(session: TrackingSession(name: "Test Session"))
    }
    .modelContainer(for: [TrackingSession.self, LocationPoint.self, TrainStation.self, StationPassEvent.self, SessionNote.self, SessionPhoto.self], inMemory: true)
    .environment(TrackingViewModel())
}
