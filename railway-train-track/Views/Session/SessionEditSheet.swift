//
//  SessionEditSheet.swift
//  railway-train-track
//
//  Created by Qiwei Li on 12/7/25.
//

import SwiftUI

struct SessionEditSheet: View {
    @Bindable var session: TrackingSession
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Session Name") {
                    TextField("Enter session name", text: $session.name)
                }

                Section("Recording Interval") {
                    HStack {
                        Text("\(session.recordingInterval, specifier: "%.1f")s")
                            .font(.headline)
                            .frame(width: 50)

                        Slider(
                            value: $session.recordingInterval,
                            in: 0.5 ... 10,
                            step: 0.5
                        )
                    }

                    Text("GPS recording frequency for this session")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Edit Session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .bottomBar) {
                    ResumeTrackingButton(session: session) {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    SessionEditSheet(session: TrackingSession(name: "Test Session"))
}
