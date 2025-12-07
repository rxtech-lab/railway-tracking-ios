//
//  PlaybackSettingsSheet.swift
//  railway-train-track
//
//  Created by Qiwei Li on 12/7/25.
//

import SwiftUI

struct PlaybackSettingsSheet: View {
    @Bindable var viewModel: SessionDetailViewModel
    @Environment(\.dismiss) private var dismiss

    private let speedOptions: [Double] = [0.25, 0.5, 1.0, 2.0, 4.0, 8.0, 16.0]

    var body: some View {
        NavigationStack {
            Form {
                Section("Playback Speed") {
                    Picker("Speed", selection: $viewModel.playbackSpeed) {
                        ForEach(speedOptions, id: \.self) { speed in
                            Text(formatSpeed(speed))
                                .tag(speed)
                        }
                    }
                    .pickerStyle(.segmented)

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Fine-tune")
                                .font(.subheadline)
                            Spacer()
                            Text(formatSpeed(viewModel.playbackSpeed))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }

                        Slider(value: $viewModel.playbackSpeed, in: 0.25...16.0, step: 0.25)
                    }
                    .padding(.vertical, 8)
                }

                Section {
                    Text("Higher speeds play through locations faster. Use slower speeds to examine route details.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Playback Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func formatSpeed(_ speed: Double) -> String {
        if speed == floor(speed) {
            return String(format: "%.0fx", speed)
        } else if speed * 10 == floor(speed * 10) {
            return String(format: "%.1fx", speed)
        } else {
            return String(format: "%.2fx", speed)
        }
    }
}

#Preview {
    PlaybackSettingsSheet(viewModel: SessionDetailViewModel(session: TrackingSession(name: "Test")))
}
