//
//  AnimatedTrackingMapView.swift
//  railway-train-track
//
//  Created by Qiwei Li on 12/7/25.
//

import MapKit
import SwiftUI

/// A reusable map view component that provides smooth animated marker tracking.
/// Supports both live tracking (last 20 points) and playback (all points with interpolation).
struct AnimatedTrackingMapView<Content: MapContent>: View {
    @Binding var cameraPosition: MapCameraPosition

    /// The coordinate to track and animate to (current position - can be interpolated)
    let currentCoordinate: CLLocationCoordinate2D?

    /// Animation duration for camera and marker transitions
    let animationDuration: Double

    /// Full route polyline to display (faded)
    let routeCoordinates: [CLLocationCoordinate2D]

    /// Traveled portion of route (highlighted solid line)
    let traveledCoordinates: [CLLocationCoordinate2D]

    /// Static markers to display (start, end, train stations)
    let markers: [TrackingPoint]

    /// Railway routes to display as brown dashed lines
    let railwayRoutes: [[CLLocationCoordinate2D]]

    /// Custom marker style for current position
    let markerStyle: MarkerStyle

    /// Whether to show the current position marker
    let showCurrentPositionMarker: Bool

    let showRoutePolyline: Bool

    /// Additional map content (annotations, markers, etc.)
    @MapContentBuilder let additionalContent: () -> Content

    enum MarkerStyle {
        case currentPosition  // Red dot with white border (playback)
        case liveTracking     // Blue dot with white border (active session)
        case none             // No marker

        var fillColor: Color {
            switch self {
            case .currentPosition: return .red
            case .liveTracking: return .blue
            case .none: return .clear
            }
        }

        var size: CGFloat {
            switch self {
            case .currentPosition: return 14
            case .liveTracking: return 16
            case .none: return 0
            }
        }
    }

    init(
        cameraPosition: Binding<MapCameraPosition>,
        currentCoordinate: CLLocationCoordinate2D?,
        animationDuration: Double = 0.5,
        routeCoordinates: [CLLocationCoordinate2D] = [],
        traveledCoordinates: [CLLocationCoordinate2D] = [],
        markers: [TrackingPoint] = [],
        railwayRoutes: [[CLLocationCoordinate2D]] = [],
        markerStyle: MarkerStyle = .currentPosition,
        showCurrentPositionMarker: Bool = true,
        showRoutePolyline: Bool = true,
        @MapContentBuilder additionalContent: @escaping () -> Content
    ) {
        self._cameraPosition = cameraPosition
        self.currentCoordinate = currentCoordinate
        self.animationDuration = animationDuration
        self.routeCoordinates = routeCoordinates
        self.traveledCoordinates = traveledCoordinates
        self.markers = markers
        self.railwayRoutes = railwayRoutes
        self.markerStyle = markerStyle
        self.showCurrentPositionMarker = showCurrentPositionMarker
        self.additionalContent = additionalContent
        self.showRoutePolyline = showRoutePolyline
    }

    var body: some View {
        Map(position: $cameraPosition) {
            // Full route polyline (faded)
            if showRoutePolyline && routeCoordinates.count > 1 {
                MapPolyline(coordinates: routeCoordinates)
                    .stroke(.blue.opacity(0.5), lineWidth: 3)
            }

            // Traveled route polyline (highlighted)
            if traveledCoordinates.count > 1 {
                MapPolyline(coordinates: traveledCoordinates)
                    .stroke(.blue, lineWidth: 4)
            }

            // Railway track polylines
            ForEach(Array(railwayRoutes.enumerated()), id: \.offset) { _, route in
                MapPolyline(coordinates: route)
                    .stroke(.brown, style: StrokeStyle(lineWidth: 3, dash: [5, 3]))
            }

            // Static markers (start, end, stations)
            ForEach(markers) { marker in
                Annotation(marker.title ?? "", coordinate: marker.location) {
                    TrackingPointMarkerView(point: marker)
                }
            }

            // Current position marker (updated every frame via DisplayLink)
            if showCurrentPositionMarker, let coord = currentCoordinate, markerStyle != .none {
                Annotation("", coordinate: coord) {
                    ZStack {
                        Circle()
                            .fill(.white)
                            .frame(width: markerStyle.size + 6, height: markerStyle.size + 6)
                        Circle()
                            .fill(markerStyle.fillColor)
                            .frame(width: markerStyle.size, height: markerStyle.size)
                    }
                }
            }

            // Additional custom content
            additionalContent()
        }
        .mapControls {
            MapCompass()
            MapScaleView()
            MapUserLocationButton()
        }
    }
}

// MARK: - TrackingPoint Marker View

struct TrackingPointMarkerView: View {
    let point: TrackingPoint

    var body: some View {
        ZStack {
            Circle()
                .fill(point.type.backgroundColor)
                .frame(width: point.type.markerSize, height: point.type.markerSize)
            Image(systemName: point.type.iconName)
                .font(.system(size: point.type.iconSize))
                .foregroundStyle(point.type.iconColor)
        }
    }
}

// MARK: - Convenience initializer without additional content

extension AnimatedTrackingMapView where Content == EmptyMapContent {
    init(
        cameraPosition: Binding<MapCameraPosition>,
        currentCoordinate: CLLocationCoordinate2D?,
        animationDuration: Double = 0.5,
        routeCoordinates: [CLLocationCoordinate2D] = [],
        traveledCoordinates: [CLLocationCoordinate2D] = [],
        markers: [TrackingPoint] = [],
        railwayRoutes: [[CLLocationCoordinate2D]] = [],
        markerStyle: MarkerStyle = .currentPosition,
        showCurrentPositionMarker: Bool = true,
        showRoutePolyline: Bool = true
    ) {
        self._cameraPosition = cameraPosition
        self.currentCoordinate = currentCoordinate
        self.animationDuration = animationDuration
        self.routeCoordinates = routeCoordinates
        self.traveledCoordinates = traveledCoordinates
        self.markers = markers
        self.railwayRoutes = railwayRoutes
        self.markerStyle = markerStyle
        self.showCurrentPositionMarker = showCurrentPositionMarker
        self.showRoutePolyline = showRoutePolyline
        self.additionalContent = { EmptyMapContent() }
    }
}

#Preview {
    AnimatedTrackingMapView(
        cameraPosition: .constant(.automatic),
        currentCoordinate: CLLocationCoordinate2D(latitude: 35.6762, longitude: 139.6503),
        animationDuration: 0.5,
        routeCoordinates: [
            CLLocationCoordinate2D(latitude: 35.6762, longitude: 139.6503),
            CLLocationCoordinate2D(latitude: 35.6812, longitude: 139.6553)
        ],
        markers: [
            TrackingPoint(
                title: "Start",
                type: .start,
                location: CLLocationCoordinate2D(latitude: 35.6762, longitude: 139.6503),
                timestamp: Date()
            )
        ],
        markerStyle: .liveTracking
    )
}
