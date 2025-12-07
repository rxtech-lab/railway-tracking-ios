//
//  ContentView.swift
//  railway-train-track
//
//  Created by Qiwei Li on 12/6/25.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(TrackingViewModel.self) private var trackingViewModel

    var body: some View {
        TabView {
            SessionListView()
                .tabItem {
                    Label("Sessions", systemImage: "list.bullet")
                }

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
        }
        .onAppear {
            trackingViewModel.setModelContext(modelContext)
            trackingViewModel.checkForRecoverableSession()
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [TrackingSession.self, LocationPoint.self, TrainStation.self, StationPassEvent.self], inMemory: true)
        .environment(TrackingViewModel())
}
