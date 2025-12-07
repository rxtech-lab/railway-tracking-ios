# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Railway Train Track is an iOS app built with SwiftUI that tracks train journeys using GPS and analyzes station passes along the route. Uses SwiftData for persistence and native Apple frameworks only (no external dependencies).

## Build Commands

```bash
# Build the project
xcodebuild -scheme railway-train-track -configuration Debug

# Build for release
xcodebuild -scheme railway-train-track -configuration Release

# Clean build
xcodebuild clean -scheme railway-train-track
```

The Xcode project file is at `railway-train-track.xcodeproj`.

## Architecture

**MVVM with @Observable (iOS 17+)**
- ViewModels use `@Observable` macro, views use `@Bindable` for two-way binding
- SwiftData models in `Models/`, ViewModels in `ViewModels/`, SwiftUI views in `Views/`

**Key Data Flow:**
1. `LocationManager` → async location updates via `CLLocationUpdate.liveUpdates()`
2. `TrackingViewModel` → creates `LocationPoint` records, saves to SwiftData
3. `SessionDetailViewModel` → displays route on map, triggers station analysis
4. `TrainStationService` → fetches stations from Overpass API (OpenStreetMap)
5. `StationAnalysisService` → detects station passes using 200m proximity threshold
6. Export services → CSV, JSON, and video output with async/await

**SwiftData Models:**
- `TrackingSession` (1:many) → `LocationPoint` and `StationPassEvent`
- `TrainStation` (keyed by osmId from OpenStreetMap)

## Key Services

| Service | Purpose |
|---------|---------|
| `LocationManager` | CoreLocation wrapper with background tracking support |
| `TrainStationService` | Overpass API queries for train stations in bounding box |
| `StationAnalysisService` | Proximity-based station pass detection algorithm |
| `VideoExporter` | AVFoundation-based animated route video rendering |

## Background Location

The app uses background location updates. Key configuration:
- `Info.plist` contains location permission strings and background modes
- `CLBackgroundActivitySession()` maintains location updates when backgrounded
- Recording interval is user-configurable (0.5-10 seconds)

## Performance Considerations

- SwiftData saves every 10 location points to batch writes
- Export operations use async/await with progress callbacks
- Map playback uses Timer-based frame stepping
