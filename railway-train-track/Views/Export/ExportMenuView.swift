//
//  ExportMenuView.swift
//  railway-train-track
//
//  Created by Qiwei Li on 12/6/25.
//

import SwiftUI

struct ExportMenuButton: View {
    let session: TrackingSession
    let currentTab: SessionTab
    @Bindable var exportViewModel: ExportViewModel

    @State private var showCSVExport = false
    @State private var showJSONExport = false
    @State private var showVideoExport = false

    var body: some View {
        Menu {
            Section("Data Export") {
                Button {
                    showCSVExport = true
                } label: {
                    Label("Export CSV", systemImage: "tablecells")
                }

                Button {
                    showJSONExport = true
                } label: {
                    Label("Export JSON", systemImage: "curlybraces")
                }
            }

            if currentTab == .stations && session.stationAnalysisCompleted {
                Section("Video Export") {
                    Button {
                        showVideoExport = true
                    } label: {
                        Label("Export Video", systemImage: "film")
                    }
                }
            }
        } label: {
            Image(systemName: "square.and.arrow.up")
        }
        .sheet(isPresented: $showCSVExport) {
            CSVExportView(
                session: session,
                exportType: currentTab,
                exportViewModel: exportViewModel
            )
        }
        .sheet(isPresented: $showJSONExport) {
            JSONExportView(
                session: session,
                exportType: currentTab,
                exportViewModel: exportViewModel
            )
        }
        .sheet(isPresented: $showVideoExport) {
            VideoExportView(
                session: session,
                exportViewModel: exportViewModel
            )
        }
    }
}

// MARK: - CSV Export View

struct CSVExportView: View {
    let session: TrackingSession
    let exportType: SessionTab
    @Bindable var exportViewModel: ExportViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("File Name") {
                    TextField("Enter filename", text: $exportViewModel.csvFilename)
                    Text("File will be saved as: \(exportViewModel.csvFilename.isEmpty ? "export" : exportViewModel.csvFilename).csv")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Export Type") {
                    HStack {
                        Text("Content")
                        Spacer()
                        Text(exportType == .locations ? "Location Points" : "Station Pass Events")
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text("Records")
                        Spacer()
                        Text("\(exportType == .locations ? session.locationPoints.count : session.stationPassEvents.count)")
                            .foregroundStyle(.secondary)
                    }
                }

                if exportViewModel.isExporting {
                    Section {
                        ProgressView(value: exportViewModel.exportProgress) {
                            Text("Exporting...")
                        }
                    }
                }

                if let error = exportViewModel.errorMessage {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Export CSV")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Export") {
                        Task {
                            if exportType == .locations {
                                await exportViewModel.exportLocationsCSV(session: session)
                            } else {
                                await exportViewModel.exportStationsCSV(session: session)
                            }
                        }
                    }
                    .disabled(exportViewModel.isExporting)
                }
            }
            .sheet(isPresented: $exportViewModel.showShareSheet) {
                if let url = exportViewModel.exportedFileURL {
                    ShareSheet(items: [url])
                }
            }
        }
        .presentationDetents([.medium])
        .onAppear {
            exportViewModel.setDefaultFilename(from: session)
        }
    }
}

// MARK: - JSON Export View

struct JSONExportView: View {
    let session: TrackingSession
    let exportType: SessionTab
    @Bindable var exportViewModel: ExportViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("File Name") {
                    TextField("Enter filename", text: $exportViewModel.csvFilename)
                    Text("File will be saved as: \(exportViewModel.csvFilename.isEmpty ? "export" : exportViewModel.csvFilename).json")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Export Type") {
                    HStack {
                        Text("Content")
                        Spacer()
                        Text(exportType == .locations ? "Location Points" : "Station Pass Events")
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text("Format")
                        Spacer()
                        Text("JSON (Pretty Printed)")
                            .foregroundStyle(.secondary)
                    }
                }

                if exportViewModel.isExporting {
                    Section {
                        ProgressView(value: exportViewModel.exportProgress) {
                            Text("Exporting...")
                        }
                    }
                }

                if let error = exportViewModel.errorMessage {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Export JSON")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Export") {
                        Task {
                            if exportType == .locations {
                                await exportViewModel.exportLocationsJSON(session: session)
                            } else {
                                await exportViewModel.exportStationsJSON(session: session)
                            }
                        }
                    }
                    .disabled(exportViewModel.isExporting)
                }
            }
            .sheet(isPresented: $exportViewModel.showShareSheet) {
                if let url = exportViewModel.exportedFileURL {
                    ShareSheet(items: [url])
                }
            }
        }
        .presentationDetents([.medium])
        .onAppear {
            exportViewModel.setDefaultFilename(from: session)
        }
    }
}

// MARK: - Video Export View

struct VideoExportView: View {
    let session: TrackingSession
    @Bindable var exportViewModel: ExportViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var includeStations = true

    var body: some View {
        NavigationStack {
            Form {
                Section("Resolution") {
                    Picker("Video Resolution", selection: $exportViewModel.selectedResolution) {
                        ForEach(VideoResolution.allCases) { resolution in
                            Text(resolution.rawValue).tag(resolution)
                        }
                    }
                    .pickerStyle(.menu)

                    HStack {
                        Text("Size")
                        Spacer()
                        Text("\(Int(exportViewModel.selectedResolution.size.width)) x \(Int(exportViewModel.selectedResolution.size.height))")
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Options") {
                    Toggle("Include Station Markers", isOn: $includeStations)

                    HStack {
                        Text("Frame Rate")
                        Spacer()
                        Text("30 fps")
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text("Location Points")
                        Spacer()
                        Text("\(session.locationPoints.count)")
                            .foregroundStyle(.secondary)
                    }
                }

                if exportViewModel.isExporting {
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            ProgressView(value: exportViewModel.exportProgress) {
                                Text("Rendering video...")
                            }
                            Text("This may take a few minutes for high resolution videos.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                if let error = exportViewModel.errorMessage {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                    }
                }

                Section {
                    Text("The video will show an animated playback of your journey on the map, with the route being drawn progressively.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Export Video")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Export") {
                        Task {
                            await exportViewModel.exportVideo(
                                session: session,
                                includeStations: includeStations
                            )
                        }
                    }
                    .disabled(exportViewModel.isExporting || session.locationPoints.isEmpty)
                }
            }
            .sheet(isPresented: $exportViewModel.showShareSheet) {
                if let url = exportViewModel.exportedFileURL {
                    ShareSheet(items: [url])
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    ExportMenuButton(
        session: TrackingSession(name: "Test"),
        currentTab: .locations,
        exportViewModel: ExportViewModel()
    )
}
