//
//  SessionListView.swift
//  Lost in Integration
//
//  Root view: lists recorded sessions, starts new recordings, and exports or
//  deletes existing ones.
//

import SwiftUI
import SwiftData

struct SessionListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \RecordingSession.startedAt, order: .reverse)
    private var sessions: [RecordingSession]

    @State private var shareItem: ShareItem?
    @State private var exportError: String?

    var body: some View {
        NavigationStack {
            Group {
                if sessions.isEmpty {
                    ContentUnavailableView(
                        "No sessions yet",
                        systemImage: "waveform.path.ecg",
                        description: Text("Tap Record to capture your first IMU + GPX session.")
                    )
                } else {
                    List {
                        ForEach(sessions) { session in
                            NavigationLink(value: session) {
                                SessionRow(session: session)
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    delete(session)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                                Button {
                                    export(session)
                                } label: {
                                    Label("Export", systemImage: "square.and.arrow.up")
                                }
                                .tint(.blue)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Sessions")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink {
                        SettingsView()
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        RecordingView()
                    } label: {
                        Label("Record", systemImage: "record.circle")
                    }
                }
            }
            .navigationDestination(for: RecordingSession.self) { session in
                SessionDetailView(session: session)
            }
            .sheet(item: $shareItem) { item in
                ShareSheet(url: item.url)
            }
            .alert("Export failed",
                   isPresented: .constant(exportError != nil),
                   actions: { Button("OK") { exportError = nil } },
                   message: { Text(exportError ?? "") })
        }
    }

    private func export(_ session: RecordingSession) {
        let dir = SessionStore.url(forRelativeDir: session.relativeDir)
        do {
            let url = try SessionExporter.makeZip(sessionDir: dir, suggestedName: session.name)
            shareItem = ShareItem(url: url)
        } catch {
            exportError = error.localizedDescription
        }
    }

    private func delete(_ session: RecordingSession) {
        let dir = SessionStore.url(forRelativeDir: session.relativeDir)
        try? FileManager.default.removeItem(at: dir)
        modelContext.delete(session)
        try? modelContext.save()
    }
}

private struct SessionRow: View {
    let session: RecordingSession

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(session.name)
                .font(.headline)
                .lineLimit(1)
            HStack(spacing: 12) {
                Label(session.startedAt.formatted(date: .abbreviated, time: .shortened),
                      systemImage: "calendar")
                Label(durationString(session.duration), systemImage: "clock")
                if !session.isFinalized {
                    Text("in progress")
                        .foregroundStyle(.orange)
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }

    private func durationString(_ t: TimeInterval) -> String {
        let s = Int(t)
        if s >= 3600 { return String(format: "%dh %dm", s / 3600, (s % 3600) / 60) }
        if s >= 60 { return String(format: "%dm %ds", s / 60, s % 60) }
        return "\(s)s"
    }
}

#Preview {
    SessionListView()
        .modelContainer(for: RecordingSession.self, inMemory: true)
}
