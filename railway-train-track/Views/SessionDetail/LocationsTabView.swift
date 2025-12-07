//
//  LocationsTabView.swift
//  railway-train-track
//
//  Created by Qiwei Li on 12/6/25.
//

import SwiftUI
import MapKit

struct LocationsTabView: View {
    @Bindable var viewModel: SessionDetailViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Playback controls
            PlaybackControlsView(viewModel: viewModel)

            // Location list
            if viewModel.sortedLocationPoints.isEmpty {
                ContentUnavailableView(
                    "No Locations",
                    systemImage: "location.slash",
                    description: Text("No GPS points were recorded in this session.")
                )
            } else {
                List {
                    ForEach(Array(viewModel.sortedLocationPoints.enumerated()), id: \.element.id) { index, point in
                        LocationRowView(
                            point: point,
                            index: index,
                            isSelected: index == viewModel.selectedLocationIndex
                        )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            viewModel.seekTo(index: index)
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
    }
}

// MARK: - Location Row View

struct LocationRowView: View {
    let point: LocationPoint
    let index: Int
    let isSelected: Bool

    var body: some View {
        HStack {
            // Index and time
            VStack(alignment: .leading, spacing: 2) {
                Text("#\(index + 1)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(point.timestamp, style: .time)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .frame(width: 70, alignment: .leading)

            Divider()

            // Coordinates
            VStack(alignment: .leading, spacing: 2) {
                Text(point.formattedCoordinate)
                    .font(.caption.monospaced())
                Text(point.formattedAltitude)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Speed
            VStack(alignment: .trailing, spacing: 2) {
                Text(point.formattedSpeed)
                    .font(.caption)
                    .fontWeight(.medium)
                Text("speed")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 4)
        .background(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Playback Controls View

struct PlaybackControlsView: View {
    @Bindable var viewModel: SessionDetailViewModel

    var body: some View {
        VStack(spacing: 8) {
            // Progress slider
            Slider(
                value: Binding(
                    get: { Double(viewModel.selectedLocationIndex) },
                    set: { viewModel.seekTo(index: Int($0)) }
                ),
                in: 0...Double(max(1, viewModel.totalLocationPoints - 1))
            )
            .disabled(viewModel.totalLocationPoints <= 1)

            HStack {
                // Current time
                if let point = viewModel.currentLocationPoint {
                    Text(point.timestamp, style: .time)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Playback controls
                HStack(spacing: 20) {
                    Button {
                        viewModel.seekToBeginning()
                    } label: {
                        Image(systemName: "backward.end.fill")
                    }
                    .disabled(viewModel.totalLocationPoints <= 1)

                    Button {
                        viewModel.togglePlayback()
                    } label: {
                        Image(systemName: viewModel.isPlayingAnimation ? "pause.fill" : "play.fill")
                            .font(.title2)
                    }
                    .disabled(viewModel.totalLocationPoints <= 1)

                    Button {
                        viewModel.seekToEnd()
                    } label: {
                        Image(systemName: "forward.end.fill")
                    }
                    .disabled(viewModel.totalLocationPoints <= 1)
                }

                Spacer()

                // Speed selector
                Menu {
                    ForEach([0.5, 1.0, 2.0, 4.0, 8.0], id: \.self) { speed in
                        Button("\(speed, specifier: "%.1f")x") {
                            viewModel.playbackSpeed = speed
                        }
                    }
                } label: {
                    Text("\(viewModel.playbackSpeed, specifier: "%.1f")x")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(.systemGray5))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
            }

            // Session info
            HStack {
                Label("\(viewModel.totalLocationPoints) points", systemImage: "mappin.and.ellipse")
                Spacer()
                if let point = viewModel.currentLocationPoint {
                    Label(point.formattedSpeed, systemImage: "speedometer")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding()
        .background(.ultraThinMaterial)
    }
}

#Preview {
    LocationsTabView(viewModel: SessionDetailViewModel(session: TrackingSession(name: "Test")))
}
