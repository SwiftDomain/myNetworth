//
//  SharedStore.swift
//  myNetworth
//

import Foundation
import SwiftData

/// Where the app and the widget keep their SwiftData store.
///
/// The store lives in the App Group container so the widget can read it. Before the
/// App Group existed, SwiftData kept it in the app's own container, so the app copies
/// that data across on first launch with `copyLegacyStoreIfNeeded(to:)`.
///
/// This file must be a member of both the app and the widget extension targets.
enum SharedStore {

    static let appGroupID = "group.com.SwiftDomain.myNetworth"

    static var schema: Schema {
        Schema([
            FinancialItem.self,
            TrackedYear.self,
            UserSettings.self,
            Goal.self,
            RecurringItem.self,
            Milestone.self,
            CustomCategory.self,
        ])
    }

    /// The shared store, or `nil` when the App Group capability isn't enabled for this target.
    static var groupStoreURL: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupID)?
            .appending(path: "Library/Application Support/default.store")
    }

    /// Where SwiftData's default configuration keeps the store when there is no App Group.
    static var legacyStoreURL: URL {
        URL.applicationSupportDirectory.appending(path: "default.store")
    }

    /// Copies the store from the app's own container into the App Group container when
    /// the shared store doesn't exist yet, so enabling the App Group doesn't leave the
    /// user's data behind. The original is left in place as a backup.
    ///
    /// Returns `false` if the copy failed. The caller should keep using the legacy store
    /// for this launch; the copy is retried on the next one.
    static func copyLegacyStoreIfNeeded(to sharedURL: URL) -> Bool {
        let fileManager = FileManager.default
        try? fileManager.createDirectory(
            at: sharedURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        guard !fileManager.fileExists(atPath: sharedURL.path(percentEncoded: false)),
              fileManager.fileExists(atPath: legacyStoreURL.path(percentEncoded: false)) else {
            return true
        }

        // SQLite keeps recent writes in "-wal" and "-shm" side files, so those come along too.
        // The main file is copied under a temporary name and renamed into place last, so it
        // only appears in the group container once the whole copy has succeeded.
        let sideFileSuffixes = ["-wal", "-shm"]
        let staging = sibling(of: sharedURL, suffix: ".copying")
        do {
            for suffix in sideFileSuffixes {
                let source = sibling(of: legacyStoreURL, suffix: suffix)
                let destination = sibling(of: sharedURL, suffix: suffix)
                try? fileManager.removeItem(at: destination) // left over from an interrupted copy
                if fileManager.fileExists(atPath: source.path(percentEncoded: false)) {
                    try fileManager.copyItem(at: source, to: destination)
                }
            }
            try? fileManager.removeItem(at: staging)
            try fileManager.copyItem(at: legacyStoreURL, to: staging)
            try fileManager.moveItem(at: staging, to: sharedURL)
            return true
        } catch {
            for suffix in sideFileSuffixes {
                try? fileManager.removeItem(at: sibling(of: sharedURL, suffix: suffix))
            }
            try? fileManager.removeItem(at: staging)
            return false
        }
    }

    /// "…/default.store" plus "-wal" gives "…/default.store-wal".
    private static func sibling(of storeURL: URL, suffix: String) -> URL {
        storeURL.deletingLastPathComponent().appending(path: storeURL.lastPathComponent + suffix)
    }
}
