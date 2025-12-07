//
//  NewSessionSheet.swift
//  railway-train-track
//
//  Created by Qiwei Li on 12/7/25.
//

import SwiftUI

struct NewSessionSheet: View {
    @Environment(TrackingViewModel.self) private var viewModel
    @Environment(\.dismiss) private var dismiss
    @State private var sessionName: String = ""

    var onSessionCreated: ((TrackingSession) -> Void)?

    var body: some View {
        NavigationStack {
            Form {
                Section("Session Name") {
                    TextField("Enter session name", text: $sessionName)
                }

                Section {
                    Text("Leave empty to use default name with timestamp")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Recording Interval") {
                    HStack {
                        Text("\(viewModel.recordingInterval, specifier: "%.1f")s")
                            .font(.headline)
                            .frame(width: 50)

                        Slider(value: Binding(
                            get: { viewModel.recordingInterval },
                            set: { viewModel.updateRecordingInterval($0) }
                        ), in: 0.5 ... 10, step: 0.5)
                    }

                    Text("How often to record GPS location")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("New Session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Start") {
                        viewModel.startNewSession(name: sessionName)
                        dismiss()
                        if let session = viewModel.currentSession {
                            onSessionCreated?(session)
                        }
                    }
                }
            }
        }
    }
}

#Preview {
    NewSessionSheet()
        .environment(TrackingViewModel())
}
