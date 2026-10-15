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
        updateAchievedGoals()
        refreshToken += 1
        WidgetCenter.shared.reloadAllTimelines()
    }

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        MigrationManager.migrateIfNeeded(modelContext: modelContext)
        moveMilestonesToGoals()
        backfillDebtGoalStarts()
        updateAchievedGoals()
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

    /// The year the debt planner reads debts from: the latest year, not in the future, that
    /// has items, so a new year that hasn't been filled in yet doesn't empty the plan.
    var currentDebtYear: Int? {
        latestYearWithData
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
        return latestEntries(in: year)
            .filter { $0.itemType == "liability" && $0.amount > 0 }
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

    /// The entries that make up each account's balance in `year`. See `latestEntries(throughMonth:)`.
    func latestEntries(in year: Int) -> [FinancialItem] {
        (assets + liabilities).filter { $0.year == year }.latestEntries()
    }

    func getYearData(for year: Int) -> YearlyData {
        let entries = latestEntries(in: year)
        let yearAssets = entries.filter { $0.itemType == "asset" }
        let yearLiabilities = entries.filter { $0.itemType == "liability" }

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

    /// Balances at the end of each month: every account at its latest amount so far, with
    /// yearly amounts counting until a monthly entry replaces them.
    func monthlyData(for year: Int) -> [MonthlyBalance] {
        let yearItems = (assets + liabilities).filter { $0.year == year }
        let monthsWithEntries = Set(yearItems.map(\.month))
        return (1...12).map { month in
            let entries = yearItems.latestEntries(throughMonth: month)
            return MonthlyBalance(
                month: month,
                assets: entries.filter { $0.itemType == "asset" }.reduce(0) { $0 + $1.amount },
                liabilities: entries.filter { $0.itemType == "liability" }.reduce(0) { $0 + $1.amount },
                hasEntries: monthsWithEntries.contains(month)
            )
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
        let items = latestEntries(in: year).filter { $0.itemType == type.rawValue }

        var categories: [String: Int] = [:]
        for item in items {
            categories[item.category, default: 0] += item.amount
        }

        return categories.map { ($0.key, $0.value) }.sorted { $0.1 > $1.1 }
    }

    // MARK: - CRUD: Years

    /// Items recorded for the whole year, for Update Balances. Accounts that also have monthly
    /// entries are left out: their latest monthly entry is their balance, so changing the
    /// yearly amount wouldn't change anything.
    func yearlyItems(in year: Int) -> [FinancialItem] {
        latestEntries(in: year).filter { $0.month == 0 }
    }

    /// The closest earlier year that has items, which a new year can start from.
    func carryForwardSource(for year: Int) -> Int? {
        // `yearsWithData` is sorted newest first, so the first match is the closest earlier year.
        yearsWithData.first { $0 < year }
    }

    /// Adds a year, optionally starting it with each of another year's accounts at its latest
    /// amount, as yearly items, so they don't have to be typed in again.
    func addYear(_ year: Int, copyingItemsFrom sourceYear: Int? = nil) {
        guard !years.contains(year) else { return }
        modelContext.insert(TrackedYear(year: year))
        if let sourceYear {
            for item in latestEntries(in: sourceYear) {
                let copy = FinancialItem(
                    name: item.name,
                    amount: item.amount,
                    year: year,
                    category: item.category,
                    itemType: item.itemType
                )
                // The amount was last checked when the original was, not today.
                copy.updatedAt = item.updatedAt
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

    /// Saves the amounts confirmed in Update Balances in one go. An amount confirmed as the
    /// same still counts as checked today, so Home stops suggesting an update.
    func updateAmounts(_ newAmounts: [UUID: Int], of items: [FinancialItem]) {
        let now = Date.now
        for item in items {
            guard let amount = newAmounts[item.id] else { continue }
            item.amount = amount
            item.updatedAt = now
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
        // A goal that's already met when it's set is marked reached, without a celebration.
        if goalProgress(for: goal) >= 1 {
            goal.isAchieved = true
            goal.achievedDate = .now
            goal.isCelebrated = true
        }
        modelContext.insert(goal)
        didMutate()
    }

    /// Marks goals reached once their progress hits 100%. A reached goal stays reached even
    /// if the numbers drop later.
    private func updateAchievedGoals() {
        for goal in goals where !goal.isAchieved && goalProgress(for: goal) >= 1 {
            goal.isAchieved = true
            goal.achievedDate = .now
        }
    }

    /// A goal that was reached and hasn't had its celebration yet.
    var goalToCelebrate: Goal? {
        goals.first { $0.isAchieved && !$0.isCelebrated }
    }

    func markCelebrated(_ goal: Goal) {
        goal.isCelebrated = true
    }

    /// How a goal is pacing toward its target date, judged from the last few years with
    /// data. Nil when there's no data yet.
    func goalPace(for goal: Goal, now: Date = .now) -> GoalPace? {
        GoalCoach.pace(of: goal, history: goalHistory, now: now)
    }

    /// Totals for each year with data up to the latest one, oldest first: what goals are
    /// measured against.
    private var goalHistory: [YearTotals] {
        guard let year = latestYearWithData else { return [] }
        return yearsWithData.filter { $0 <= year }.sorted().map { yearTotals($0) }
    }

    private func yearTotals(_ year: Int) -> YearTotals {
        let data = getYearData(for: year)
        return YearTotals(year: year, assets: data.assets, liabilities: data.liabilities)
    }

    /// The goal Home features: the unreached goal with the nearest target date.
    var featuredGoal: Goal? {
        GoalCoach.featuredGoal(in: goals)
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
        return GoalCoach.progress(of: goal, current: yearTotals(year))
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

    /// Milestones were net worth targets without a date. They're goals now: each becomes a
    /// net worth goal with no target date and the milestone is removed. Ones already passed
    /// are marked reached without a celebration.
    private func moveMilestonesToGoals() {
        guard let milestones = try? modelContext.fetch(FetchDescriptor<Milestone>()), !milestones.isEmpty else {
            return
        }
        for milestone in milestones {
            let goal = Goal(title: milestone.title, targetAmount: milestone.targetNetWorth, targetDate: .distantFuture)
            goal.hasTargetDate = false
            goal.createdAt = milestone.createdAt
            if milestone.isAchieved || goalProgress(for: goal) >= 1 {
                goal.isAchieved = true
                goal.achievedDate = milestone.achievedDate ?? .now
                goal.isCelebrated = true
            }
            modelContext.insert(goal)
            modelContext.delete(milestone)
        }
        try? modelContext.save()
    }

    /// Debt goals made before `startAmount` existed get it filled in once from the data, so
    /// their starting point stays fixed when that year's numbers are edited later.
    private func backfillDebtGoalStarts() {
        for goal in goals where goal.goalType == "liability" && goal.startAmount == nil {
            goal.startAmount = debtWhenSet(goal)
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

    /// The entries behind each year's balances as plain values for `InsightsEngine`.
    var insightItems: [InsightItem] {
        Dictionary(grouping: assets + liabilities, by: \.year).values
            .flatMap { $0.latestEntries() }
            .map { item in
                InsightItem(
                    name: item.name,
                    category: item.category,
                    isAsset: item.itemType == "asset",
                    amount: item.amount,
                    year: item.year
                )
            }
    }

    // MARK: - Home

    /// Balances not checked for this long get an "Update balances" suggestion on Home.
    static let balanceCheckInterval: TimeInterval = 30 * 24 * 60 * 60

    /// The latest net worth, its change since the previous year with data, and the trend.
    var netWorthSummary: NetWorthSummary? {
        guard let year = latestYearWithData else { return nil }
        return NetWorthSummary(
            year: year,
            netWorth: getYearData(for: year).netWorth,
            change: InsightsEngine.yearChange(for: year, items: insightItems),
            trend: yearsWithData.filter { $0 <= year }.sorted().map { getYearData(for: $0) },
            lastUpdated: latestEntries(in: year).map(\.updatedAt).max()
        )
    }

    /// The most useful thing to do next, or nil when everything is up to date. `strategy` is
    /// the debt planner's, so the suggested debt matches the plan.
    func nextStep(strategy: PayoffStrategy, now: Date = .now) -> NextStep? {
        let thisYear = Calendar.current.component(.year, from: now)
        guard !years.isEmpty else { return .addFirstYear }
        guard years.contains(thisYear) else {
            return .startYear(thisYear, from: carryForwardSource(for: thisYear))
        }
        if latestEntries(in: thisYear).isEmpty {
            return .addAccounts(year: thisYear)
        }
        // The oldest balance Update Balances can refresh, so one forgotten account still counts.
        if let oldest = yearlyItems(in: thisYear).map(\.updatedAt).min(),
           now.timeIntervalSince(oldest) > Self.balanceCheckInterval {
            return .updateBalances(year: thisYear, lastUpdated: oldest)
        }
        if goals.isEmpty {
            return .setFirstGoal
        }
        let debts = plannerDebts
        if let first = DebtPlanner.payoffOrder(of: debts, strategy: strategy).first {
            return .payOffNext(debtName: debts[first].name)
        }
        return nil
    }

    /// What the monthly reminder opens: Update Balances for this year, or whatever has to
    /// happen first when this year isn't set up yet.
    func checkInStep(now: Date = .now) -> NextStep {
        let thisYear = Calendar.current.component(.year, from: now)
        guard !years.isEmpty else { return .addFirstYear }
        guard years.contains(thisYear) else {
            return .startYear(thisYear, from: carryForwardSource(for: thisYear))
        }
        guard let oldest = yearlyItems(in: thisYear).map(\.updatedAt).min() else {
            return .addAccounts(year: thisYear)
        }
        return .updateBalances(year: thisYear, lastUpdated: oldest)
    }

    // MARK: - Quick Start

    /// Starts tracking `year` with the accounts picked in quick-start setup. Accounts without
    /// an amount are skipped.
    func startTracking(year: Int, amounts: [StarterAccount: Int]) {
        addYear(year)
        for (account, amount) in amounts where amount > 0 {
            modelContext.insert(FinancialItem(
                name: account.name,
                amount: amount,
                year: year,
                category: account.category,
                itemType: account.itemType
            ))
        }
        didMutate()
    }

    // MARK: - Future You

    /// Net worth projected 5, 10 and 20 years past the latest year with data, at the average
    /// yearly change so far. Nil with fewer than two years of data.
    var netWorthProjection: NetWorthProjection? {
        let thisYear = Calendar.current.component(.year, from: .now)
        return InsightsEngine.overall(items: insightItems, throughYear: thisYear).map { NetWorthProjection($0) }
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

    /// Every year's entries in one file, with a Year column, oldest year first. Import reads
    /// it back.
    func generateAllYearsCSV() -> String {
        var csv = "Year,Name,Amount,Category,Type,Month\n"
        let allItems = (assets + liabilities).sorted {
            ($0.year, $0.name, $0.month) < ($1.year, $1.name, $1.month)
        }
        for item in allItems {
            let fields = [String(item.year), item.name, String(item.amount), item.category, item.itemType, String(item.month)]
            csv += fields.map(csvField).joined(separator: ",") + "\n"
        }
        return csv
    }

    /// Writes CSV text to a temporary file, so it's shared as a .csv file rather than text.
    func csvFile(named fileName: String, contents: String) -> URL? {
        let url = URL.temporaryDirectory.appending(path: fileName)
        do {
            try contents.write(to: url, atomically: true, encoding: .utf8)
            return url
        } catch {
            return nil
        }
    }

    // MARK: - Import

    /// What importing `entries` would do. `year` is used for entries from a file without a
    /// Year column.
    func importSummary(of entries: [ImportedEntry], year: Int) -> ImportSummary {
        let categories = resolveCategories(for: entries)
        let matches = existingMatches(for: entries, categories: categories.names, year: year)
        let updated = matches.compactMap { $0 }.count
        let entryYears = Set(entries.map { $0.year ?? year })
        return ImportSummary(
            added: entries.count - updated,
            updated: updated,
            newYears: entryYears.subtracting(years).sorted(),
            newCategories: categories.new
        )
    }

    /// Adds the entries, along with any years and categories they need. An entry for an item
    /// that's already there (same name, category, type, year and month) updates its amount
    /// instead, so importing the same file twice doesn't count anything twice.
    @discardableResult
    func importEntries(_ entries: [ImportedEntry], year: Int) -> ImportSummary {
        let summary = importSummary(of: entries, year: year)
        let categories = resolveCategories(for: entries)
        let matches = existingMatches(for: entries, categories: categories.names, year: year)

        for newYear in summary.newYears {
            modelContext.insert(TrackedYear(year: newYear))
        }
        for category in categories.new {
            modelContext.insert(CustomCategory(name: category.name, itemType: category.isAsset ? "asset" : "liability"))
        }
        let now = Date.now
        for (index, entry) in entries.enumerated() {
            if let match = matches[index] {
                match.amount = entry.amount
                match.updatedAt = now
            } else {
                modelContext.insert(FinancialItem(
                    name: entry.name,
                    amount: entry.amount,
                    year: entry.year ?? year,
                    month: entry.month,
                    category: categories.names[index],
                    itemType: entry.isAsset ? "asset" : "liability"
                ))
            }
        }
        didMutate()
        return summary
    }

    /// Each entry's category as the app spells it, matched without regard to case; blank
    /// means Other. Categories the app doesn't have yet are listed once as new.
    private func resolveCategories(for entries: [ImportedEntry]) -> (names: [String], new: [ImportSummary.NewCategory]) {
        var known: [String: String] = [:]
        for type in [ItemType.asset, .liability] {
            for name in allCategoryNames(for: type) {
                known["\(type.rawValue)|\(name.lowercased())"] = name
            }
        }

        var newCategories: [ImportSummary.NewCategory] = []
        var names: [String] = []
        for entry in entries {
            guard !entry.category.isEmpty else {
                names.append("Other")
                continue
            }
            let key = "\(entry.isAsset ? "asset" : "liability")|\(entry.category.lowercased())"
            if let name = known[key] {
                names.append(name)
            } else {
                known[key] = entry.category
                newCategories.append(ImportSummary.NewCategory(name: entry.category, isAsset: entry.isAsset))
                names.append(entry.category)
            }
        }
        return (names, newCategories)
    }

    /// The existing item each entry updates, or nil for an entry that's added. Each item is
    /// matched at most once, so a file listing the same account twice in a year (two items
    /// that add up) brings both back.
    private func existingMatches(for entries: [ImportedEntry], categories: [String], year: Int) -> [FinancialItem?] {
        var unmatched = Dictionary(grouping: assets + liabilities) { ImportKey($0) }
        var matches: [FinancialItem?] = []
        for (index, entry) in entries.enumerated() {
            let key = ImportKey(
                year: entry.year ?? year,
                month: entry.month,
                name: entry.name,
                category: categories[index],
                itemType: entry.isAsset ? "asset" : "liability"
            )
            if var candidates = unmatched[key], !candidates.isEmpty {
                matches.append(candidates.removeFirst())
                unmatched[key] = candidates
            } else {
                matches.append(nil)
            }
        }
        return matches
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

/// What makes an imported entry the same as an existing item.
private struct ImportKey: Hashable {
    let year: Int
    let month: Int
    let name: String
    let category: String
    let itemType: String

    init(year: Int, month: Int, name: String, category: String, itemType: String) {
        self.year = year
        self.month = month
        self.name = name
        self.category = category
        self.itemType = itemType
    }

    init(_ item: FinancialItem) {
        self.init(year: item.year, month: item.month, name: item.name, category: item.category, itemType: item.itemType)
    }
}

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
