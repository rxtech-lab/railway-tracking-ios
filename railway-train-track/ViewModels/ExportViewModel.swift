//
//  ExportViewModel.swift
//  railway-train-track
//
//  Created by Qiwei Li on 12/6/25.
//

import Foundation
import SwiftData

@Observable
final class ExportViewModel {
    // State
    var isExporting: Bool = false
    var exportProgress: Double = 0
    var exportedFileURL: URL?
    var errorMessage: String?
    var showShareSheet: Bool = false

    // CSV Settings
    var csvFilename: String = ""

    // Video Settings
    var selectedResolution: VideoResolution = .hd1080p

    // Services
    private let csvExporter = CSVExporter()
    private let jsonExporter = JSONExporter()
    private let videoExporter = VideoExporter()

    init() {}

    func setDefaultFilename(from session: TrackingSession) {
        csvFilename = session.name
            .replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "/", with: "-")
    }

    // MARK: - CSV Export

    func exportLocationsCSV(session: TrackingSession) async {
        isExporting = true
        exportProgress = 0
        errorMessage = nil

        do {
            let filename = csvFilename.isEmpty ? "locations_export" : csvFilename
            let url = try await csvExporter.exportLocations(
                session: session,
                filename: filename
            ) { [weak self] progress in
                self?.exportProgress = progress
            }
            exportedFileURL = url
            showShareSheet = true
        } catch {
            errorMessage = error.localizedDescription
        }

        isExporting = false
    }

    func exportStationsCSV(session: TrackingSession) async {
        isExporting = true
        exportProgress = 0
        errorMessage = nil

        do {
            let filename = csvFilename.isEmpty ? "stations_export" : "\(csvFilename)_stations"
            let url = try await csvExporter.exportStations(
                session: session,
                filename: filename
            ) { [weak self] progress in
                self?.exportProgress = progress
            }
            exportedFileURL = url
            showShareSheet = true
        } catch {
            errorMessage = error.localizedDescription
        }

        isExporting = false
    }

    // MARK: - JSON Export

    func exportLocationsJSON(session: TrackingSession) async {
        isExporting = true
        exportProgress = 0
        errorMessage = nil

        do {
            let filename = csvFilename.isEmpty ? "locations_export" : csvFilename
            let url = try await jsonExporter.exportLocations(
                session: session,
                filename: filename
            ) { [weak self] progress in
                self?.exportProgress = progress
            }
            exportedFileURL = url
            showShareSheet = true
        } catch {
            errorMessage = error.localizedDescription
        }

        isExporting = false
    }

    func exportStationsJSON(session: TrackingSession) async {
        isExporting = true
        exportProgress = 0
        errorMessage = nil

        do {
            let filename = csvFilename.isEmpty ? "stations_export" : "\(csvFilename)_stations"
            let url = try await jsonExporter.exportStations(
                session: session,
                filename: filename
            ) { [weak self] progress in
                self?.exportProgress = progress
            }
            exportedFileURL = url
            showShareSheet = true
        } catch {
            errorMessage = error.localizedDescription
        }

        isExporting = false
    }

    // MARK: - Video Export

    func exportVideo(session: TrackingSession, includeStations: Bool = true) async {
        isExporting = true
        exportProgress = 0
        errorMessage = nil

        do {
            let url = try await videoExporter.export(
                session: session,
                resolution: selectedResolution,
                includeStations: includeStations
            ) { [weak self] progress in
                self?.exportProgress = progress
            }
            exportedFileURL = url
            showShareSheet = true
        } catch {
            errorMessage = error.localizedDescription
        }

        isExporting = false
    }

    // MARK: - Helpers

    func resetExportState() {
        isExporting = false
        exportProgress = 0
        exportedFileURL = nil
        errorMessage = nil
        showShareSheet = false
    }
}
