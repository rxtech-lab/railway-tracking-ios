//
//  ExportMenuView.swift
//  railway-train-track
//
//  Created by Qiwei Li on 12/6/25.
//

import SwiftUI

struct ExportMenuButton: View {
    @Bindable var viewModel: SessionDetailViewModel
    @Bindable var exportViewModel: ExportViewModel

    var body: some View {
        Menu {
            Section("Data Export") {
                Button {
                    viewModel.sheetContent = .exportCSV
                } label: {
                    Label("Export CSV", systemImage: "tablecells")
                }

                Button {
                    viewModel.sheetContent = .exportJSON
                } label: {
                    Label("Export JSON", systemImage: "curlybraces")
                }
            }

            if viewModel.selectedTab == .stations && viewModel.session.stationAnalysisCompleted {
                Section("Video Export") {
                    Button {
                        viewModel.sheetContent = .exportVideo
                    } label: {
                        Label("Export Video", systemImage: "film")
                    }
                }
            }
        } label: {
            Image(systemName: "square.and.arrow.up")
        }
    }
}

// MARK: - CSV Export Content

struct CSVExportContent: View {
    let session: TrackingSession
    let exportType: SessionTab
    @Bindable var exportViewModel: ExportViewModel

    var body: some View {
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

            Section {
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
        .sheet(isPresented: $exportViewModel.showShareSheet) {
            if let url = exportViewModel.exportedFileURL {
                ShareSheet(items: [url])
            }
        }
        .onAppear {
            exportViewModel.setDefaultFilename(from: session)
        }
    }
}

// MARK: - JSON Export Content

struct JSONExportContent: View {
    let session: TrackingSession
    let exportType: SessionTab
    @Bindable var exportViewModel: ExportViewModel

    var body: some View {
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

            Section {
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
        .sheet(isPresented: $exportViewModel.showShareSheet) {
            if let url = exportViewModel.exportedFileURL {
                ShareSheet(items: [url])
            }
        }
        .onAppear {
            exportViewModel.setDefaultFilename(from: session)
        }
    }
}

// MARK: - Video Export Content

struct VideoExportContent: View {
    let session: TrackingSession
    @Bindable var exportViewModel: ExportViewModel

    @State private var includeStations = true

    var body: some View {
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

            Section {
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
        .sheet(isPresented: $exportViewModel.showShareSheet) {
            if let url = exportViewModel.exportedFileURL {
                ShareSheet(items: [url])
            }
        }
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
        viewModel: SessionDetailViewModel(session: TrackingSession(name: "Test")),
        exportViewModel: ExportViewModel()
    )
}
