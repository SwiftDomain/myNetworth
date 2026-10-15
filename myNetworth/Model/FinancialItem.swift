//
//  FinancialItem.swift
//  myNetworth
//
//  Created by BeastMode on 12/5/25.
//

import SwiftData
import SwiftUI

// MARK: - Financial Item Model

@Model
class FinancialItem {
    var id: UUID = UUID()
    var name: String = ""
    var amount: Int = 0
    var year: Int = 0
    /// 0 = yearly (no specific month), 1-12 = monthly entry
    var month: Int = 0
    var category: String = ""
    /// "asset" or "liability"
    var itemType: String = ""
    var isRecurring: Bool = false
    var createdAt: Date = Date.now
    var updatedAt: Date = Date.now

    init(
        name: String,
        amount: Int,
        year: Int,
        month: Int = 0,
        category: String,
        itemType: String,
        isRecurring: Bool = false
    ) {
        self.id = UUID()
        self.name = name
        self.amount = amount
        self.year = year
        self.month = month
        self.category = category
        self.itemType = itemType
        self.isRecurring = isRecurring
        self.createdAt = .now
        self.updatedAt = .now
    }
}

// MARK: - Tracked Year Model

@Model
class TrackedYear {
    var year: Int = 0
    var createdAt: Date = Date.now

    init(year: Int) {
        self.year = year
        self.createdAt = .now
    }
}

// MARK: - User Settings Model

@Model
class UserSettings {
    var currencyCode: String = "USD"
    /// "system", "dark", or "light"
    var colorScheme: String = "system"
    var requireBiometricLock: Bool = false
    var createdAt: Date = Date.now

    init(currencyCode: String = "USD") {
        self.currencyCode = currencyCode
    }
}

// MARK: - Goal Model

@Model
class Goal {
    var id: UUID = UUID()
    var title: String = ""
    var targetAmount: Int = 0
    var targetDate: Date = Date.now
    /// "netWorth", "asset", "liability"
    var goalType: String = "netWorth"
    var isAchieved: Bool = false
    var achievedDate: Date? = nil
    var createdAt: Date = Date.now
    /// Debt goals only: total liabilities when the goal was set, which progress counts down
    /// from. `nil` until known; goals created before this existed get it filled in at launch.
    var startAmount: Int? = nil

    init(
        title: String,
        targetAmount: Int,
        targetDate: Date,
        goalType: String = "netWorth"
    ) {
        self.id = UUID()
        self.title = title
        self.targetAmount = targetAmount
        self.targetDate = targetDate
        self.goalType = goalType
    }
}

// MARK: - Recurring Item Model

/// No longer used by the app: the Recurring Items screen was removed. The model stays in
/// the schema so existing stores keep opening without a SwiftData migration.
@Model
class RecurringItem {
    var id: UUID = UUID()
    var name: String = ""
    var amount: Int = 0
    var category: String = ""
    /// "asset" or "liability"
    var itemType: String = ""
    /// "monthly", "quarterly", "annually"
    var frequency: String = "monthly"
    var isActive: Bool = true
    var createdAt: Date = Date.now

    init(
        name: String,
        amount: Int,
        category: String,
        itemType: String,
        frequency: String = "monthly"
    ) {
        self.id = UUID()
        self.name = name
        self.amount = amount
        self.category = category
        self.itemType = itemType
        self.frequency = frequency
    }
}

// MARK: - Milestone Model

@Model
class Milestone {
    var id: UUID = UUID()
    var title: String = ""
    var targetNetWorth: Int = 0
    var isAchieved: Bool = false
    var achievedDate: Date? = nil
    var createdAt: Date = Date.now

    init(title: String, targetNetWorth: Int) {
        self.id = UUID()
        self.title = title
        self.targetNetWorth = targetNetWorth
    }
}

// MARK: - Custom Category Model

@Model
class CustomCategory {
    var id: UUID = UUID()
    var name: String = ""
    /// "asset" or "liability"
    var itemType: String = ""
    var colorHex: String = "#808080"
    var createdAt: Date = Date.now

    init(name: String, itemType: String, colorHex: String = "#808080") {
        self.id = UUID()
        self.name = name
        self.itemType = itemType
        self.colorHex = colorHex
    }
}

// MARK: - Debt Terms Model

/// A debt's interest rate, minimum payment and whether it's in the payoff plan. Matched to
/// liabilities by name and category, so the terms carry over to the same debt every year.
@Model
class DebtTerms {
    var name: String = ""
    var category: String = ""
    /// Annual interest rate as a percentage, e.g. 24.9.
    var annualRate: Double = 0
    var minimumPayment: Int = 0
    var isIncludedInPlan: Bool = true
    var createdAt: Date = Date.now

    init(name: String, category: String, annualRate: Double, minimumPayment: Int, isIncludedInPlan: Bool) {
        self.name = name
        self.category = category
        self.annualRate = annualRate
        self.minimumPayment = minimumPayment
        self.isIncludedInPlan = isIncludedInPlan
    }
}

// MARK: - Balances

/// Entries with the same name, category and type are one account.
private struct AccountKey: Hashable {
    let name: String
    let category: String
    let itemType: String

    init(_ item: FinancialItem) {
        name = item.name
        category = item.category
        itemType = item.itemType
    }
}

extension Collection where Element == FinancialItem {

    /// The entries that make up each account's balance as of `month`, from one year's items.
    ///
    /// An account's balance is its most recent entry: a monthly entry replaces the yearly
    /// amount from that month on, and a later month replaces an earlier one, so updates
    /// aren't added on top of the old amount. Entries for the same account in the same
    /// month are added together, as with two yearly items of the same name.
    func latestEntries(throughMonth month: Int = 12) -> [FinancialItem] {
        let entries = filter { $0.month <= month }
        var latestMonth: [AccountKey: Int] = [:]
        for item in entries {
            let key = AccountKey(item)
            latestMonth[key] = Swift.max(latestMonth[key] ?? 0, item.month)
        }
        return entries.filter { $0.month == latestMonth[AccountKey($0)] }
    }
}

// MARK: - Computed Yearly Data (not persisted)

struct YearlyData: Identifiable {
    var id: Int { year }
    var year: Int
    var assets: Int
    var liabilities: Int
    var netWorth: Int
    var assetCategoryTotal: [AssetCategories: Int]
    var liabilityCategoryTotal: [LiabilityCategories: Int]
}

/// Balances as of the end of one month.
struct MonthlyBalance: Identifiable {
    var id: Int { month }
    let month: Int
    let assets: Int
    let liabilities: Int
    /// Whether anything was entered for this month. Other months only carry earlier balances.
    let hasEntries: Bool

    var netWorth: Int { assets - liabilities }
}

// MARK: - Legacy Model (for UserDefaults migration)

struct LegacyFinancialItem: Codable {
    var id: UUID
    var name: String
    var amount: Int
    var year: Int
    var category: String
}

// MARK: - Enums

enum ItemType: String {
    case asset, liability
}

enum AssetCategories: String, Codable, CaseIterable {
    case cash = "Cash"
    case investments = "Investments"
    case realEstate = "Real Estate"
    case retirement = "Retirement"
    case vehicle = "Vehicle"
    case crypto = "Crypto"
    case furniture = "Furniture"
    case jewelry = "Jewelry"
    case other = "Other"

    var assetColor: Color {
        switch self {
        case .cash: .green
        case .investments: .orange
        case .realEstate: .yellow
        case .other: .gray
        case .crypto: .mint
        case .retirement: .blue
        case .vehicle: .brown
        case .furniture: .orange
        case .jewelry: .red
        }
    }
}

enum LiabilityCategories: String, Codable, CaseIterable {
    case mortgage = "Mortgage"
    case autoLoan = "Auto Loan"
    case creditCard = "Credit Card"
    case studentLoan = "Student Loan"
    case other = "Other"

    var liabilityColor: Color {
        switch self {
        case .mortgage: .green
        case .autoLoan: .orange
        case .creditCard: .red
        case .studentLoan: .blue
        case .other: .gray
        }
    }
}
