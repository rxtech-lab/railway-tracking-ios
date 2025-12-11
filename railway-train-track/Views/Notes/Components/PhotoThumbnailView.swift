//
//  PhotoThumbnailView.swift
//  railway-train-track
//
//  Created by Qiwei Li on 12/8/25.
//

import SwiftUI

struct PhotoThumbnailView: View {
    let image: UIImage
    let onRemove: () -> Void

    @State private var showFullScreen = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 100, height: 100)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .contentShape(Rectangle())
                .onTapGesture {
                    showFullScreen = true
                }

            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.white)
                    .background(Circle().fill(.black.opacity(0.5)))
            }
            .offset(x: 4, y: -4)
        }
        .fullScreenCover(isPresented: $showFullScreen) {
            FullScreenPhotoView(image: image)
        }
    }
}

// MARK: - Full Screen Photo View

struct FullScreenPhotoView: View {
    let image: UIImage
    @Environment(\.dismiss) private var dismiss

    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ScrollView([.horizontal, .vertical], showsIndicators: false) {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(
                            width: geometry.size.width * scale,
                            height: geometry.size.height * scale
                        )
                        .scaleEffect(scale)
                        .gesture(
                            MagnificationGesture()
                                .onChanged { value in
                                    let delta = value / lastScale
                                    lastScale = value
                                    scale = min(max(scale * delta, 1), 4)
                                }
                                .onEnded { _ in
                                    lastScale = 1.0
                                }
                        )
                        .onTapGesture(count: 2) {
                            withAnimation {
                                scale = scale > 1 ? 1 : 2
                            }
                        }
                }
            }
            .background(Color.black)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundStyle(.white)
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
        }
    }
}

// MARK: - Read-Only Photo Thumbnail (for detail view)

struct ReadOnlyPhotoThumbnailView: View {
    let image: UIImage?
    let size: CGFloat

    @State private var showFullScreen = false

    var body: some View {
        Group {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size, height: size)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .contentShape(Rectangle())
                    .onTapGesture {
                        showFullScreen = true
                    }
                    .fullScreenCover(isPresented: $showFullScreen) {
                        FullScreenPhotoView(image: image)
                    }
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.systemGray5))
                    .frame(width: size, height: size)
                    .overlay {
                        Image(systemName: "photo")
                            .foregroundStyle(.secondary)
                    }
            }
        }
    }
}

#Preview {
    VStack {
        PhotoThumbnailView(
            image: UIImage(systemName: "photo.fill")!,
            onRemove: {}
        )

        ReadOnlyPhotoThumbnailView(
            image: UIImage(systemName: "photo.fill"),
            size: 100
        )
    }
    .padding()
}
