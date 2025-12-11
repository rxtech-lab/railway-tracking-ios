//
//  NoteEditorView.swift
//  railway-train-track
//
//  Created by Qiwei Li on 12/8/25.
//

import CoreLocation
import PhotosUI
import SwiftData
import SwiftUI

struct NoteEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let context: NoteEditorContext
    @Bindable var viewModel: SessionDetailViewModel

    @State private var editorViewModel: NoteEditorViewModel

    init(context: NoteEditorContext, viewModel: SessionDetailViewModel) {
        self.context = context
        self.viewModel = viewModel
        _editorViewModel = State(initialValue: NoteEditorViewModel(
            existingNote: context.existingNote,
            linkedStation: context.linkedStation
        ))
    }

    private var availableStations: [TrainStation] {
        viewModel.sortedStationEvents.compactMap { $0.station }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LocationInfoSection(coordinate: context.coordinate)
                }

                // Station Linking Section
                Section {
                    StationPickerSection(
                        selectedStation: $editorViewModel.linkedStation,
                        availableStations: availableStations
                    )
                } header: {
                    Text("Linked Station")
                } footer: {
                    Text("Link this note to a station from your journey")
                }

                // Photo Gallery Section
                PhotoGallerySection(viewModel: editorViewModel)

                // Note Text Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Note")
                        .font(.headline)

                    TextEditor(text: $editorViewModel.plainText)
                        .frame(minHeight: 150)
                        .padding(8)
                        .background(Color.gray.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
            .formStyle(.grouped)
            .navigationTitle(context.isEditing ? "Edit Note" : "New Note")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        viewModel.clearStationSelection()
                        viewModel.sheetContent = .tabBar
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveNote()
                    }
                    .disabled(!editorViewModel.canSave)
                }
            }
            .onChange(of: editorViewModel.selectedPhotoItems) { _, _ in
                Task {
                    await editorViewModel.loadSelectedPhotos()
                }
            }
        }
    }

    private func saveNote() {
        _ = editorViewModel.save(
            coordinate: context.coordinate,
            linkedStationEvent: context.linkedStationEvent,
            existingNote: context.existingNote,
            session: viewModel.session,
            modelContext: modelContext
        )
        viewModel.clearStationSelection()
        viewModel.sheetContent = .tabBar
    }
}

// MARK: - Station Picker Section

struct StationPickerSection: View {
    @Binding var selectedStation: TrainStation?
    let availableStations: [TrainStation]

    var body: some View {
        if availableStations.isEmpty {
            HStack {
                Image(systemName: "train.side.front.car")
                    .foregroundStyle(.secondary)
                Text("No stations available")
                    .foregroundStyle(.secondary)
            }
        } else {
            Picker("Station", selection: $selectedStation) {
                Text("None")
                    .tag(nil as TrainStation?)

                ForEach(availableStations, id: \.osmId) { station in
                    HStack {
                        Image(systemName: "train.side.front.car")
                        Text(station.name)
                    }
                    .tag(station as TrainStation?)
                }
            }
            .pickerStyle(.menu)
        }
    }
}

// MARK: - Location Info Section

struct LocationInfoSection: View {
    let coordinate: CLLocationCoordinate2D

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Location")
                .font(.headline)

            HStack {
                Image(systemName: "location.fill")
                    .foregroundStyle(.secondary)
                Text(formattedCoordinate)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var formattedCoordinate: String {
        String(format: "%.6f, %.6f", coordinate.latitude, coordinate.longitude)
    }
}

#Preview {
    NoteEditorView(
        context: NoteEditorContext(
            coordinate: CLLocationCoordinate2D(latitude: 35.6762, longitude: 139.6503),
            linkedStationEvent: nil,
            linkedStation: nil,
            existingNote: nil
        ),
        viewModel: SessionDetailViewModel(session: TrackingSession(name: "Test"))
    )
    .modelContainer(for: [TrackingSession.self, SessionNote.self, SessionPhoto.self], inMemory: true)
}
