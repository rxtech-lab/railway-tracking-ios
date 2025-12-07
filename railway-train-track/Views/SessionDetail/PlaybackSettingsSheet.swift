//
//  PlaybackSettingsSheet.swift
//  railway-train-track
//
//  Created by Qiwei Li on 12/7/25.
//

import SwiftUI

struct PlaybackSettingsContent: View {
    @Bindable var viewModel: SessionDetailViewModel
    @State private var durationText: String = ""
    @FocusState private var isDurationFieldFocused: Bool

    private let speedOptions: [Double] = [0.5, 1.0, 2.0, 4.0, 8.0]

    var body: some View {
        Form {
            // Playback Duration Section
            Section("Playback Duration") {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Duration (seconds)")
                            .font(.subheadline)
                        Spacer()
                        TextField("30", text: $durationText)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                            .textFieldStyle(.roundedBorder)
                            .focused($isDurationFieldFocused)
                            .onChange(of: durationText) { _, newValue in
                                if let value = Double(newValue), value > 0 {
                                    viewModel.playbackDurationSeconds = value
                                }
                            }
                    }

                    // Quick duration buttons
                    HStack(spacing: 8) {
                        ForEach([10, 30, 60, 120, 300], id: \.self) { seconds in
                            Button(formatQuickDuration(seconds)) {
                                viewModel.playbackDurationSeconds = Double(seconds)
                                durationText = "\(seconds)"
                            }
                            .buttonStyle(.bordered)
                            .tint(viewModel.playbackDurationSeconds == Double(seconds) ? .blue : .gray)
                        }
                    }
                    .font(.caption)

                    // Stepper for fine adjustment
                    Stepper(
                        "Adjust: \(Int(viewModel.playbackDurationSeconds))s",
                        value: Binding(
                            get: { viewModel.playbackDurationSeconds },
                            set: {
                                viewModel.playbackDurationSeconds = max(1, $0)
                                durationText = "\(Int(viewModel.playbackDurationSeconds))"
                            }
                        ),
                        in: 1...3600,
                        step: 5
                    )
                    .font(.subheadline)
                }

                // Journey info
                VStack(alignment: .leading, spacing: 4) {
                    Text("Original journey: \(viewModel.formattedJourneyDuration)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("Compression: \(compressionRatio)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

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

                    Slider(value: $viewModel.playbackSpeed, in: 0.25...8.0, step: 0.25)
                }
                .padding(.vertical, 8)
            }

            Section {
                Text("Set the total playback duration to compress your journey. Speed controls how fast the animation plays within that duration.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .onAppear {
            durationText = "\(Int(viewModel.playbackDurationSeconds))"
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    isDurationFieldFocused = false
                }
            }
        }
    }

    private var compressionRatio: String {
        guard viewModel.journeyDuration > 0 else { return "N/A" }
        let ratio = viewModel.journeyDuration / viewModel.playbackDurationSeconds
        return String(format: "%.1fx faster", ratio)
    }

    private func formatQuickDuration(_ seconds: Int) -> String {
        if seconds < 60 {
            return "\(seconds)s"
        } else {
            return "\(seconds / 60)m"
        }
    }

    private func formatSpeed(_ speed: Double) -> String {
        if speed == floor(speed) {
            return String(format: "%.0fx", speed)
        } else {
            return String(format: "%.1fx", speed)
        }
    }
}

#Preview {
    PlaybackSettingsContent(viewModel: SessionDetailViewModel(session: TrackingSession(name: "Test")))
}
