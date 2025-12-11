//
//  DetailColumnView.swift
//  railway-train-track
//
//  Created by Qiwei Li on 12/12/25.
//

import SwiftUI

/// A view that displays the detail column content for iPad/macOS 3-column layout.
/// This view wraps the same content as SheetContentView but without sheet-specific modifiers.
struct DetailColumnView: View {
    @Bindable var viewModel: SessionDetailViewModel
    @Bindable var exportViewModel: ExportViewModel

    var body: some View {
        Group {
            switch viewModel.sheetContent {
            case .tabBar:
                // Main tab interface - wrap in NavigationStack for toolbar support
                NavigationStack {
                    SessionSheetContent(viewModel: viewModel, exportViewModel: exportViewModel)
                        #if os(iOS)
                        .navigationBarTitleDisplayMode(.inline)
                        #endif
                }

            case .playbackSettings:
                NavigationStack {
                    PlaybackSettingsContent(viewModel: viewModel)
                        .navigationTitle("Playback Settings")
                        #if os(iOS)
                        .navigationBarTitleDisplayMode(.inline)
                        #endif
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button("Done") {
                                    viewModel.sheetContent = .tabBar
                                }
                            }
                        }
                }

            case .stationSearch:
                NavigationStack {
                    StationSearchContent(
                        viewModel: viewModel,
                        stationDataViewModel: viewModel.stationDataViewModel
                    )
                    .navigationTitle("Add Station")
                    #if os(iOS)
                    .navigationBarTitleDisplayMode(.inline)
                    #endif
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Back") {
                                viewModel.sheetContent = .tabBar
                            }
                        }
                    }
                }

            case .exportCSV:
                NavigationStack {
                    CSVExportContent(
                        session: viewModel.session,
                        exportType: viewModel.selectedTab,
                        exportViewModel: exportViewModel
                    )
                    .navigationTitle("Export CSV")
                    #if os(iOS)
                    .navigationBarTitleDisplayMode(.inline)
                    #endif
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Back") {
                                viewModel.sheetContent = .tabBar
                            }
                        }
                    }
                }

            case .exportJSON:
                NavigationStack {
                    JSONExportContent(
                        session: viewModel.session,
                        exportType: viewModel.selectedTab,
                        exportViewModel: exportViewModel
                    )
                    .navigationTitle("Export JSON")
                    #if os(iOS)
                    .navigationBarTitleDisplayMode(.inline)
                    #endif
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Back") {
                                viewModel.sheetContent = .tabBar
                            }
                        }
                    }
                }

            case .exportVideo:
                NavigationStack {
                    VideoExportContent(
                        session: viewModel.session,
                        exportViewModel: exportViewModel
                    )
                    .navigationTitle("Export Video")
                    #if os(iOS)
                    .navigationBarTitleDisplayMode(.inline)
                    #endif
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Back") {
                                viewModel.sheetContent = .tabBar
                            }
                        }
                    }
                }

            case .noteEditor(let context):
                // NoteEditorView already has its own NavigationStack
                NoteEditorView(context: context, viewModel: viewModel)

            case .noteDetail(let note):
                // NoteDetailView already has its own NavigationStack
                NoteDetailView(note: note, viewModel: viewModel)
            }
        }
    }
}
