//
//  SessionNote.swift
//  railway-train-track
//
//  Created by Qiwei Li on 12/8/25.
//

import CoreLocation
import Foundation
import SwiftData

@Model
final class SessionNote {
    var id: UUID
    var timestamp: Date
    var latitude: Double
    var longitude: Double
    var plainText: String
    var linkedStationEventId: UUID?
    var displayOrder: Int = 0

    var session: TrackingSession?

    @Relationship(deleteRule: .nullify)
    var linkedStation: TrainStation?

    @Relationship(deleteRule: .cascade, inverse: \SessionPhoto.note)
    var photos: [SessionPhoto] = []

    init(
        timestamp: Date = Date(),
        latitude: Double,
        longitude: Double,
        plainText: String = "",
        linkedStationEventId: UUID? = nil,
        linkedStation: TrainStation? = nil,
        displayOrder: Int = 0
    ) {
        self.id = UUID()
        self.timestamp = timestamp
        self.latitude = latitude
        self.longitude = longitude
        self.plainText = plainText
        self.linkedStationEventId = linkedStationEventId
        self.linkedStation = linkedStation
        self.displayOrder = displayOrder
    }

    // MARK: - Station Computed Properties

    var hasLinkedStation: Bool {
        linkedStation != nil
    }

    var linkedStationName: String? {
        linkedStation?.name
    }

    // MARK: - Computed Properties

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var formattedTime: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .short
        return formatter.string(from: timestamp)
    }

    var hasPhotos: Bool {
        !photos.isEmpty
    }

    var photoCount: Int {
        photos.count
    }

    var sortedPhotos: [SessionPhoto] {
        photos.sorted { $0.displayOrder < $1.displayOrder }
    }

    var previewText: String {
        let trimmed = plainText.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return hasPhotos ? "\(photoCount) photo\(photoCount == 1 ? "" : "s")" : "Empty note"
        }
        let maxLength = 50
        if trimmed.count <= maxLength {
            return trimmed
        }
        return String(trimmed.prefix(maxLength)) + "..."
    }
}
