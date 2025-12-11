//
//  PlaybackControlsView.swift
//  railway-train-track
//
//  Created by Qiwei Li on 12/6/25.
//

import SwiftUI

struct PlaybackControlsView: View {
    @Bindable var viewModel: SessionDetailViewModel
    @State private var sliderValue: Double = 0
    @State private var isDragging: Bool = false

    var body: some View {
        VStack(spacing: 8) {
            // Time-based progress slider
            Slider(
                value: $sliderValue,
                in: 0...viewModel.playbackDurationSeconds,
                onEditingChanged: { editing in
                    isDragging = editing
                    if !editing {
                        // Only update viewModel when drag finishes
                        viewModel.seekToTime(sliderValue)
                    }
                }
            )
            .disabled(viewModel.totalLocationPoints <= 1)
            .onChange(of: viewModel.playbackElapsedTime) { _, newValue in
                // Sync slider with playback when not dragging
                if !isDragging {
                    sliderValue = newValue
                }
            }

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
    PlaybackControlsView(viewModel: SessionDetailViewModel(session: TrackingSession(name: "Test")))
}
