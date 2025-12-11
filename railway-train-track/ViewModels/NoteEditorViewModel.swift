//
//  NoteEditorViewModel.swift
//  railway-train-track
//
//  Created by Qiwei Li on 12/8/25.
//

import CoreLocation
import Foundation
import PhotosUI
import SwiftData
import SwiftUI
#if os(macOS)
import AppKit
#endif

@Observable
final class NoteEditorViewModel {
    var plainText: String = ""
    var photos: [PhotoItem] = []
    var selectedPhotoItems: [PhotosPickerItem] = []
    var isLoadingPhotos: Bool = false
    var linkedStation: TrainStation?

    struct PhotoItem: Identifiable {
        let id = UUID()
        var image: PlatformImage
        var data: Data
    }

    init(existingNote: SessionNote? = nil, linkedStation: TrainStation? = nil) {
        if let note = existingNote {
            plainText = note.plainText
            self.linkedStation = note.linkedStation
            // Load existing photos
            photos = note.sortedPhotos.compactMap { photo in
                guard let image = photo.image else { return nil }
                return PhotoItem(image: image, data: photo.imageData)
            }
        } else {
            self.linkedStation = linkedStation
        }
    }

    // MARK: - Photo Management

    func loadSelectedPhotos() async {
        await MainActor.run {
            isLoadingPhotos = true
        }

        for item in selectedPhotoItems {
            if let data = try? await item.loadTransferable(type: Data.self),
               let image = PlatformImage(data: data)
            {
                #if os(iOS)
                let compressedData = image.jpegData(compressionQuality: 0.7) ?? data
                #elseif os(macOS)
                var rect = NSRect(origin: .zero, size: image.size)
                let compressedData: Data
                if let cgImage = image.cgImage(forProposedRect: &rect, context: nil, hints: nil) {
                    let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
                    compressedData = bitmapRep.representation(using: .jpeg, properties: [.compressionFactor: 0.7]) ?? data
                } else {
                    compressedData = data
                }
                #endif
                await MainActor.run {
                    photos.append(PhotoItem(image: image, data: compressedData))
                }
            }
        }

        await MainActor.run {
            selectedPhotoItems.removeAll()
            isLoadingPhotos = false
        }
    }

    func removePhoto(_ photo: PhotoItem) {
        photos.removeAll { $0.id == photo.id }
    }

    func removePhoto(at indexSet: IndexSet) {
        photos.remove(atOffsets: indexSet)
    }

    // MARK: - Save

    func save(
        coordinate: CLLocationCoordinate2D,
        linkedStationEvent: StationPassEvent?,
        existingNote: SessionNote?,
        session: TrackingSession,
        modelContext: ModelContext
    ) -> SessionNote {
        let note: SessionNote

        if let existing = existingNote {
            // Update existing note
            note = existing
            note.plainText = plainText
            note.linkedStation = linkedStation

            // Clear old photos and add new ones
            for photo in note.photos {
                modelContext.delete(photo)
            }
            note.photos.removeAll()
        } else {
            // Create new note
            note = SessionNote(
                timestamp: Date(),
                latitude: coordinate.latitude,
                longitude: coordinate.longitude,
                plainText: plainText,
                linkedStationEventId: linkedStationEvent?.id,
                linkedStation: linkedStation,
                displayOrder: session.notes.count
            )
            note.session = session
            session.notes.append(note)
            modelContext.insert(note)
        }

        // Add photos
        for (index, photoItem) in photos.enumerated() {
            if let sessionPhoto = SessionPhoto.create(
                from: photoItem.image,
                compressionQuality: 0.7,
                displayOrder: index
            ) {
                sessionPhoto.note = note
                note.photos.append(sessionPhoto)
            }
        }

        try? modelContext.save()
        return note
    }

    // MARK: - Validation

    var canSave: Bool {
        !plainText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !photos.isEmpty
    }
}
