//
//  PhotoThumbnailView.swift
//  railway-train-track
//
//  Created by Qiwei Li on 12/8/25.
//

import SwiftUI

// Helper extension to create SwiftUI Image from PlatformImage
extension Image {
    init(platformImage: PlatformImage) {
        #if os(iOS)
        self.init(uiImage: platformImage)
        #elseif os(macOS)
        self.init(nsImage: platformImage)
        #endif
    }
}

struct PhotoThumbnailView: View {
    let image: PlatformImage
    let onRemove: () -> Void

    @State private var showFullScreen = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Image(platformImage: image)
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
        #if os(iOS)
        .fullScreenCover(isPresented: $showFullScreen) {
            FullScreenPhotoView(image: image)
        }
        #else
        .sheet(isPresented: $showFullScreen) {
            FullScreenPhotoView(image: image)
        }
        #endif
    }
}

// MARK: - Full Screen Photo View

struct FullScreenPhotoView: View {
    let image: PlatformImage
    @Environment(\.dismiss) private var dismiss

    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ScrollView([.horizontal, .vertical], showsIndicators: false) {
                    Image(platformImage: image)
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
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundStyle(.white)
                }
            }
            #if os(iOS)
            .toolbarBackground(.hidden, for: .navigationBar)
            #endif
        }
    }
}

// MARK: - Read-Only Photo Thumbnail (for detail view)

struct ReadOnlyPhotoThumbnailView: View {
    let image: PlatformImage?
    let size: CGFloat

    @State private var showFullScreen = false

    var body: some View {
        Group {
            if let image = image {
                Image(platformImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size, height: size)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .contentShape(Rectangle())
                    .onTapGesture {
                        showFullScreen = true
                    }
                    #if os(iOS)
                    .fullScreenCover(isPresented: $showFullScreen) {
                        FullScreenPhotoView(image: image)
                    }
                    #else
                    .sheet(isPresented: $showFullScreen) {
                        FullScreenPhotoView(image: image)
                    }
                    #endif
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.2))
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
        #if os(iOS)
        PhotoThumbnailView(
            image: UIImage(systemName: "photo.fill")!,
            onRemove: {}
        )

        ReadOnlyPhotoThumbnailView(
            image: UIImage(systemName: "photo.fill"),
            size: 100
        )
        #elseif os(macOS)
        PhotoThumbnailView(
            image: NSImage(systemSymbolName: "photo.fill", accessibilityDescription: nil)!,
            onRemove: {}
        )

        ReadOnlyPhotoThumbnailView(
            image: NSImage(systemSymbolName: "photo.fill", accessibilityDescription: nil),
            size: 100
        )
        #endif
    }
    .padding()
}
