//
//  VideoExporter.swift
//  railway-train-track
//
//  Created by Qiwei Li on 12/6/25.
//

import Foundation
import AVFoundation
import MapKit
import UIKit

enum VideoResolution: String, CaseIterable, Identifiable {
    case uhd4K = "4K 16:9 (3840x2160)"
    case hd1080p = "1080p (1920x1080)"
    case hd720p = "720p (1280x720)"
    case square4K = "4K 1:1 (2160x2160)"

    var id: String { rawValue }

    var size: CGSize {
        switch self {
        case .uhd4K: return CGSize(width: 3840, height: 2160)
        case .hd1080p: return CGSize(width: 1920, height: 1080)
        case .hd720p: return CGSize(width: 1280, height: 720)
        case .square4K: return CGSize(width: 2160, height: 2160)
        }
    }

    var bitrate: Int {
        switch self {
        case .uhd4K, .square4K: return 20_000_000 // 20 Mbps
        case .hd1080p: return 10_000_000 // 10 Mbps
        case .hd720p: return 5_000_000 // 5 Mbps
        }
    }
}

final class VideoExporter {
    private let frameRate: Int32 = 30

    func export(
        session: TrackingSession,
        resolution: VideoResolution,
        includeStations: Bool,
        progress: @escaping (Double) -> Void
    ) async throws -> URL {
        let outputURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("track_\(session.id.uuidString).mp4")

        // Remove existing file
        try? FileManager.default.removeItem(at: outputURL)

        let points = session.sortedLocationPoints
        guard !points.isEmpty else {
            throw NSError(domain: "VideoExporter", code: 1, userInfo: [NSLocalizedDescriptionKey: "No location points to export"])
        }

        // Setup AVAssetWriter
        let writer = try AVAssetWriter(outputURL: outputURL, fileType: .mp4)

        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: resolution.size.width,
            AVVideoHeightKey: resolution.size.height,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: resolution.bitrate,
                AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel
            ]
        ]

        let writerInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        writerInput.expectsMediaDataInRealTime = false

        let pixelBufferAttributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB,
            kCVPixelBufferWidthKey as String: Int(resolution.size.width),
            kCVPixelBufferHeightKey as String: Int(resolution.size.height)
        ]

        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: writerInput,
            sourcePixelBufferAttributes: pixelBufferAttributes
        )

        writer.add(writerInput)
        writer.startWriting()
        writer.startSession(atSourceTime: .zero)

        // Calculate region for all points
        let coordinates = points.map { $0.coordinate }
        let region = calculateRegion(for: coordinates)

        // Generate frames - aim for 30-60 second video
        let targetDuration = min(60, max(30, Double(points.count) / 10))
        let totalFrames = Int(targetDuration * Double(frameRate))
        let pointsPerFrame = max(1, points.count / totalFrames)

        var frameIndex: Int64 = 0

        for i in stride(from: 0, to: points.count, by: pointsPerFrame) {
            while !writerInput.isReadyForMoreMediaData {
                try await Task.sleep(nanoseconds: 10_000_000) // 10ms
            }

            // Render map snapshot as frame
            let visiblePoints = Array(points[0...i])
            let stations = includeStations ? session.stationPassEvents.filter { $0.entryPointIndex <= i } : []

            if let pixelBuffer = try await renderMapFrame(
                points: visiblePoints,
                allPoints: points,
                currentIndex: i,
                region: region,
                resolution: resolution.size,
                stations: stations
            ) {
                let presentationTime = CMTime(value: frameIndex, timescale: frameRate)
                adaptor.append(pixelBuffer, withPresentationTime: presentationTime)
                frameIndex += 1
            }

            await MainActor.run {
                progress(Double(i) / Double(points.count))
            }
        }

        writerInput.markAsFinished()
        await writer.finishWriting()

        if writer.status == .failed {
            throw writer.error ?? NSError(domain: "VideoExporter", code: 2, userInfo: [NSLocalizedDescriptionKey: "Video export failed"])
        }

        return outputURL
    }

    private func calculateRegion(for coordinates: [CLLocationCoordinate2D]) -> MKCoordinateRegion {
        guard !coordinates.isEmpty else {
            return MKCoordinateRegion()
        }

        var minLat = coordinates[0].latitude
        var maxLat = coordinates[0].latitude
        var minLon = coordinates[0].longitude
        var maxLon = coordinates[0].longitude

        for coord in coordinates {
            minLat = min(minLat, coord.latitude)
            maxLat = max(maxLat, coord.latitude)
            minLon = min(minLon, coord.longitude)
            maxLon = max(maxLon, coord.longitude)
        }

        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )

        let span = MKCoordinateSpan(
            latitudeDelta: (maxLat - minLat) * 1.2,
            longitudeDelta: (maxLon - minLon) * 1.2
        )

        return MKCoordinateRegion(center: center, span: span)
    }

    private func renderMapFrame(
        points: [LocationPoint],
        allPoints: [LocationPoint],
        currentIndex: Int,
        region: MKCoordinateRegion,
        resolution: CGSize,
        stations: [StationPassEvent]
    ) async throws -> CVPixelBuffer? {
        let options = MKMapSnapshotter.Options()
        options.region = region
        options.size = resolution
        options.mapType = .standard

        let snapshotter = MKMapSnapshotter(options: options)
        let snapshot = try await snapshotter.start()

        // Draw route on snapshot
        let image = await MainActor.run {
            UIGraphicsImageRenderer(size: resolution).image { ctx in
                // Draw base map
                snapshot.image.draw(at: .zero)

                let coordinates = points.map { $0.coordinate }

                // Draw full route as faded line
                if allPoints.count > 1 {
                    ctx.cgContext.setStrokeColor(UIColor.systemBlue.withAlphaComponent(0.3).cgColor)
                    ctx.cgContext.setLineWidth(2)
                    let allCoords = allPoints.map { $0.coordinate }
                    for (i, coord) in allCoords.enumerated() {
                        let point = snapshot.point(for: coord)
                        if i == 0 {
                            ctx.cgContext.move(to: point)
                        } else {
                            ctx.cgContext.addLine(to: point)
                        }
                    }
                    ctx.cgContext.strokePath()
                }

                // Draw traveled route
                if coordinates.count > 1 {
                    ctx.cgContext.setStrokeColor(UIColor.systemBlue.cgColor)
                    ctx.cgContext.setLineWidth(4)
                    for (i, coord) in coordinates.enumerated() {
                        let point = snapshot.point(for: coord)
                        if i == 0 {
                            ctx.cgContext.move(to: point)
                        } else {
                            ctx.cgContext.addLine(to: point)
                        }
                    }
                    ctx.cgContext.strokePath()
                }

                // Draw station markers
                for event in stations {
                    if let station = event.station {
                        let stationPoint = snapshot.point(for: station.coordinate)
                        ctx.cgContext.setFillColor(UIColor.orange.cgColor)
                        ctx.cgContext.fillEllipse(in: CGRect(
                            x: stationPoint.x - 10,
                            y: stationPoint.y - 10,
                            width: 20,
                            height: 20
                        ))
                    }
                }

                // Draw current position marker
                if let lastCoord = coordinates.last {
                    let currentPoint = snapshot.point(for: lastCoord)

                    // Outer circle
                    ctx.cgContext.setFillColor(UIColor.white.cgColor)
                    ctx.cgContext.fillEllipse(in: CGRect(
                        x: currentPoint.x - 12,
                        y: currentPoint.y - 12,
                        width: 24,
                        height: 24
                    ))

                    // Inner circle
                    ctx.cgContext.setFillColor(UIColor.systemRed.cgColor)
                    ctx.cgContext.fillEllipse(in: CGRect(
                        x: currentPoint.x - 8,
                        y: currentPoint.y - 8,
                        width: 16,
                        height: 16
                    ))
                }

                // Draw timestamp overlay
                if currentIndex < allPoints.count {
                    let timeText = allPoints[currentIndex].timestamp.formatted(date: .abbreviated, time: .standard)
                    let attributes: [NSAttributedString.Key: Any] = [
                        .font: UIFont.systemFont(ofSize: 24, weight: .bold),
                        .foregroundColor: UIColor.white,
                        .backgroundColor: UIColor.black.withAlphaComponent(0.7)
                    ]
                    let textSize = (timeText as NSString).size(withAttributes: attributes)
                    let textRect = CGRect(x: 20, y: resolution.height - textSize.height - 20, width: textSize.width + 10, height: textSize.height)
                    (timeText as NSString).draw(in: textRect, withAttributes: attributes)
                }
            }
        }

        return pixelBuffer(from: image, size: resolution)
    }

    private func pixelBuffer(from image: UIImage, size: CGSize) -> CVPixelBuffer? {
        let attrs: [CFString: Any] = [
            kCVPixelBufferCGImageCompatibilityKey: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey: true
        ]

        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            Int(size.width),
            Int(size.height),
            kCVPixelFormatType_32ARGB,
            attrs as CFDictionary,
            &pixelBuffer
        )

        guard status == kCVReturnSuccess, let buffer = pixelBuffer else {
            return nil
        }

        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }

        guard let context = CGContext(
            data: CVPixelBufferGetBaseAddress(buffer),
            width: Int(size.width),
            height: Int(size.height),
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue
        ) else {
            return nil
        }

        // Flip context for correct orientation
        context.translateBy(x: 0, y: size.height)
        context.scaleBy(x: 1.0, y: -1.0)

        if let cgImage = image.cgImage {
            context.draw(cgImage, in: CGRect(origin: .zero, size: size))
        }

        return buffer
    }
}
