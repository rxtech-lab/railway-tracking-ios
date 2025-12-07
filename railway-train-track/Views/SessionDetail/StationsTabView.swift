//
//  StationsTabView.swift
//  railway-train-track
//
//  Created by Qiwei Li on 12/6/25.
//

import SwiftUI

struct StationsTabView: View {
    @Bindable var viewModel: SessionDetailViewModel

    var body: some View {
        VStack {
            if viewModel.isAnalyzingStations {
                // Analysis in progress
                analysisProgressView
            } else if !viewModel.session.stationAnalysisCompleted {
                // Not yet analyzed
                analyzePromptView
            } else if viewModel.sortedStationEvents.isEmpty {
                // No stations found
                ContentUnavailableView(
                    "No Stations Detected",
                    systemImage: "train.side.front.car",
                    description: Text("No train stations were detected along this route. Try analyzing a route that passes through known railway stations.")
                )
            } else {
                // Station list with playback
                stationListView
            }
        }
    }

    // MARK: - Analysis Progress View

    private var analysisProgressView: some View {
        VStack(spacing: 20) {
            ProgressView(value: viewModel.analysisProgress) {
                Text("Analyzing route...")
            }
            .progressViewStyle(.linear)

            Text("Searching for train stations along your route")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            if viewModel.analysisProgress > 0 {
                Text("\(Int(viewModel.analysisProgress * 100))%")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(40)
    }

    // MARK: - Analyze Prompt View

    private var analyzePromptView: some View {
        VStack(spacing: 20) {
            Image(systemName: "train.side.front.car")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)

            Text("Detect Train Stations")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Analyze your route to find train stations you passed by. This will search OpenStreetMap data for railway stations near your recorded path.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal)

            Button {
                Task {
                    await viewModel.analyzeStations()
                }
            } label: {
                Label("Analyze Route", systemImage: "magnifyingglass")
                    .font(.headline)
            }
            .buttonStyle(.borderedProminent)

            if let error = viewModel.analysisError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding()
            }
        }
        .padding()
    }

    // MARK: - Station List View

    private var stationListView: some View {
        VStack(spacing: 0) {
            // Station playback controls
            StationPlaybackControlsView(viewModel: viewModel)

            // Summary header
            HStack {
                Label("\(viewModel.sortedStationEvents.count) stations", systemImage: "train.side.front.car")
                Spacer()
                Button {
                    viewModel.showStationSearchSheet = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                }
                EditButton()
                    .font(.caption)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding()
            .background(.ultraThinMaterial)

            // Station list
            List {
                ForEach(Array(viewModel.sortedStationEvents.enumerated()), id: \.element.id) { index, event in
                    StationRowView(event: event, index: index)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            // Seek to when we passed this station
                            viewModel.seekTo(index: event.entryPointIndex)
                        }
                }
                .onDelete { indexSet in
                    if let index = indexSet.first {
                        viewModel.confirmDeleteStation(viewModel.sortedStationEvents[index])
                    }
                }
                .onMove { source, destination in
                    viewModel.moveStationEvents(from: source, to: destination)
                }
            }
            .listStyle(.plain)
        }
        .confirmationDialog(
            "Delete Station?",
            isPresented: $viewModel.showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                viewModel.executeDeleteStation()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            if let station = viewModel.stationToDelete {
                Text("Are you sure you want to remove \(station.stationName) from this journey?")
            }
        }
        .sheet(isPresented: $viewModel.showStationSearchSheet) {
            StationSearchSheet(
                viewModel: viewModel,
                stationDataViewModel: viewModel.stationDataViewModel
            )
        }
    }
}

// MARK: - Station Row View

struct StationRowView: View {
    let event: StationPassEvent
    let index: Int

    var body: some View {
        HStack(spacing: 12) {
            // Station icon
            ZStack {
                Circle()
                    .fill(.orange.opacity(0.2))
                    .frame(width: 44, height: 44)
                Image(systemName: "train.side.front.car")
                    .foregroundStyle(.orange)
            }

            // Station info
            VStack(alignment: .leading, spacing: 4) {
                Text(event.stationName)
                    .font(.headline)

                HStack {
                    Label(event.formattedTime, systemImage: "clock")
                    Text("•")
                    Label(event.formattedDistance, systemImage: "arrow.left.and.right")
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                if let station = event.station {
                    Text(station.formattedCoordinate)
                        .font(.caption2.monospaced())
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            // Station number
            Text("#\(index + 1)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(8)
                .background(Color(.systemGray5))
                .clipShape(Circle())
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Station Playback Controls View

struct StationPlaybackControlsView: View {
    @Bindable var viewModel: SessionDetailViewModel

    var body: some View {
        VStack(spacing: 8) {
            // Progress slider
            Slider(
                value: Binding(
                    get: { Double(viewModel.selectedStationIndex) },
                    set: { viewModel.seekToStation(index: Int($0)) }
                ),
                in: 0...Double(max(1, viewModel.totalStations - 1))
            )
            .disabled(viewModel.totalStations <= 1)

            HStack {
                // Current station name
                if let event = viewModel.currentStationEvent {
                    Text(event.stationName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                // Playback controls
                HStack(spacing: 20) {
                    Button {
                        viewModel.seekToFirstStation()
                    } label: {
                        Image(systemName: "backward.end.fill")
                    }

                    Button {
                        viewModel.toggleStationPlayback()
                    } label: {
                        Image(systemName: viewModel.isPlayingStationAnimation ? "pause.fill" : "play.fill")
                            .font(.title2)
                    }

                    Button {
                        viewModel.seekToLastStation()
                    } label: {
                        Image(systemName: "forward.end.fill")
                    }
                }
                .disabled(viewModel.totalStations <= 1)

                Spacer()

                // Station count
                Text("\(viewModel.selectedStationIndex + 1)/\(viewModel.totalStations)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Fetch railway routes button
            if viewModel.stationDataViewModel.railwayRoutes.isEmpty && !viewModel.sortedStationEvents.isEmpty {
                Button {
                    Task {
                        await viewModel.fetchRailwayRoutes()
                    }
                } label: {
                    if viewModel.stationDataViewModel.isFetchingRailways {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Label("Load Railway Lines", systemImage: "point.topleft.down.to.point.bottomright.curvepath")
                            .font(.caption)
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(viewModel.stationDataViewModel.isFetchingRailways)
            }
        }
        .padding()
        .background(.ultraThinMaterial)
    }
}

#Preview {
    StationsTabView(viewModel: SessionDetailViewModel(session: TrackingSession(name: "Test")))
}
