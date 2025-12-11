//
//  NotesTabView.swift
//  railway-train-track
//
//  Created by Qiwei Li on 12/8/25.
//

import SwiftUI

struct NotesTabView: View {
    @Bindable var viewModel: SessionDetailViewModel
    @State private var isEditing = false
    @State private var noteToDelete: SessionNote?
    @State private var showDeleteConfirmation = false

    var body: some View {
        VStack(spacing: 0) {
            if viewModel.sortedNotes.isEmpty {
                ContentUnavailableView(
                    "No Notes",
                    systemImage: "note.text",
                    description: Text("Add notes by tapping the note button in the toolbar, long-pressing on the map, or tapping on a station marker.")
                )
            } else {
                List {
                    ForEach(viewModel.sortedNotes) { note in
                        NoteRowView(note: note)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                viewModel.viewNoteDetail(note)
                            }
                    }
                    .onDelete { indexSet in
                        if let index = indexSet.first {
                            noteToDelete = viewModel.sortedNotes[index]
                            showDeleteConfirmation = true
                        }
                    }
                }
                .scrollContentBackground(.hidden)
                .listStyle(.sidebar)
                .environment(\.editMode, .constant(isEditing ? .active : .inactive))
            }
        }
        .alert("Delete Note?", isPresented: $showDeleteConfirmation, presenting: noteToDelete) { note in
            Button("Cancel", role: .cancel) {
                noteToDelete = nil
            }
            Button("Delete", role: .destructive) {
                viewModel.deleteNote(note)
                noteToDelete = nil
            }
        } message: { _ in
            Text("Are you sure you want to delete this note? This action cannot be undone.")
        }
        .toolbar {
            ToolbarItemGroup(placement: .bottomBar) {
                Button {
                    viewModel.addNoteAtCurrentPlaybackPosition()
                } label: {
                    Label("Add Note", systemImage: "plus")
                }

                Spacer()

                if !viewModel.sortedNotes.isEmpty {
                    Button(isEditing ? "Done" : "Edit") {
                        isEditing.toggle()
                    }
                }
            }
        }
    }
}

#Preview {
    NotesTabView(
        viewModel: SessionDetailViewModel(session: TrackingSession(name: "Test"))
    )
}
