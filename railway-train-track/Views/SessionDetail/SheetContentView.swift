//
//  SheetContentView.swift
//  railway-train-track
//
//  Created by Qiwei Li on 12/6/25.
//

import SwiftUI

// MARK: - Sheet Content View

struct SheetContentView: View {
    let content: SheetContent
    @Bindable var viewModel: SessionDetailViewModel
    @Bindable var exportViewModel: ExportViewModel

    var body: some View {
        switch content {
        case .tabBar:
            SessionSheetContent(viewModel: viewModel, exportViewModel: exportViewModel)

        case .playbackSettings:
            NavigationStack {
                PlaybackSettingsContent(viewModel: viewModel)
                    .navigationTitle("Playback Settings")
                    .navigationBarTitleDisplayMode(.inline)
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
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close") {
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
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close") {
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
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close") {
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
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close") {
                            viewModel.sheetContent = .tabBar
                        }
                    }
                }
            }

        case .noteEditor(let context):
            NoteEditorView(context: context, viewModel: viewModel)

        case .noteDetail(let note):
            NoteDetailView(note: note, viewModel: viewModel)
        }
    }
}

// MARK: - Session Sheet Content

struct SessionSheetContent: View {
    @Bindable var viewModel: SessionDetailViewModel
    @Bindable var exportViewModel: ExportViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Tab picker
            Picker("Tab", selection: $viewModel.selectedTab) {
                ForEach(SessionTab.allCases, id: \.self) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding()

            // Tab content
            switch viewModel.selectedTab {
            case .locations:
                LocationsTabView(viewModel: viewModel)
                    .tag(SessionTab.locations)
            case .stations:
                StationsTabView(viewModel: viewModel)
                    .tag(SessionTab.stations)
            case .notes:
                NotesTabView(viewModel: viewModel)
                    .tag(SessionTab.notes)
            }
        }
    }
}
