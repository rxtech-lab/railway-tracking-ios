//
//  ExportProgressView.swift
//  railway-train-track
//
//  Created by Claude on 12/12/25.
//

import SwiftUI

/// A modal view that displays export progress
struct ExportProgressView: View {
    let exportType: ExportType
    let progress: Double
    let isExporting: Bool
    var totalItems: Int?
    var onCancel: (() -> Void)?

    enum ExportType: String {
        case csv = "CSV"
        case json = "JSON"
        case video = "Video"

        var icon: String {
            switch self {
            case .csv: return "tablecells"
            case .json: return "curlybraces"
            case .video: return "film"
            }
        }
    }

    private var progressPercentage: Int {
        Int(progress * 100)
    }

    private var processedItems: Int? {
        guard let total = totalItems else { return nil }
        return Int(Double(total) * progress)
    }

    var body: some View {
        VStack(spacing: 24) {
            // Icon and title
            VStack(spacing: 12) {
                Image(systemName: exportType.icon)
                    .font(.system(size: 48))
                    .foregroundStyle(.blue)

                Text("Exporting \(exportType.rawValue)")
                    .font(.headline)
            }

            // Progress indicator
            VStack(spacing: 16) {
                ProgressView(value: progress)
                    .progressViewStyle(.linear)
                    .frame(width: 200)

                Text("\(progressPercentage)%")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .monospacedDigit()

                // Item count if available
                if let processed = processedItems, let total = totalItems {
                    Text("\(processed) / \(total) items")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // Status text
            if isExporting {
                Text("Please wait...")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else if progress >= 1.0 {
                Text("Export complete!")
                    .font(.subheadline)
                    .foregroundStyle(.green)
            }

            // Cancel button (optional)
            if isExporting, let onCancel = onCancel {
                Button("Cancel", role: .cancel) {
                    onCancel()
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(32)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(radius: 10)
    }
}

/// A full-screen overlay version of the export progress view
struct ExportProgressOverlay: View {
    let exportType: ExportProgressView.ExportType
    let progress: Double
    let isExporting: Bool
    var totalItems: Int?
    var onCancel: (() -> Void)?

    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()

            ExportProgressView(
                exportType: exportType,
                progress: progress,
                isExporting: isExporting,
                totalItems: totalItems,
                onCancel: onCancel
            )
        }
    }
}

/// View modifier to show export progress as an overlay
struct ExportProgressModifier: ViewModifier {
    let isPresented: Bool
    let exportType: ExportProgressView.ExportType
    let progress: Double
    var totalItems: Int?
    var onCancel: (() -> Void)?

    func body(content: Content) -> some View {
        content
            .overlay {
                if isPresented {
                    ExportProgressOverlay(
                        exportType: exportType,
                        progress: progress,
                        isExporting: true,
                        totalItems: totalItems,
                        onCancel: onCancel
                    )
                    .transition(.opacity)
                    .animation(.easeInOut(duration: 0.2), value: isPresented)
                }
            }
    }
}

extension View {
    /// Shows an export progress overlay when exporting
    func exportProgress(
        isPresented: Bool,
        exportType: ExportProgressView.ExportType,
        progress: Double,
        totalItems: Int? = nil,
        onCancel: (() -> Void)? = nil
    ) -> some View {
        modifier(ExportProgressModifier(
            isPresented: isPresented,
            exportType: exportType,
            progress: progress,
            totalItems: totalItems,
            onCancel: onCancel
        ))
    }
}

#Preview("Progress View") {
    VStack(spacing: 20) {
        ExportProgressView(
            exportType: .csv,
            progress: 0.65,
            isExporting: true,
            totalItems: 1000
        )

        ExportProgressView(
            exportType: .json,
            progress: 1.0,
            isExporting: false,
            totalItems: 500
        )
    }
    .padding()
}

#Preview("Overlay") {
    Text("Background Content")
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .exportProgress(
            isPresented: true,
            exportType: .video,
            progress: 0.35,
            totalItems: 2000
        )
}
