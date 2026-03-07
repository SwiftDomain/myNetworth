//
//  MigrationManager.swift
//  myNetworth
//

import SwiftData
import Foundation

/// Migrates data from UserDefaults (legacy) to SwiftData (modern).
enum MigrationManager {

    static func migrateIfNeeded(modelContext: ModelContext) {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: "swiftdata_migration_complete") else { return }

        // Check if there's any legacy data to migrate
        let hasLegacyData = defaults.string(forKey: "assets") != nil
            || defaults.string(forKey: "liabilities") != nil
            || defaults.string(forKey: "years") != nil

        guard hasLegacyData else {
            defaults.set(true, forKey: "swiftdata_migration_complete")
            return
        }

        // Migrate assets
        if let assetsString = defaults.string(forKey: "assets"),
           let data = assetsString.data(using: .utf8),
           let oldAssets = try? JSONDecoder().decode([LegacyFinancialItem].self, from: data) {
            for old in oldAssets {
                let item = FinancialItem(
                    name: old.name,
                    amount: old.amount,
                    year: old.year,
                    category: old.category,
                    itemType: "asset"
                )
                modelContext.insert(item)
            }
        }

        // Migrate liabilities
        if let liabilitiesString = defaults.string(forKey: "liabilities"),
           let data = liabilitiesString.data(using: .utf8),
           let oldLiabilities = try? JSONDecoder().decode([LegacyFinancialItem].self, from: data) {
            for old in oldLiabilities {
                let item = FinancialItem(
                    name: old.name,
                    amount: old.amount,
                    year: old.year,
                    category: old.category,
                    itemType: "liability"
                )
                modelContext.insert(item)
            }
        }

        // Migrate tracked years
        if let yearsString = defaults.string(forKey: "years"),
           let data = yearsString.data(using: .utf8),
           let oldYears = try? JSONDecoder().decode([Int].self, from: data) {
            for year in oldYears {
                modelContext.insert(TrackedYear(year: year))
            }
        }

        defaults.set(true, forKey: "swiftdata_migration_complete")
    }
}
