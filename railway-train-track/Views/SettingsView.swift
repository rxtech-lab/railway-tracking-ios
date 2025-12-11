//
//  SettingsView.swift
//  railway-train-track
//
//  Created by Qiwei Li on 12/6/25.
//

import SwiftUI
import CoreLocation
#if os(iOS)
import UIKit
#endif

struct SettingsView: View {
    @Environment(TrackingViewModel.self) private var viewModel

    var body: some View {
        NavigationStack {
            Form {
                Section("Recording") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Recording Interval")
                            Spacer()
                            Text("\(viewModel.recordingInterval, specifier: "%.1f") seconds")
                                .foregroundStyle(.secondary)
                        }

                        Slider(value: Binding(
                            get: { viewModel.recordingInterval },
                            set: { viewModel.updateRecordingInterval($0) }
                        ), in: 0.5...10, step: 0.5)
                    }

                    Text("Shorter intervals capture more detail but use more storage and battery.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("GPS Accuracy Threshold")
                            Spacer()
                            Text("\(viewModel.accuracyThreshold, specifier: "%.0f") meters")
                                .foregroundStyle(.secondary)
                        }

                        Slider(value: Binding(
                            get: { viewModel.accuracyThreshold },
                            set: { viewModel.updateAccuracyThreshold($0) }
                        ), in: 10...100, step: 10)
                    }

                    Text("Locations with accuracy worse than this threshold will be filtered out. Lower values are more strict.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Location Permission") {
                    HStack {
                        Text("Status")
                        Spacer()
                        Text(authorizationStatusText)
                            .foregroundStyle(authorizationStatusColor)
                    }

                    if !viewModel.canTrack {
                        Button("Request Permission") {
                            viewModel.requestLocationPermission()
                        }
                    }

                    #if os(iOS)
                    if viewModel.locationAuthorizationStatus == .authorizedWhenInUse {
                        Text("For background tracking during your journey, please allow 'Always' location access in Settings.")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                    #endif

                    #if os(iOS)
                    if viewModel.locationAuthorizationStatus != .authorizedAlways {
                        Button {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        } label: {
                            Label("Open Settings", systemImage: "gear")
                        }
                    }
                    #endif
                }

                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundStyle(.secondary)
                    }
                
                }

            }
            .navigationTitle("Settings")
        }
    }

    private var authorizationStatusText: String {
        switch viewModel.locationAuthorizationStatus {
        case .notDetermined:
            return "Not Determined"
        case .restricted:
            return "Restricted"
        case .denied:
            return "Denied"
        case .authorizedWhenInUse:
            return "When In Use"
        case .authorizedAlways:
            return "Always"
        @unknown default:
            return "Unknown"
        }
    }

    private var authorizationStatusColor: Color {
        switch viewModel.locationAuthorizationStatus {
        case .authorizedAlways:
            return .green
        case .authorizedWhenInUse:
            return .orange
        case .denied, .restricted:
            return .red
        default:
            return .secondary
        }
    }
}

#Preview {
    SettingsView()
        .environment(TrackingViewModel())
}
