//
//  SessionListView.swift
//  railway-train-track
//
//  Created by Qiwei Li on 12/6/25.
//

import SwiftUI
import SwiftData

struct SessionListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(TrackingViewModel.self) private var trackingViewModel
    @Query(sort: \TrackingSession.startTime, order: .reverse)
    private var sessions: [TrackingSession]

    @State private var showNewSessionSheet = false
    @State private var selectedActiveSession: TrackingSession?
    @State private var showRecoveryAlert = false
    @State private var showDeleteConfirmation = false
    @State private var sessionToDelete: TrackingSession?

    var body: some View {
        NavigationStack {
            Group {
                if sessions.isEmpty {
                    ContentUnavailableView(
                        "No Sessions",
                        systemImage: "train.side.front.car",
                        description: Text("Start tracking your train journey to see sessions here.")
                    )
                } else {
                    List {
                        ForEach(groupedSessions, id: \.key) { date, daySessions in
                            Section(header: Text(date, style: .date)) {
                                ForEach(daySessions) { session in
                                    sessionRow(for: session)
                                        .contextMenu {
                                            if !session.isActive && !trackingViewModel.hasActiveSession {
                                                Button {
                                                    trackingViewModel.resumeFinishedSession(session)
                                                    selectedActiveSession = session
                                                } label: {
                                                    Label("Resume Tracking", systemImage: "play.fill")
                                                }
                                            }
                                            Button(role: .destructive) {
                                                sessionToDelete = session
                                                showDeleteConfirmation = true
                                            } label: {
                                                Label("Delete", systemImage: "trash")
                                            }
                                        }
                                }
                                .onDelete { indexSet in
                                    deleteSession(from: daySessions, at: indexSet)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Sessions")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    EditButton()
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    if !trackingViewModel.hasActiveSession {
                        Button {
                            showNewSessionSheet = true
                        } label: {
                            Image(systemName: "plus")
                        }
                    }
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
                Button("Discard", role: .destructive) {
                    trackingViewModel.discardRecoveredSession()
                }
                Button("Cancel", role: .cancel) {
                    trackingViewModel.dismissRecoveryPrompt()
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
            NavigationLink(destination: SessionDetailView(session: session)) {
                SessionRowView(session: session)
            }
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

    private func deleteSession(from daySessions: [TrackingSession], at offsets: IndexSet) {
        if let index = offsets.first {
            sessionToDelete = daySessions[index]
            showDeleteConfirmation = true
        }
    }

    private func confirmDelete() {
        if let session = sessionToDelete {
            withAnimation {
                modelContext.delete(session)
                try? modelContext.save()
            }
            sessionToDelete = nil
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
