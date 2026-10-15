//
//  BugFixTests.swift
//  myNetworthTests
//
//  The bug fixes and the widget data migration.
//

import Foundation
import SwiftData
import Testing
@testable import myNetworth

// MARK: - CSV Export

@MainActor
@Suite("CSV export")
struct CSVExportTests {

    @Test("Plain fields are left as they are")
    func plainFields() {
        #expect(csvField("Savings") == "Savings")
        #expect(csvField("1200") == "1200")
        #expect(csvField("") == "")
    }

    @Test("Fields with commas, quotes or line breaks are quoted")
    func specialCharacters() {
        #expect(csvField("Smith, John") == "\"Smith, John\"")
        #expect(csvField("The \"big\" one") == "\"The \"\"big\"\" one\"")
        #expect(csvField("Line one\nLine two") == "\"Line one\nLine two\"")
    }

    @Test("Export keeps each item in its own columns and only includes the chosen year")
    func exportYear() throws {
        let store = try TestStore()
        store.addItem("Smith, John loan", 5_000, year: 2024, category: "Other", asset: false)
        store.addItem("Checking", 1_200, year: 2024, category: "Cash", asset: true, month: 3)
        store.addItem("Old account", 900, year: 2023, category: "Cash", asset: true)

        let lines = store.viewModel.generateCSV(for: 2024)
            .split(separator: "\n")
            .map(String.init)

        #expect(lines == [
            "Name,Amount,Category,Type,Month",
            "Checking,1200,Cash,asset,3",
            "\"Smith, John loan\",5000,Other,liability,0",
        ])
    }
}

// MARK: - Editing Items

@MainActor
@Suite("Editing items")
struct EditItemTests {

    @Test("Editing an item saves every field")
    func updateItem() throws {
        let store = try TestStore()
        let item = store.addItem("Visa", 3_000, year: 2024, category: "Credit Card", asset: false)
        let createdAt = item.updatedAt

        store.viewModel.updateItem(item, name: "Visa Signature", amount: 2_500, category: "Other", month: 6)

        #expect(item.name == "Visa Signature")
        #expect(item.amount == 2_500)
        #expect(item.category == "Other")
        #expect(item.month == 6)
        #expect(item.updatedAt >= createdAt)
        #expect(store.viewModel.liabilities.map(\.amount) == [2_500])
    }
}

// MARK: - Shared Store

@MainActor
@Suite("Widget data migration")
struct SharedStoreTests {

    @Test("Every model is in the shared schema")
    func schemaHasEveryModel() {
        let names = Set(SharedStore.schema.entities.map(\.name))
        #expect(names == [
            "FinancialItem", "TrackedYear", "UserSettings", "Goal",
            "RecurringItem", "Milestone", "CustomCategory", "DebtTerms",
        ])
    }

    @Test("Copies the store and its side files into the shared container")
    func copiesStore() throws {
        let folders = try Folders()
        defer { folders.remove() }
        try write("main", to: folders.legacy)
        try write("wal", to: sideFile(of: folders.legacy, "-wal"))
        try write("shm", to: sideFile(of: folders.legacy, "-shm"))

        #expect(SharedStore.copyLegacyStoreIfNeeded(from: folders.legacy, to: folders.shared))

        #expect(try read(folders.shared) == "main")
        #expect(try read(sideFile(of: folders.shared, "-wal")) == "wal")
        #expect(try read(sideFile(of: folders.shared, "-shm")) == "shm")
        #expect(!exists(sideFile(of: folders.shared, ".copying")))
        // The original stays where it was as a backup.
        #expect(try read(folders.legacy) == "main")
    }

    @Test("Leaves an existing shared store alone")
    func keepsExistingSharedStore() throws {
        let folders = try Folders()
        defer { folders.remove() }
        try write("old", to: folders.legacy)
        try FileManager.default.createDirectory(
            at: folders.shared.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try write("current", to: folders.shared)

        #expect(SharedStore.copyLegacyStoreIfNeeded(from: folders.legacy, to: folders.shared))
        #expect(try read(folders.shared) == "current")
    }

    @Test("Does nothing when there's no old store")
    func noLegacyStore() throws {
        let folders = try Folders()
        defer { folders.remove() }

        #expect(SharedStore.copyLegacyStoreIfNeeded(from: folders.legacy, to: folders.shared))
        #expect(!exists(folders.shared))
    }

    @Test("Clears side files left behind by an interrupted copy")
    func clearsLeftovers() throws {
        let folders = try Folders()
        defer { folders.remove() }
        try write("main", to: folders.legacy)
        try FileManager.default.createDirectory(
            at: folders.shared.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try write("stale", to: sideFile(of: folders.shared, "-wal"))

        #expect(SharedStore.copyLegacyStoreIfNeeded(from: folders.legacy, to: folders.shared))
        #expect(try read(folders.shared) == "main")
        #expect(!exists(sideFile(of: folders.shared, "-wal")))
    }

    @Test("Reports a failed copy and leaves nothing half-copied")
    func failedCopy() throws {
        let folders = try Folders()
        defer { folders.remove() }
        try write("main", to: folders.legacy)
        try write("wal", to: sideFile(of: folders.legacy, "-wal"))
        // The shared store's folder is really a file, so nothing can be written into it.
        let blocker = folders.root.appending(path: "blocker")
        try write("not a folder", to: blocker)
        let shared = blocker.appending(path: "default.store")

        #expect(!SharedStore.copyLegacyStoreIfNeeded(from: folders.legacy, to: shared))
        #expect(!exists(shared))
        #expect(try read(folders.legacy) == "main")
    }

    // MARK: Helpers

    /// A temporary folder holding an old store location and a shared one.
    private struct Folders {
        let root = URL.temporaryDirectory.appending(path: "SharedStoreTests-\(UUID().uuidString)")
        var legacy: URL { root.appending(path: "Application Support/default.store") }
        var shared: URL { root.appending(path: "Group/Library/Application Support/default.store") }

        init() throws {
            try FileManager.default.createDirectory(
                at: legacy.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
        }

        func remove() {
            try? FileManager.default.removeItem(at: root)
        }
    }

    private func sideFile(of storeURL: URL, _ suffix: String) -> URL {
        storeURL.deletingLastPathComponent().appending(path: storeURL.lastPathComponent + suffix)
    }

    private func write(_ text: String, to url: URL) throws {
        try Data(text.utf8).write(to: url)
    }

    private func read(_ url: URL) throws -> String {
        let data = try Data(contentsOf: url)
        return String(decoding: data, as: UTF8.self)
    }

    private func exists(_ url: URL) -> Bool {
        FileManager.default.fileExists(atPath: url.path(percentEncoded: false))
    }
}
