//
//  ResumeTrackingButton.swift
//  railway-train-track
//
//  Created by Qiwei Li on 12/8/25.
//

import SwiftUI

struct ResumeTrackingButton: View {
    let session: TrackingSession
    let onClick: () -> Void
    @Environment(TrackingViewModel.self) var trackingViewModel
    
    
    var body: some View {
        if !session.isActive && !trackingViewModel.hasActiveSession {
            Button {
                trackingViewModel.resumeFinishedSession(session)
                onClick()
            } label: {
                Label("Resume Tracking", systemImage: "play.fill")
            }
        }
    }
}
