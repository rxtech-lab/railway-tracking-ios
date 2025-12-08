//
//  StopAndPauseTrackingButton.swift
//  railway-train-track
//
//  Created by Qiwei Li on 12/8/25.
//

import SwiftUI

public struct StopAndPauseTrackingButton: View {
    let showPauseButton: Bool
    @Environment(TrackingViewModel.self) var viewModel
    @Environment(\.dismiss) private var dismiss
    
    init(showPauseButton: Bool = true) {
        self.showPauseButton = showPauseButton
    }

    public var body: some View {
        if showPauseButton {
            Button {
                if viewModel.isPaused {
                    viewModel.resumeSession()
                } else {
                    viewModel.pauseSession()
                }
            } label: {
                Label(
                    viewModel.isPaused ? "Resume" : "Pause",
                    systemImage: viewModel.isPaused ? "play.fill" : "pause.fill"
                )
            }
        }

        if viewModel.hasActiveSession {
            Button(role: .destructive) {
                viewModel.stopSession()
                dismiss()
            } label: {
                Label("Stop", systemImage: "stop.fill")
                    .foregroundStyle(.red)
            }
        }
    }
}
