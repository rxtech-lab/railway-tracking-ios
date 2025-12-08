//
//  railway_train_trackApp.swift
//  railway-train-track
//
//  Created by Qiwei Li on 12/6/25.
//

import SwiftUI
import SwiftData

@main
struct railway_train_trackApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            TrackingSession.self,
            LocationPoint.self,
            TrainStation.self,
            StationPassEvent.self,
            RailwayRoute.self,
            SessionNote.self,
            SessionPhoto.self,
        ])
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false
        )

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    @State private var trackingViewModel = TrackingViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(trackingViewModel)
        }
        .modelContainer(sharedModelContainer)
    }
}
