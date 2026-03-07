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
        let schema = Schema([
            FinancialItem.self,
            TrackedYear.self,
            UserSettings.self,
            Goal.self,
            RecurringItem.self,
            Milestone.self,
            CustomCategory.self,
        ])

        let appGroupID = "group.com.SwiftDomain.myNetworth"
        let hasAppGroup = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupID
        ) != nil

        let configuration: ModelConfiguration
        if hasAppGroup {
            configuration = ModelConfiguration(
                schema: schema,
                groupContainer: .identifier(appGroupID),
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
