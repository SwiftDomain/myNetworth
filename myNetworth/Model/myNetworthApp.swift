//
//  myNetworthApp.swift
//  myNetworth
//
//  Created by BeastMode on 12/5/25.
//

import SwiftUI
import SwiftData
import UserNotifications

@main
struct myNetworthApp: App {

    private let modelContainer: ModelContainer

    init() {
        // Set before launch finishes, so tapping the monthly reminder to open the app is handled.
        UNUserNotificationCenter.current().delegate = NotificationDelegate.shared
        SharedStore.moveSettingsToSharedDefaults()

        let schema = SharedStore.schema

        // Shared with the widget. Existing data is copied in the first time; if that copy
        // fails, keep using the data where it is and retry on the next launch.
        let storeURL: URL?
        if let groupStoreURL = SharedStore.groupStoreURL {
            storeURL = SharedStore.copyLegacyStoreIfNeeded(to: groupStoreURL)
                ? groupStoreURL
                : SharedStore.legacyStoreURL
        } else {
            storeURL = nil
        }

        func configuration(syncing cloudKitDatabase: ModelConfiguration.CloudKitDatabase) -> ModelConfiguration {
            if let storeURL {
                return ModelConfiguration(schema: schema, url: storeURL, cloudKitDatabase: cloudKitDatabase)
            }
            return ModelConfiguration(schema: schema, cloudKitDatabase: cloudKitDatabase)
        }

        do {
            // Syncs through the iCloud container in the app's entitlements, whenever the
            // user is signed in to iCloud.
            modelContainer = try ModelContainer(for: schema, configurations: [configuration(syncing: .automatic)])
        } catch {
            // If iCloud can't be set up, keep working with the data on this device.
            do {
                modelContainer = try ModelContainer(for: schema, configurations: [configuration(syncing: .none)])
            } catch {
                fatalError("Failed to create model container: \(error)")
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            HomePage()
        }
        .modelContainer(modelContainer)
    }
}
