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
                        "Adjust: \(formatDurationHHMMSS(viewModel.playbackDurationSeconds))",
                        value: Binding(
                            get: { viewModel.playbackDurationSeconds },
                            set: {
                                viewModel.playbackDurationSeconds = max(1, $0)
                                durationText = "\(Int(viewModel.playbackDurationSeconds))"
                            }
                        ),
                        in: 1 ... 3600,
                        step: 5
                    )
                    .font(.subheadline)
                }
            }

            // Route Source Section (Mutually Exclusive)
            Section("Route Source") {
                Picker("Route Source", selection: $viewModel.routeSourceMode) {
                    ForEach(RouteSourceMode.allCases, id: \.self) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .pickerStyle(.menu)

                Text(viewModel.routeSourceMode.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Display Options Section (Multiple Selection)
            Section("Display Options") {
                Toggle("Show Railroad", isOn: $viewModel.showRailroad)
                Toggle("Show Station Markers", isOn: $viewModel.showStationMarkers)
                Toggle("Show GPS Location Marker", isOn: $viewModel.showGPSLocationMarker)
            }

            Section {
                Text("Set the total playback duration to compress your journey. The position updates once per second during playback.")
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

    private func formatDurationHHMMSS(_ seconds: Double) -> String {
        let totalSeconds = Int(seconds)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let secs = totalSeconds % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, secs)
    }
}

#Preview {
    PlaybackSettingsContent(viewModel: SessionDetailViewModel(session: TrackingSession(name: "Test")))
}
