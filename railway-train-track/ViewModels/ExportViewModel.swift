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
    var showProgressModal: Bool = false
    var currentExportType: ExportType = .csv
    var totalItemsToExport: Int = 0

    enum ExportType: String {
        case csv = "CSV"
        case json = "JSON"
        case video = "Video"
    }

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
        currentExportType = .csv
        totalItemsToExport = session.locationPoints.count
        showProgressModal = true

        do {
            let filename = csvFilename.isEmpty ? "locations_export" : csvFilename
            let url = try await csvExporter.exportLocations(
                session: session,
                filename: filename
            ) { [weak self] progress in
                self?.exportProgress = progress
            }
            exportedFileURL = url
            showProgressModal = false
            showShareSheet = true
        } catch {
            errorMessage = error.localizedDescription
            showProgressModal = false
        }

        isExporting = false
    }

    func exportStationsCSV(session: TrackingSession) async {
        isExporting = true
        exportProgress = 0
        errorMessage = nil
        currentExportType = .csv
        totalItemsToExport = session.stationPassEvents.count
        showProgressModal = true

        do {
            let filename = csvFilename.isEmpty ? "stations_export" : "\(csvFilename)_stations"
            let url = try await csvExporter.exportStations(
                session: session,
                filename: filename
            ) { [weak self] progress in
                self?.exportProgress = progress
            }
            exportedFileURL = url
            showProgressModal = false
            showShareSheet = true
        } catch {
            errorMessage = error.localizedDescription
            showProgressModal = false
        }

        isExporting = false
    }

    // MARK: - JSON Export

    func exportLocationsJSON(session: TrackingSession) async {
        isExporting = true
        exportProgress = 0
        errorMessage = nil
        currentExportType = .json
        totalItemsToExport = session.locationPoints.count
        showProgressModal = true

        do {
            let filename = csvFilename.isEmpty ? "locations_export" : csvFilename
            let url = try await jsonExporter.exportLocations(
                session: session,
                filename: filename
            ) { [weak self] progress in
                self?.exportProgress = progress
            }
            exportedFileURL = url
            showProgressModal = false
            showShareSheet = true
        } catch {
            errorMessage = error.localizedDescription
            showProgressModal = false
        }

        isExporting = false
    }

    func exportStationsJSON(session: TrackingSession) async {
        isExporting = true
        exportProgress = 0
        errorMessage = nil
        currentExportType = .json
        totalItemsToExport = session.stationPassEvents.count
        showProgressModal = true

        do {
            let filename = csvFilename.isEmpty ? "stations_export" : "\(csvFilename)_stations"
            let url = try await jsonExporter.exportStations(
                session: session,
                filename: filename
            ) { [weak self] progress in
                self?.exportProgress = progress
            }
            exportedFileURL = url
            showProgressModal = false
            showShareSheet = true
        } catch {
            errorMessage = error.localizedDescription
            showProgressModal = false
        }

        isExporting = false
    }

    // MARK: - Video Export

    func exportVideo(session: TrackingSession, includeStations: Bool = true) async {
        isExporting = true
        exportProgress = 0
        errorMessage = nil
        currentExportType = .video
        totalItemsToExport = session.locationPoints.count
        showProgressModal = true

        do {
            let url = try await videoExporter.export(
                session: session,
                resolution: selectedResolution,
                includeStations: includeStations
            ) { [weak self] progress in
                self?.exportProgress = progress
            }
            exportedFileURL = url
            showProgressModal = false
            showShareSheet = true
        } catch {
            errorMessage = error.localizedDescription
            showProgressModal = false
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
        showProgressModal = false
        totalItemsToExport = 0
    }

    /// Convert internal ExportType to ExportProgressView.ExportType for UI
    var progressViewExportType: ExportProgressView.ExportType {
        switch currentExportType {
        case .csv: return .csv
        case .json: return .json
        case .video: return .video
        }
    }
}
