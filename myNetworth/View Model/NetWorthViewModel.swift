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
        backfillDebtGoalStarts()
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

    /// The largest tracked year that is not in the future (≤ the current
    /// calendar year), used as the "current" snapshot of debts. `years` is
    /// already sorted descending, so the first match is the largest.
    var currentDebtYear: Int? {
        let currentYear = Calendar.current.component(.year, from: .now)
        return years.first { $0 <= currentYear }
    }

    // MARK: - Debt Payoff Planner

    var debtTerms: [DebtTerms] {
        _ = refreshToken
        let descriptor = FetchDescriptor<DebtTerms>(
            sortBy: [SortDescriptor(\.name)]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    /// Debts in the current snapshot year, largest first.
    var currentDebts: [FinancialItem] {
        guard let year = currentDebtYear else { return [] }
        return liabilities
            .filter { $0.year == year && $0.amount > 0 }
            .sorted { $0.amount > $1.amount }
    }

    /// Saved terms for a debt, matched by name and category so they carry across years.
    func terms(for debt: FinancialItem) -> DebtTerms? {
        debtTerms.first { $0.name == debt.name && $0.category == debt.category }
    }

    /// Whether a debt is in the payoff plan. Mortgages are left out by default so a
    /// long-term loan doesn't swamp the plan.
    func isIncludedInPlan(_ debt: FinancialItem) -> Bool {
        terms(for: debt)?.isIncludedInPlan ?? (debt.category != LiabilityCategories.mortgage.rawValue)
    }

    func updateTerms(for debt: FinancialItem, annualRate: Double, minimumPayment: Int, isIncluded: Bool) {
        if let saved = terms(for: debt) {
            saved.annualRate = annualRate
            saved.minimumPayment = minimumPayment
            saved.isIncludedInPlan = isIncluded
        } else {
            let newTerms = DebtTerms(
                name: debt.name,
                category: debt.category,
                annualRate: annualRate,
                minimumPayment: minimumPayment,
                isIncludedInPlan: isIncluded
            )
            modelContext.insert(newTerms)
        }
        didMutate()
    }

    func setIncludedInPlan(_ isIncluded: Bool, for debt: FinancialItem) {
        let saved = terms(for: debt)
        updateTerms(
            for: debt,
            annualRate: saved?.annualRate ?? 0,
            minimumPayment: saved?.minimumPayment ?? 0,
            isIncluded: isIncluded
        )
    }

    /// The debts in the plan, with their terms, ready for `DebtPlanner`. Debts without
    /// saved terms count as 0% interest with no minimum payment.
    var plannerDebts: [PlannerDebt] {
        currentDebts
            .filter { isIncludedInPlan($0) }
            .map { debt in
                let saved = terms(for: debt)
                return PlannerDebt(
                    id: debt.id,
                    name: debt.name,
                    balance: debt.amount,
                    annualRate: saved?.annualRate ?? 0,
                    minimumPayment: saved?.minimumPayment ?? 0
                )
            }
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

    /// Items recorded for the whole year rather than for a specific month.
    func yearlyItems(in year: Int) -> [FinancialItem] {
        (assets + liabilities).filter { $0.year == year && $0.month == 0 }
    }

    /// The closest earlier year that has yearly items, which a new year can start from.
    func carryForwardSource(for year: Int) -> Int? {
        let yearsWithYearlyItems = Set((assets + liabilities).filter { $0.month == 0 }.map(\.year))
        // `years` is sorted newest first, so the first match is the closest earlier year.
        return years.first { $0 < year && yearsWithYearlyItems.contains($0) }
    }

    /// Adds a year, optionally starting it with a copy of another year's yearly items
    /// (amounts included) so they don't have to be typed in again.
    func addYear(_ year: Int, copyingItemsFrom sourceYear: Int? = nil) {
        guard !years.contains(year) else { return }
        modelContext.insert(TrackedYear(year: year))
        if let sourceYear {
            for item in yearlyItems(in: sourceYear) {
                let copy = FinancialItem(
                    name: item.name,
                    amount: item.amount,
                    year: year,
                    category: item.category,
                    itemType: item.itemType
                )
                modelContext.insert(copy)
            }
        }
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

    /// Saves the amounts confirmed in Update Balances in one go.
    func updateAmounts(_ newAmounts: [UUID: Int], of items: [FinancialItem]) {
        for item in items {
            guard let amount = newAmounts[item.id], amount != item.amount else { continue }
            item.amount = amount
            item.updatedAt = .now
        }
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

    func updateItem(_ item: FinancialItem, name: String, amount: Int, category: String, month: Int) {
        item.name = name
        item.amount = amount
        item.category = category
        item.month = month
        item.updatedAt = .now
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
        if goal.goalType == "liability" {
            goal.startAmount = debtWhenSet(goal)
        }
        modelContext.insert(goal)
        didMutate()
    }

    func deleteGoal(_ goal: Goal) {
        modelContext.delete(goal)
        didMutate()
    }

    /// Tracked years that have at least one item, newest first.
    private var yearsWithData: [Int] {
        let yearsWithItems = Set((assets + liabilities).map(\.year))
        return years.filter { yearsWithItems.contains($0) }
    }

    /// The most recent year, not in the future, that has items. Goal progress is measured
    /// against it, since the calendar year may not have been filled in yet.
    var latestYearWithData: Int? {
        let thisYear = Calendar.current.component(.year, from: .now)
        return yearsWithData.first { $0 <= thisYear }
    }

    /// How far along a goal is, from 0 (not started) to 1 (reached).
    func goalProgress(for goal: Goal) -> Double {
        guard let year = latestYearWithData else { return 0 }
        let current = getYearData(for: year)

        let progress: Double
        switch goal.goalType {
        case "liability":
            // Debt goals count down: progress is the share of the debt paid off since the
            // goal was set, so owing more than the target no longer reads as "complete".
            let start = goal.startAmount ?? current.liabilities
            let toPayOff = start - goal.targetAmount
            guard toPayOff > 0 else { return current.liabilities <= goal.targetAmount ? 1 : 0 }
            progress = Double(start - current.liabilities) / Double(toPayOff)
        case "asset":
            guard goal.targetAmount > 0 else { return 0 }
            progress = Double(current.assets) / Double(goal.targetAmount)
        default:
            guard goal.targetAmount > 0 else { return 0 }
            progress = Double(current.netWorth) / Double(goal.targetAmount)
        }
        return min(max(progress, 0), 1)
    }

    /// Total liabilities in the latest year with data on or before the year the goal was
    /// created (or the earliest year with data if there's none): the debt a goal starts from.
    private func debtWhenSet(_ goal: Goal) -> Int? {
        let createdYear = Calendar.current.component(.year, from: goal.createdAt)
        let candidates = yearsWithData
        guard let year = candidates.first(where: { $0 <= createdYear }) ?? candidates.last else {
            return nil
        }
        return getYearData(for: year).liabilities
    }

    /// Debt goals made before `startAmount` existed get it filled in once from the data, so
    /// their starting point stays fixed when that year's numbers are edited later.
    private func backfillDebtGoalStarts() {
        for goal in goals where goal.goalType == "liability" && goal.startAmount == nil {
            goal.startAmount = debtWhenSet(goal)
        }
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

    // MARK: - Insights

    /// Every item as plain values for `InsightsEngine`.
    var insightItems: [InsightItem] {
        (assets + liabilities).map { item in
            InsightItem(
                name: item.name,
                category: item.category,
                isAsset: item.itemType == "asset",
                amount: item.amount,
                year: item.year
            )
        }
    }

    // MARK: - Export

    func generateCSV(for year: Int) -> String {
        var csv = "Name,Amount,Category,Type,Month\n"
        let allItems = (assets + liabilities).filter { $0.year == year }
        for item in allItems.sorted(by: { $0.name < $1.name }) {
            let fields = [item.name, String(item.amount), item.category, item.itemType, String(item.month)]
            csv += fields.map(csvField).joined(separator: ",") + "\n"
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

// MARK: - CSV Utility

/// Quotes a CSV field that contains a comma, quote or line break, doubling any
/// embedded quotes (RFC 4180), so names like "Smith, John" stay in one column.
func csvField(_ value: String) -> String {
    guard value.contains(where: { $0 == "," || $0 == "\"" || $0.isNewline }) else {
        return value
    }
    return "\"" + value.replacing("\"", with: "\"\"") + "\""
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
