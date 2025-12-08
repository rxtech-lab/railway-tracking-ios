//
//  PhotoGallerySection.swift
//  railway-train-track
//
//  Created by Qiwei Li on 12/8/25.
//

import PhotosUI
import SwiftUI

struct PhotoGallerySection: View {
    @Bindable var viewModel: NoteEditorViewModel

    private let columns = [
        GridItem(.adaptive(minimum: 100), spacing: 8)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Photos")
                    .font(.headline)

                if viewModel.isLoadingPhotos {
                    ProgressView()
                        .scaleEffect(0.8)
                }

                Spacer()

                PhotosPicker(
                    selection: $viewModel.selectedPhotoItems,
                    maxSelectionCount: 10,
                    matching: .images
                ) {
                    Label("Add", systemImage: "plus")
                        .font(.subheadline)
                }
            }

            if viewModel.photos.isEmpty {
                // Empty state
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemGray6))
                    .frame(height: 120)
                    .overlay {
                        VStack(spacing: 8) {
                            Image(systemName: "photo.on.rectangle.angled")
                                .font(.largeTitle)
                                .foregroundStyle(.secondary)
                            Text("Tap + to add photos")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
            } else {
                // Photo grid
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(viewModel.photos) { photo in
                        PhotoThumbnailView(
                            image: photo.image,
                            onRemove: {
                                viewModel.removePhoto(photo)
                            }
                        )
                    }
                }
            }
        }
    }
}

#Preview {
    PhotoGallerySection(viewModel: NoteEditorViewModel())
        .padding()
}
