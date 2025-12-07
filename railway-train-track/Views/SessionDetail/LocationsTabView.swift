//
//  LocationsTabView.swift
//  railway-train-track
//
//  Created by Qiwei Li on 12/6/25.
//

import MapKit
import SwiftUI

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
                ScrollView {
                    LazyVStack {
                        ForEach(Array(viewModel.sortedLocationPoints.enumerated()), id: \.element.id) { index, point in
                            LocationRowView(
                                point: point,
                                index: index,
                                isSelected: index == viewModel.selectedLocationIndex
                            )
                            .onTapGesture {
                                viewModel.seekTo(index: index)
                            }
                        }
                    }
                }
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
            // Time-based progress slider
            Slider(
                value: Binding(
                    get: { viewModel.playbackElapsedTime },
                    set: { viewModel.seekToTime($0) }
                ),
                in: 0...viewModel.playbackDurationSeconds
            )
            .disabled(viewModel.totalLocationPoints <= 1)

            HStack {
                // Elapsed / Total time
                Text(viewModel.formattedPlaybackTime)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)

                Spacer()

                // Playback controls
                HStack(spacing: 20) {
                    Button {
                        viewModel.seekToBeginningTimeBased()
                    } label: {
                        Image(systemName: "backward.end.fill")
                    }
                    .disabled(viewModel.totalLocationPoints <= 1)

                    Button {
                        viewModel.toggleTimeBasedPlayback()
                    } label: {
                        Image(systemName: viewModel.isPlayingAnimation ? "pause.fill" : "play.fill")
                            .font(.title2)
                    }
                    .disabled(viewModel.totalLocationPoints <= 1)

                    Button {
                        viewModel.seekToEndTimeBased()
                    } label: {
                        Image(systemName: "forward.end.fill")
                    }
                    .disabled(viewModel.totalLocationPoints <= 1)
                }

            }

            // Session info
            HStack {
                Label("\(viewModel.totalLocationPoints) points", systemImage: "mappin.and.ellipse")
                Spacer()
                Label("Duration: \(formatDuration(viewModel.playbackDurationSeconds))", systemImage: "timer")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding()
        .background(.ultraThinMaterial)
    }

    private func formatDuration(_ seconds: Double) -> String {
        let s = Int(seconds)
        if s >= 60 {
            return "\(s / 60)m \(s % 60)s"
        } else {
            return "\(s)s"
        }
    }
}

#Preview {
    LocationsTabView(viewModel: SessionDetailViewModel(session: TrackingSession(name: "Test")))
}
