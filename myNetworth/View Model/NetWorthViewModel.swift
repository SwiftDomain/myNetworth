//
//  NetWorthViewModel.swift
//  myNetworth
//
//  Created by BeastMode on 12/5/25.
//

import SwiftUI
import SwiftData
import WidgetKit

// MARK: - View Model

@Observable
class NetWorthViewModel {

    var modelContext: ModelContext
    var searchText: String = ""
    /// Incremented on data mutations to trigger SwiftUI re-evaluation of computed properties
    private(set) var refreshToken: Int = 0

    private func didMutate() {
        refreshToken += 1
        WidgetCenter.shared.reloadAllTimelines()
    }

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        MigrationManager.migrateIfNeeded(modelContext: modelContext)
    }

    // MARK: - Fetched Data

    var assets: [FinancialItem] {
        _ = refreshToken
        let descriptor = FetchDescriptor<FinancialItem>(
            predicate: #Predicate { $0.itemType == "asset" },
            sortBy: [SortDescriptor(\.name)]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    var liabilities: [FinancialItem] {
        _ = refreshToken
        let descriptor = FetchDescriptor<FinancialItem>(
            predicate: #Predicate { $0.itemType == "liability" },
            sortBy: [SortDescriptor(\.name)]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    var years: [Int] {
        _ = refreshToken
        let descriptor = FetchDescriptor<TrackedYear>(
            sortBy: [SortDescriptor(\.year, order: .reverse)]
        )
        return ((try? modelContext.fetch(descriptor)) ?? []).map(\.year)
    }

    // MARK: - Settings

    var settings: UserSettings {
        let descriptor = FetchDescriptor<UserSettings>()
        if let existing = (try? modelContext.fetch(descriptor))?.first {
            return existing
        }
        let newSettings = UserSettings()
        modelContext.insert(newSettings)
        return newSettings
    }

    var currencyCode: String {
        settings.currencyCode
    }

    func updateCurrency(_ code: String) {
        settings.currencyCode = code
    }

    // MARK: - Yearly Data

    var yearlyData: [YearlyData] {
        years.sorted().map { getYearData(for: $0) }
    }

    func getYearData(for year: Int) -> YearlyData {
        let yearAssets = assets.filter { $0.year == year }
        let yearLiabilities = liabilities.filter { $0.year == year }

        let totalAssets = yearAssets.reduce(0) { $0 + $1.amount }
        let totalLiabilities = yearLiabilities.reduce(0) { $0 + $1.amount }

        var assetCategories: [AssetCategories: Int] = [:]
        for category in AssetCategories.allCases {
            let total = yearAssets
                .filter { $0.category == category.rawValue }
                .reduce(0) { $0 + $1.amount }
            if total > 0 {
                assetCategories[category] = total
            }
        }

        var liabilityCategories: [LiabilityCategories: Int] = [:]
        for category in LiabilityCategories.allCases {
            let total = yearLiabilities
                .filter { $0.category == category.rawValue }
                .reduce(0) { $0 + $1.amount }
            if total > 0 {
                liabilityCategories[category] = total
            }
        }

        return YearlyData(
            year: year,
            assets: totalAssets,
            liabilities: totalLiabilities,
            netWorth: totalAssets - totalLiabilities,
            assetCategoryTotal: assetCategories,
            liabilityCategoryTotal: liabilityCategories
        )
    }

    // MARK: - Monthly Data

    func monthlyData(for year: Int) -> [(month: Int, assets: Int, liabilities: Int, netWorth: Int)] {
        (1...12).map { month in
            let monthAssets = assets.filter { $0.year == year && $0.month == month }
                .reduce(0) { $0 + $1.amount }
            let monthLiabilities = liabilities.filter { $0.year == year && $0.month == month }
                .reduce(0) { $0 + $1.amount }
            return (month, monthAssets, monthLiabilities, monthAssets - monthLiabilities)
        }
    }

    func itemsForMonth(year: Int, month: Int, type: ItemType) -> [FinancialItem] {
        let typeString = type == .asset ? "asset" : "liability"
        let descriptor = FetchDescriptor<FinancialItem>(
            predicate: #Predicate {
                $0.year == year && $0.month == month && $0.itemType == typeString
            },
            sortBy: [SortDescriptor(\.name)]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    // MARK: - Percentage Change

    func percentageChange(for year: Int) -> Double? {
        let previousYear = year - 1
        guard years.contains(previousYear) else { return nil }
        let currentData = getYearData(for: year)
        let previousData = getYearData(for: previousYear)
        guard previousData.netWorth != 0 else { return nil }
        return Double(currentData.netWorth - previousData.netWorth)
            / Double(abs(previousData.netWorth)) * 100
    }

    // MARK: - Category Data

    func getCategoryData(for type: ItemType, year: Int) -> [(String, Int)] {
        let items = type == .asset
            ? assets.filter { $0.year == year }
            : liabilities.filter { $0.year == year }

        var categories: [String: Int] = [:]
        for item in items {
            categories[item.category, default: 0] += item.amount
        }

        return categories.map { ($0.key, $0.value) }.sorted { $0.1 > $1.1 }
    }

    // MARK: - CRUD: Years

    func addYear(_ year: Int) {
        guard !years.contains(year) else { return }
        modelContext.insert(TrackedYear(year: year))
        didMutate()
    }

    func deleteYear(_ year: Int) {
        // Delete the tracked year
        let yearDescriptor = FetchDescriptor<TrackedYear>(
            predicate: #Predicate { $0.year == year }
        )
        if let trackedYears = try? modelContext.fetch(yearDescriptor) {
            for ty in trackedYears { modelContext.delete(ty) }
        }

        // Delete all items for that year
        let itemDescriptor = FetchDescriptor<FinancialItem>(
            predicate: #Predicate { $0.year == year }
        )
        if let items = try? modelContext.fetch(itemDescriptor) {
            for item in items { modelContext.delete(item) }
        }
        didMutate()
    }

    // MARK: - CRUD: Items

    func addItem(_ item: FinancialItem) {
        modelContext.insert(item)
        didMutate()
    }

    func addAsset(_ item: FinancialItem) {
        modelContext.insert(item)
        didMutate()
    }

    func addLiability(_ item: FinancialItem) {
        modelContext.insert(item)
        didMutate()
    }

    func deleteItem(_ item: FinancialItem) {
        modelContext.delete(item)
        didMutate()
    }

    func deleteAsset(_ item: FinancialItem) {
        modelContext.delete(item)
        didMutate()
    }

    func deleteLiability(_ item: FinancialItem) {
        modelContext.delete(item)
        didMutate()
    }

    // MARK: - Search / Filter

    func filteredItems(_ items: [FinancialItem]) -> [FinancialItem] {
        guard !searchText.isEmpty else { return items }
        return items.filter {
            $0.name.localizedStandardContains(searchText)
                || $0.category.localizedStandardContains(searchText)
        }
    }

    // MARK: - Goals

    var goals: [Goal] {
        _ = refreshToken
        let descriptor = FetchDescriptor<Goal>(
            sortBy: [SortDescriptor(\.targetDate)]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    func addGoal(_ goal: Goal) {
        modelContext.insert(goal)
        didMutate()
    }

    func deleteGoal(_ goal: Goal) {
        modelContext.delete(goal)
        didMutate()
    }

    func goalProgress(for goal: Goal) -> Double {
        let currentYear = Calendar.current.component(.year, from: .now)
        let yearData = getYearData(for: currentYear)
        let currentAmount: Int
        switch goal.goalType {
        case "netWorth": currentAmount = yearData.netWorth
        case "asset": currentAmount = yearData.assets
        case "liability": currentAmount = yearData.liabilities
        default: currentAmount = yearData.netWorth
        }
        guard goal.targetAmount != 0 else { return 0 }
        return Double(currentAmount) / Double(goal.targetAmount)
    }

    // MARK: - Recurring Items

    var recurringItems: [RecurringItem] {
        _ = refreshToken
        let descriptor = FetchDescriptor<RecurringItem>(
            sortBy: [SortDescriptor(\.name)]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    func addRecurringItem(_ item: RecurringItem) {
        modelContext.insert(item)
        didMutate()
    }

    func deleteRecurringItem(_ item: RecurringItem) {
        modelContext.delete(item)
        didMutate()
    }

    func generateRecurringItems(for year: Int, month: Int) {
        let activeItems = recurringItems.filter(\.isActive)

        for recurring in activeItems {
            // Check if already generated
            let existing = assets.filter {
                $0.name == recurring.name
                    && $0.year == year
                    && $0.month == month
                    && $0.category == recurring.category
            } + liabilities.filter {
                $0.name == recurring.name
                    && $0.year == year
                    && $0.month == month
                    && $0.category == recurring.category
            }
            guard existing.isEmpty else { continue }

            let shouldGenerate: Bool
            switch recurring.frequency {
            case "monthly": shouldGenerate = true
            case "quarterly": shouldGenerate = [1, 4, 7, 10].contains(month)
            case "annually": shouldGenerate = month == 1
            default: shouldGenerate = false
            }

            if shouldGenerate {
                let item = FinancialItem(
                    name: recurring.name,
                    amount: recurring.amount,
                    year: year,
                    month: month,
                    category: recurring.category,
                    itemType: recurring.itemType,
                    isRecurring: true
                )
                modelContext.insert(item)
            }
        }
        didMutate()
    }

    // MARK: - Milestones

    var milestones: [Milestone] {
        _ = refreshToken
        let descriptor = FetchDescriptor<Milestone>(
            sortBy: [SortDescriptor(\.targetNetWorth)]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    func addMilestone(_ milestone: Milestone) {
        modelContext.insert(milestone)
        didMutate()
    }

    func deleteMilestone(_ milestone: Milestone) {
        modelContext.delete(milestone)
        didMutate()
    }

    func checkMilestones() {
        let currentYear = Calendar.current.component(.year, from: .now)
        let data = getYearData(for: currentYear)
        let unachieved = milestones.filter { !$0.isAchieved }
        for milestone in unachieved {
            if data.netWorth >= milestone.targetNetWorth {
                milestone.isAchieved = true
                milestone.achievedDate = .now
            }
        }
    }

    // MARK: - Custom Categories

    var customCategories: [CustomCategory] {
        _ = refreshToken
        let descriptor = FetchDescriptor<CustomCategory>(
            sortBy: [SortDescriptor(\.name)]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    func addCustomCategory(_ category: CustomCategory) {
        modelContext.insert(category)
        didMutate()
    }

    func deleteCustomCategory(_ category: CustomCategory) {
        modelContext.delete(category)
        didMutate()
    }

    func allCategoryNames(for type: ItemType) -> [String] {
        let builtIn: [String]
        if type == .asset {
            builtIn = AssetCategories.allCases.map(\.rawValue)
        } else {
            builtIn = LiabilityCategories.allCases.map(\.rawValue)
        }
        let custom = customCategories
            .filter { $0.itemType == type.rawValue }
            .map(\.name)
        return builtIn + custom
    }

    // MARK: - Export

    func generateCSV(for year: Int) -> String {
        var csv = "Name,Amount,Category,Type,Month\n"
        let allItems = (assets + liabilities).filter { $0.year == year }
        for item in allItems.sorted(by: { $0.name < $1.name }) {
            csv += "\(item.name),\(item.amount),\(item.category),\(item.itemType),\(item.month)\n"
        }
        return csv
    }

    // MARK: - PDF Export

    @MainActor
    func generatePDFURL(for year: Int) -> URL? {
        let data = getYearData(for: year)
        let view = PDFReportView(yearData: data, currencyCode: currencyCode)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2.0

        let url = URL.temporaryDirectory.appending(path: "NetWorth_\(year).pdf")

        renderer.render { size, context in
            var box = CGRect(origin: .zero, size: size)
            guard let pdfContext = CGContext(url as CFURL, mediaBox: &box, nil) else { return }
            pdfContext.beginPDFPage(nil)
            context(pdfContext)
            pdfContext.endPDFPage()
            pdfContext.closePDF()
        }

        return FileManager.default.fileExists(atPath: url.path()) ? url : nil
    }

    // MARK: - Color Scheme

    var resolvedColorScheme: ColorScheme? {
        switch settings.colorScheme {
        case "dark": return .dark
        case "light": return .light
        default: return nil
        }
    }
}

// MARK: - Number Formatting Utility

func formatNumber(_ number: Int) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    formatter.groupingSeparator = ","
    return formatter.string(from: NSNumber(value: number)) ?? "\(number)"
}

extension Formatter {
    static let zeroSymbol: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.zeroSymbol = ""
        return formatter
    }()
}
