//
//  ContentView.swift
//  Lost in Integration
//
//  Temporary placeholder root view. This is replaced by `SessionListView`
//  in the "Session list + export" build step.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    var body: some View {
        SessionListView()
    }
}

#Preview {
    ContentView()
        .modelContainer(for: RecordingSession.self, inMemory: true)
}
