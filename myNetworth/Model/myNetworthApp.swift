//
//  myNetworthApp.swift
//  myNetworth
//
//  Created by BeastMode on 12/5/25.
//

import SwiftUI
import SwiftData

@main
struct myNetworthApp: App {

    private let modelContainer: ModelContainer

    init() {
        let schema = SharedStore.schema

        let configuration: ModelConfiguration
        if let groupStoreURL = SharedStore.groupStoreURL {
            // Shared with the widget. Existing data is copied in the first time; if that
            // copy fails, keep using the data where it is and retry on the next launch.
            let storeURL = SharedStore.copyLegacyStoreIfNeeded(to: groupStoreURL)
                ? groupStoreURL
                : SharedStore.legacyStoreURL
            configuration = ModelConfiguration(
                schema: schema,
                url: storeURL,
                cloudKitDatabase: .automatic
            )
        } else {
            configuration = ModelConfiguration(schema: schema)
        }

        do {
            modelContainer = try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Failed to create model container: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            HomePage()
        }
        .modelContainer(modelContainer)
    }
}
