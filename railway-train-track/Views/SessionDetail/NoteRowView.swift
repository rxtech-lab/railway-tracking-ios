//
//  NoteRowView.swift
//  railway-train-track
//
//  Created by Qiwei Li on 12/8/25.
//

import SwiftUI

struct NoteRowView: View {
    let note: SessionNote

    var body: some View {
        HStack(spacing: 12) {
            // Thumbnail or placeholder
            if let firstPhoto = note.sortedPhotos.first {
                ReadOnlyPhotoThumbnailView(image: firstPhoto.thumbnail, size: 60)
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.purple.opacity(0.1))
                    .frame(width: 60, height: 60)
                    .overlay {
                        Image(systemName: "note.text")
                            .foregroundStyle(.purple)
                    }
            }

            // Note info
            VStack(alignment: .leading, spacing: 4) {
                Text(note.previewText)
                    .font(.body)
                    .lineLimit(2)

                HStack(spacing: 8) {
                    Label(note.formattedTime, systemImage: "clock")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if note.hasPhotos {
                        Label("\(note.photoCount)", systemImage: "photo")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    // Station badge
                    if let stationName = note.linkedStationName {
                        HStack(spacing: 2) {
                            Image(systemName: "train.side.front.car")
                            Text(stationName)
                                .lineLimit(1)
                        }
                        .font(.caption)
                        .foregroundStyle(.orange)
                    }
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    List {
        NoteRowView(
            note: SessionNote(
                timestamp: Date(),
                latitude: 35.6762,
                longitude: 139.6503,
                plainText: "This is a sample note with some text content that might span multiple lines."
            )
        )

        NoteRowView(
            note: SessionNote(
                timestamp: Date(),
                latitude: 35.6762,
                longitude: 139.6503,
                plainText: ""
            )
        )
    }
}
