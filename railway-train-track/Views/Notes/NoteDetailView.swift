//
//  NoteDetailView.swift
//  railway-train-track
//
//  Created by Qiwei Li on 12/8/25.
//

import SwiftUI

struct NoteDetailView: View {
    let note: SessionNote
    @Bindable var viewModel: SessionDetailViewModel

    private let columns = [
        GridItem(.adaptive(minimum: 100), spacing: 8)
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Linked Station Section
                    if let station = note.linkedStation {
                        StationInfoSection(station: station)
                        Divider()
                    }

                    // Photo Gallery (if any)
                    if note.hasPhotos {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Photos")
                                .font(.headline)

                            LazyVGrid(columns: columns, spacing: 8) {
                                ForEach(note.sortedPhotos) { photo in
                                    ReadOnlyPhotoThumbnailView(
                                        image: photo.thumbnail,
                                        size: 100
                                    )
                                }
                            }
                        }

                        Divider()
                    }

                    // Note Text
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Note")
                            .font(.headline)

                        if note.plainText.isEmpty {
                            Text("No text content")
                                .foregroundStyle(.secondary)
                                .italic()
                        } else {
                            Text(note.plainText)
                                .font(.body)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }

                    Divider()

                    // Location and Time Info
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Details")
                            .font(.headline)

                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "clock")
                                    .foregroundStyle(.secondary)
                                Text(note.formattedTime)
                                    .font(.subheadline)
                            }

                            HStack {
                                Image(systemName: "location.fill")
                                    .foregroundStyle(.secondary)
                                Text(String(format: "%.6f, %.6f", note.latitude, note.longitude))
                                    .font(.subheadline)
                            }

                            if note.hasPhotos {
                                HStack {
                                    Image(systemName: "photo")
                                        .foregroundStyle(.secondary)
                                    Text("\(note.photoCount) photo\(note.photoCount == 1 ? "" : "s")")
                                        .font(.subheadline)
                                }
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        viewModel.sheetContent = .tabBar
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Edit") {
                        viewModel.editNote(note)
                    }
                }
            }
        }
    }
}

// MARK: - Station Info Section

struct StationInfoSection: View {
    let station: TrainStation

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Linked Station")
                .font(.headline)

            HStack(spacing: 12) {
                // Station icon
                ZStack {
                    Circle()
                        .fill(.orange)
                        .frame(width: 40, height: 40)
                    Image(systemName: "train.side.front.car")
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(station.name)
                        .font(.body)
                        .fontWeight(.medium)

                    if let stationType = station.stationType {
                        Text(stationType.capitalized)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Text(station.formattedCoordinate)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .padding()
            .background(Color.orange.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

#Preview {
    NoteDetailView(
        note: SessionNote(
            timestamp: Date(),
            latitude: 35.6762,
            longitude: 139.6503,
            plainText: "This is a sample note with some text content that spans multiple lines. It describes the journey and what we saw along the way."
        ),
        viewModel: SessionDetailViewModel(session: TrackingSession(name: "Test"))
    )
}
