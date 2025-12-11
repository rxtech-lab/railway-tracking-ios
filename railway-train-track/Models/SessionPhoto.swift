//
//  SessionPhoto.swift
//  railway-train-track
//
//  Created by Qiwei Li on 12/8/25.
//

import Foundation
import SwiftData
import UIKit

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

    var image: UIImage? {
        UIImage(data: imageData)
    }

    var thumbnail: UIImage? {
        if let thumbnailData = thumbnailData {
            return UIImage(data: thumbnailData)
        }
        return image
    }

    // MARK: - Factory Methods

    static func create(
        from image: UIImage,
        compressionQuality: CGFloat = 0.7,
        thumbnailSize: CGSize = CGSize(width: 150, height: 150),
        displayOrder: Int = 0
    ) -> SessionPhoto? {
        guard let imageData = image.jpegData(compressionQuality: compressionQuality) else {
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

    private static func generateThumbnail(from image: UIImage, size: CGSize) -> Data? {
        let aspectWidth = size.width / image.size.width
        let aspectHeight = size.height / image.size.height
        let aspectRatio = min(aspectWidth, aspectHeight)

        let newSize = CGSize(
            width: image.size.width * aspectRatio,
            height: image.size.height * aspectRatio
        )

        UIGraphicsBeginImageContextWithOptions(newSize, false, 0)
        image.draw(in: CGRect(origin: .zero, size: newSize))
        let thumbnail = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return thumbnail?.jpegData(compressionQuality: 0.5)
    }
}
