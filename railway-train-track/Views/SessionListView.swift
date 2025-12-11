//
//  SessionListView.swift
//  railway-train-track
//
//  Created by Qiwei Li on 12/6/25.
//

import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct SessionListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(TrackingViewModel.self) private var trackingViewModel
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Query(sort: \TrackingSession.startTime, order: .reverse)
    private var sessions: [TrackingSession]

    @State private var selectedSession: TrackingSession?
    @State private var showNewSessionSheet = false
    @State private var selectedActiveSession: TrackingSession?
    @State private var columnVisibility: NavigationSplitViewVisibility = .automatic
    @State private var showRecoveryAlert = false
    @State private var showDeleteConfirmation = false
    @State private var sessionToDelete: TrackingSession?
    @State private var sessionToEdit: TrackingSession?
    @State private var showImportPicker = false
    @State private var showImportError = false
    @State private var importErrorMessage = ""
    @State private var showImportSuccess = false
    @State private var importedSessionName = ""

    // For iPad/Mac 3-column layout: shared viewModel across content and detail columns
    @State private var detailViewModel: SessionDetailViewModel?
    @State private var exportViewModel = ExportViewModel()

    var body: some View {
        Group {
            if horizontalSizeClass == .regular {
                threeColumnLayout
            } else {
                twoColumnLayout
            }
        }
        .sheet(isPresented: $showNewSessionSheet) {
            NewSessionSheet { createdSession in
                selectedActiveSession = createdSession
            }
        }
        .sheet(item: $selectedActiveSession) { session in
            ActiveSessionSheet(session: session)
        }
        .sheet(item: $sessionToEdit) { session in
            SessionEditSheet(session: session)
        }
        .onAppear {
            if trackingViewModel.hasRecoverableSession {
                showRecoveryAlert = true
            }
        }
        .alert("Session Found", isPresented: $showRecoveryAlert) {
            Button("Resume") {
                trackingViewModel.resumeRecoveredSession()
                selectedActiveSession = trackingViewModel.currentSession
            }
            Button("Discard", role: .cancel) {
                trackingViewModel.discardRecoveredSession()
            }
        } message: {
            Text("You have an active recording session that was interrupted. Would you like to resume it?")
        }
        .alert("Delete Session", isPresented: $showDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                confirmDelete()
            }
            Button("Cancel", role: .cancel) {
                sessionToDelete = nil
            }
        } message: {
            Text("Are you sure you want to delete this session? This cannot be undone.")
        }
        .fileImporter(
            isPresented: $showImportPicker,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            handleImportResult(result)
        }
        .alert("Import Successful", isPresented: $showImportSuccess) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Successfully imported session: \(importedSessionName)")
        }
        .alert("Import Failed", isPresented: $showImportError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(importErrorMessage)
        }
        .onChange(of: selectedSession) { _, newSession in
            // Update shared viewModel when session changes (for iPad 3-column)
            if let session = newSession {
                detailViewModel = SessionDetailViewModel(session: session)
                exportViewModel.setDefaultFilename(from: session)
            } else {
                detailViewModel = nil
            }
        }
    }

    // MARK: - Three Column Layout (iPad/Mac)

    private var threeColumnLayout: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            sidebarContent
        } content: {
            if let session = selectedSession, let vm = detailViewModel {
                SessionDetailView(
                    session: session,
                    presentationMode: .column,
                    externalViewModel: vm
                )
                .id(session.id)
            } else {
                ContentUnavailableView(
                    "Select a Session",
                    systemImage: "train.side.front.car",
                    description: Text("Choose a session from the list to view its details.")
                )
            }
        } detail: {
            if let vm = detailViewModel {
                DetailColumnView(
                    viewModel: vm,
                    exportViewModel: exportViewModel
                )
            } else {
                ContentUnavailableView(
                    "No Session Selected",
                    systemImage: "sidebar.right",
                    description: Text("Select a session to view locations, stations, and notes.")
                )
            }
        }
    }

    // MARK: - Two Column Layout (iPhone)

    private var twoColumnLayout: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            sidebarContent
        } detail: {
            if let session = selectedSession {
                SessionDetailView(session: session, presentationMode: .sheet)
                    .id(session.id)
            } else {
                ContentUnavailableView(
                    "Select a Session",
                    systemImage: "train.side.front.car",
                    description: Text("Choose a session from the list to view its details.")
                )
            }
        }
    }

    // MARK: - Sidebar Content

    private var sidebarContent: some View {
        Group {
            if sessions.isEmpty {
                ContentUnavailableView(
                    "No Sessions",
                    systemImage: "train.side.front.car",
                    description: Text("Start tracking your train journey to see sessions here.")
                )
            } else {
                List(selection: $selectedSession) {
                    ForEach(groupedSessions, id: \.key) { date, daySessions in
                        Section(header: Text(date, style: .date)) {
                            ForEach(daySessions) { session in
                                sessionRow(for: session)
                                    .tag(session)
                                    .contextMenu {
                                        ResumeTrackingButton(session: session) {
                                            selectedActiveSession = session
                                        }

                                        StopAndPauseTrackingButton(showPauseButton: false)

                                        Button {
                                            sessionToEdit = session
                                        } label: {
                                            Label("Edit", systemImage: "pencil")
                                        }
                                        Button(role: .destructive) {
                                            sessionToDelete = session
                                            showDeleteConfirmation = true
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
                                    .swipeActions(edge: .trailing) {
                                        Button(role: .destructive) {
                                            sessionToDelete = session
                                            showDeleteConfirmation = true
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
                                    .swipeActions(edge: .leading) {
                                        Button {
                                            sessionToEdit = session
                                        } label: {
                                            Label("Edit", systemImage: "pencil")
                                        }
                                        .tint(.orange)
                                    }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Sessions")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button {
                        showNewSessionSheet = true
                    } label: {
                        Label("New Session", systemImage: "plus")
                    }
                    .disabled(trackingViewModel.hasActiveSession)

                    Button {
                        showImportPicker = true
                    } label: {
                        Label("Import Session", systemImage: "square.and.arrow.down")
                    }
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
    }

    @ViewBuilder
    private func sessionRow(for session: TrackingSession) -> some View {
        if session.isActive {
            Button {
                // If this is the recoverable session, resume it properly
                if trackingViewModel.recoverableSession?.id == session.id {
                    trackingViewModel.resumeRecoveredSession()
                } else if !trackingViewModel.isTracking {
                    // Handle orphaned active session - resume tracking
                    trackingViewModel.resumeFinishedSession(session)
                }
                selectedActiveSession = session
            } label: {
                SessionRowView(session: session)
            }
            .foregroundStyle(.primary)
        } else {
            SessionRowView(session: session)
        }
    }

    // Group sessions by date
    private var groupedSessions: [(key: Date, value: [TrackingSession])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: sessions) { session in
            calendar.startOfDay(for: session.startTime)
        }
        return grouped.sorted { $0.key > $1.key }
    }

    private func confirmDelete() {
        if let session = sessionToDelete {
            withAnimation {
                if selectedSession?.id == session.id {
                    selectedSession = nil
                }
                trackingViewModel.clearSessionIfDeleted(session)
                modelContext.delete(session)
                try? modelContext.save()
            }
            sessionToDelete = nil
        }
    }

    private func handleImportResult(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }

            guard url.startAccessingSecurityScopedResource() else {
                importErrorMessage = "Unable to access the selected file."
                showImportError = true
                return
            }

            defer { url.stopAccessingSecurityScopedResource() }

            do {
                let importer = JSONImporter()
                let importedData = try importer.importSession(from: url)

                let session = TrackingSession(
                    name: "Imported: \(importedData.name)",
                    recordingInterval: 1.0
                )
                session.startTime = importedData.startTime
                session.endTime = importedData.endTime
                session.isActive = false
                session.totalDistance = importedData.totalDistance
                session.averageSpeed = importedData.averageSpeed

                modelContext.insert(session)

                for pointData in importedData.locationPoints {
                    let point = LocationPoint(
                        timestamp: pointData.timestamp,
                        latitude: pointData.latitude,
                        longitude: pointData.longitude,
                        altitude: pointData.altitude,
                        horizontalAccuracy: pointData.horizontalAccuracy,
                        verticalAccuracy: pointData.verticalAccuracy,
                        speed: pointData.speed,
                        course: pointData.course
                    )
                    point.session = session
                    modelContext.insert(point)
                }

                try modelContext.save()

                importedSessionName = importedData.name
                showImportSuccess = true

            } catch {
                importErrorMessage = error.localizedDescription
                showImportError = true
            }

        case .failure(let error):
            importErrorMessage = error.localizedDescription
            showImportError = true
        }
    }
}

struct SessionRowView: View {
    let session: TrackingSession

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(session.name)
                    .font(.headline)

                Spacer()

                if session.isActive {
                    Label("Recording", systemImage: "record.circle")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            HStack {
                Label(session.startTime.formatted(date: .omitted, time: .shortened), systemImage: "clock")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text("•")
                    .foregroundStyle(.secondary)

                Text(session.formattedDuration)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text("•")
                    .foregroundStyle(.secondary)

                Text("\(session.locationPoints.count) points")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let distance = session.totalDistance {
                HStack {
                    Label(session.formattedDistance, systemImage: "arrow.left.and.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if session.stationAnalysisCompleted {
                        Text("•")
                            .foregroundStyle(.secondary)

                        Label("\(session.stationPassEvents.count) stations", systemImage: "train.side.front.car")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    SessionListView()
        .modelContainer(for: [TrackingSession.self, LocationPoint.self], inMemory: true)
        .environment(TrackingViewModel())
}
