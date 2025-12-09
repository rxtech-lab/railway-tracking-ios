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

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                // Background Time Header
                VStack {
                    HStack {
                        Image(systemName: "clock")
                            .foregroundStyle(.secondary)
                        Text(note.formattedTime)
                            .font(.subheadline)
                    }
                    .padding(.top, 8)
                }

                ScrollView {
                    VStack(spacing: 0) {
                        // Transparent spacer to reveal time header
                        Color.clear
                            .frame(height: 50)

                        VStack(spacing: 20) {
                            // Linked Station Section

                            // Photo Gallery (if any)
                            if note.hasPhotos {
                                VStack(alignment: .leading, spacing: 12) {
                                    WrapRow(maxColumns: 3) {
                                        if let station = note.linkedStation {
                                            StationInfoSection(station: station)
                                        }
                                        ForEach(note.sortedPhotos) { photo in
                                            if let image = photo.thumbnail {
                                                PhotoCell(image: image)
                                            }
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
                            HStack {
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("Details")
                                        .font(.headline)

                                    VStack(alignment: .leading, spacing: 8) {
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
                                Spacer()
                            }
                        }
                        .padding()
                        .glassEffect(in: .rect)
                    }
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
}

// MARK: - Photo Cell

private struct PhotoCell: View {
    let image: UIImage
    @State private var showFullScreen = false

    var body: some View {
        Color.clear
            .frame(maxWidth: .infinity)
            .frame(height: 150)
            .overlay {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            }
            .clipped()
            .contentShape(Rectangle())
            .onTapGesture {
                showFullScreen = true
            }
            .fullScreenCover(isPresented: $showFullScreen) {
                FullScreenPhotoView(image: image)
            }
    }
}

// MARK: - Station Info Section

struct StationInfoSection: View {
    let station: TrainStation

    var body: some View {
        HStack {
            // Station icon
            ZStack {
                Circle()
                    .fill(.orange)
                    .frame(width: 40, height: 40)
                Image(systemName: "train.side.front.car")
                    .foregroundStyle(.white)
            }
            VStack(alignment: .leading) {
                Text(station.name)
                    .font(.body)
                    .fontWeight(.medium)
                if let stationType = station.stationType {
                    Text(stationType.capitalized)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 150)
        .background(Color.orange.opacity(0.1))
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
