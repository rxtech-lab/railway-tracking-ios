//
//  SessionPhoto.swift
//  railway-train-track
//
//  Created by Qiwei Li on 12/8/25.
//

import Foundation
import SwiftData

#if canImport(UIKit)
import UIKit
typealias PlatformImage = UIImage
#elseif canImport(AppKit)
import AppKit
typealias PlatformImage = NSImage
#endif

@Model
final class SessionPhoto {
    var id: UUID
    var timestamp: Date
    var imageData: Data
    var thumbnailData: Data?
    var displayOrder: Int = 0

    var note: SessionNote?

    init(
        timestamp: Date = Date(),
        imageData: Data,
        thumbnailData: Data? = nil,
        displayOrder: Int = 0
    ) {
        self.id = UUID()
        self.timestamp = timestamp
        self.imageData = imageData
        self.thumbnailData = thumbnailData
        self.displayOrder = displayOrder
    }

    // MARK: - Computed Properties

    var image: PlatformImage? {
        PlatformImage(data: imageData)
    }

    var thumbnail: PlatformImage? {
        if let thumbnailData = thumbnailData {
            return PlatformImage(data: thumbnailData)
        }
        return image
    }

    // MARK: - Factory Methods

    static func create(
        from image: PlatformImage,
        compressionQuality: CGFloat = 0.7,
        thumbnailSize: CGSize = CGSize(width: 150, height: 150),
        displayOrder: Int = 0
    ) -> SessionPhoto? {
        guard let imageData = getJpegData(from: image, compressionQuality: compressionQuality) else {
            return nil
        }

        let thumbnailData = generateThumbnail(from: image, size: thumbnailSize)

        return SessionPhoto(
            timestamp: Date(),
            imageData: imageData,
            thumbnailData: thumbnailData,
            displayOrder: displayOrder
        )
    }

    private static func getJpegData(from image: PlatformImage, compressionQuality: CGFloat) -> Data? {
        #if canImport(UIKit)
        return image.jpegData(compressionQuality: compressionQuality)
        #elseif canImport(AppKit)
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
        let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
        return bitmapRep.representation(using: .jpeg, properties: [.compressionFactor: compressionQuality])
        #endif
    }

    private static func generateThumbnail(from image: PlatformImage, size: CGSize) -> Data? {
        let aspectWidth = size.width / image.size.width
        let aspectHeight = size.height / image.size.height
        let aspectRatio = min(aspectWidth, aspectHeight)

        let newSize = CGSize(
            width: image.size.width * aspectRatio,
            height: image.size.height * aspectRatio
        )

        #if canImport(UIKit)
        UIGraphicsBeginImageContextWithOptions(newSize, false, 0)
        image.draw(in: CGRect(origin: .zero, size: newSize))
        let thumbnail = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return thumbnail?.jpegData(compressionQuality: 0.5)
        #elseif canImport(AppKit)
        let newImage = NSImage(size: newSize)
        newImage.lockFocus()
        image.draw(in: NSRect(origin: .zero, size: newSize),
                   from: NSRect(origin: .zero, size: image.size),
                   operation: .copy,
                   fraction: 1.0)
        newImage.unlockFocus()
        return getJpegData(from: newImage, compressionQuality: 0.5)
        #endif
    }
}
