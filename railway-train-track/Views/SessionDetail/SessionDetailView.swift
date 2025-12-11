//
//  SessionDetailView.swift
//  railway-train-track
//
//  Created by Qiwei Li on 12/6/25.
//

import MapKit
import SwiftData
import SwiftUI

// MARK: - Presentation Mode

enum PresentationMode {
    case sheet   // iPhone: present content via .sheet()
    case column  // iPad/Mac: content displayed in third column by parent
}

struct SessionDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(TrackingViewModel.self) private var trackingViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: SessionDetailViewModel
    @State private var exportViewModel = ExportViewModel()

    let presentationMode: PresentationMode

    // For column mode: expose viewModel for parent to share with DetailColumnView
    var sharedViewModel: SessionDetailViewModel {
        viewModel
    }

    var sharedExportViewModel: ExportViewModel {
        exportViewModel
    }

    init(session: TrackingSession, presentationMode: PresentationMode = .sheet, externalViewModel: SessionDetailViewModel? = nil) {
        self.presentationMode = presentationMode
        if let external = externalViewModel {
            _viewModel = State(initialValue: external)
        } else {
            _viewModel = State(initialValue: SessionDetailViewModel(session: session))
        }
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
            routeCoordinates: viewModel.displayCoordinates,
            traveledCoordinates: viewModel.simplifiedTraveledCoordinates,
            markers: viewModel.staticMarkers,
            railwayRoutes: viewModel.showRailroad ? viewModel.stationDataViewModel.railwayRoutes : [],
            markerStyle: .currentPosition,
            showCurrentPositionMarker: viewModel.showPlaybackMarker && viewModel.showGPSLocationMarker,
            showRoutePolyline: false,
            cameraDistance: viewModel.playbackCameraDistance,
            onCameraDistanceChanged: { newDistance in
                viewModel.playbackCameraDistance = newDistance
                viewModel.handleCameraDistanceChange(newDistance)
            },
            onLongPress: { coordinate in
                viewModel.handleMapLongPress(coordinate)
            },
            onMarkerTap: { marker in
                viewModel.handleMarkerTap(marker)
            },
            cameraTrigger: viewModel.cameraTrigger
        )
        .ignoresSafeArea()
    }

    private var toolbarContent: some View {
        HStack(spacing: 16) {
            Button {
                if presentationMode == .sheet {
                    viewModel.addNoteAtCurrentPlaybackPosition()
                } else {
                    // For column mode, open note editor in sheet
                    if let coord = viewModel.interpolatedCoordinate ?? viewModel.sortedLocationPoints.first?.coordinate {
                        let context = NoteEditorContext(
                            coordinate: coord,
                            linkedStationEvent: nil,
                            linkedStation: nil,
                            existingNote: nil
                        )
                        viewModel.toolbarSheetContent = .noteEditor(context)
                    }
                }
            } label: {
                Image(systemName: "note.text.badge.plus")
            }

            Button {
                if presentationMode == .sheet {
                    viewModel.sheetContent = .playbackSettings
                } else {
                    viewModel.toolbarSheetContent = .playbackSettings
                }
            } label: {
                Image(systemName: "slider.horizontal.3")
            }

            ExportMenuButton(
                viewModel: viewModel,
                exportViewModel: exportViewModel,
                presentationMode: presentationMode
            )
        }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            mapView

            // Show playback controls on map in column mode (iPad/Mac)
            if presentationMode == .column {
                PlaybackControlsView(viewModel: viewModel)
                    .padding(.bottom, 8)
                    .padding(.horizontal)
            }
        }
        .modifier(ConditionalSheetModifier(
            presentationMode: presentationMode,
            sheetBinding: sheetBinding,
            viewModel: viewModel,
            exportViewModel: exportViewModel
        ))
        .sheet(item: $viewModel.toolbarSheetContent) { content in
            NavigationStack {
                toolbarSheetView(for: content)
            }
            .interactiveDismissDisabled()
        }
        .toolbar {
            #if os(iOS)
            ToolbarItem(placement: .topBarTrailing) {
                toolbarContent
            }
            #else
            ToolbarItem(placement: .automatic) {
                toolbarContent
            }
            #endif
        }
        .navigationTitle(viewModel.session.name)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
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

    @ViewBuilder
    private func toolbarSheetView(for content: ToolbarSheetContent) -> some View {
        switch content {
        case .playbackSettings:
            PlaybackSettingsContent(viewModel: viewModel)
                .navigationTitle("Playback Settings")
                #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
                #endif
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") {
                            viewModel.toolbarSheetContent = nil
                        }
                    }
                }
        case .exportCSV:
            CSVExportContent(
                session: viewModel.session,
                exportType: viewModel.selectedTab,
                exportViewModel: exportViewModel
            )
            .navigationTitle("Export CSV")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        viewModel.toolbarSheetContent = nil
                    }
                }
            }
        case .exportJSON:
            JSONExportContent(
                session: viewModel.session,
                exportType: viewModel.selectedTab,
                exportViewModel: exportViewModel
            )
            .navigationTitle("Export JSON")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        viewModel.toolbarSheetContent = nil
                    }
                }
            }
        case .exportVideo:
            VideoExportContent(
                session: viewModel.session,
                exportViewModel: exportViewModel
            )
            .navigationTitle("Export Video")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        viewModel.toolbarSheetContent = nil
                    }
                }
            }
        case .noteEditor(let context):
            NoteEditorView(context: context, viewModel: viewModel)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            viewModel.toolbarSheetContent = nil
                        }
                    }
                }
        }
    }
}

// MARK: - Conditional Sheet Modifier

/// A view modifier that conditionally applies sheet presentation based on presentation mode.
/// In sheet mode (iPhone), presents content as a sheet.
/// In column mode (iPad/Mac), does nothing as content is displayed in the third column.
struct ConditionalSheetModifier: ViewModifier {
    let presentationMode: PresentationMode
    let sheetBinding: Binding<SheetContent?>
    let viewModel: SessionDetailViewModel
    let exportViewModel: ExportViewModel

    func body(content: Content) -> some View {
        if presentationMode == .sheet {
            content
                .sheet(item: sheetBinding) { sheetContent in
                    SheetContentView(
                        content: sheetContent,
                        viewModel: viewModel,
                        exportViewModel: exportViewModel
                    )
                    .presentationDetents(sheetContent.isTabBar ? [.height(300), .medium, .large] : [.medium, .large])
                    .presentationDragIndicator(.visible)
                    .presentationBackgroundInteraction(sheetContent.isTabBar ? .enabled : .disabled)
                    .interactiveDismissDisabled()
                }
        } else {
            content
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
