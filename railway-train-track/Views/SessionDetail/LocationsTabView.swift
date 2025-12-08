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
                    .padding()
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

#Preview {
    LocationsTabView(viewModel: SessionDetailViewModel(session: TrackingSession(name: "Test")))
}
