//
//  Lost_in_IntegrationApp.swift
//  Lost in Integration
//
//  Created by Alexander Lazarov on 20.07.26.
//

import SwiftUI
import SwiftData

@main
struct Lost_in_IntegrationApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            RecordingSession.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
