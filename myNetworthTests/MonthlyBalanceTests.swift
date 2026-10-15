//
//  MonthlyBalanceTests.swift
//  myNetworthTests
//
//  Monthly entries update an account's balance instead of being added on top of it.
//

import Foundation
import SwiftData
import Testing
@testable import myNetworth

@MainActor
@Suite("Monthly balances")
struct MonthlyBalanceTests {

    @Test("A monthly entry replaces the yearly amount instead of adding to it")
    func monthlyEntryReplacesYearly() throws {
        let store = try TestStore()
        let viewModel = store.viewModel
        viewModel.addYear(2025)
        store.addItem("Savings", 5_000, year: 2025, category: "Cash", asset: true)
        store.addItem("Savings", 5_500, year: 2025, category: "Cash", asset: true, month: 3)
        store.addItem("Savings", 6_000, year: 2025, category: "Cash", asset: true, month: 6)
        store.addItem("Visa", 1_200, year: 2025, category: "Credit Card", asset: false)

        let year = viewModel.getYearData(for: 2025)
        #expect(year.assets == 6_000)
        #expect(year.liabilities == 1_200)
        #expect(year.netWorth == 4_800)
        #expect(year.assetCategoryTotal[.cash] == 6_000)
        #expect(viewModel.getCategoryData(for: .asset, year: 2025).map(\.1) == [6_000])
    }

    @Test("Yearly-only data adds up as before, including two items with the same name")
    func yearlyOnlyUnchanged() throws {
        let store = try TestStore()
        let viewModel = store.viewModel
        viewModel.addYear(2025)
        store.addItem("Savings", 1_000, year: 2025, category: "Cash", asset: true)
        store.addItem("Savings", 2_000, year: 2025, category: "Cash", asset: true)
        store.addItem("Car", 9_000, year: 2025, category: "Vehicle", asset: true)

        #expect(viewModel.getYearData(for: 2025).assets == 12_000)
    }

    @Test("A different category or type is a different account")
    func accountsAreNameCategoryAndType() throws {
        let store = try TestStore()
        let viewModel = store.viewModel
        viewModel.addYear(2025)
        store.addItem("Savings", 1_000, year: 2025, category: "Cash", asset: true)
        store.addItem("Savings", 500, year: 2025, category: "Investments", asset: true, month: 6)
        store.addItem("Savings", 300, year: 2025, category: "Cash", asset: false, month: 6)

        let year = viewModel.getYearData(for: 2025)
        #expect(year.assets == 1_500)
        #expect(year.liabilities == 300)
    }

    @Test("Later months win, and months after the one asked for are ignored")
    func latestEntriesThroughMonth() {
        let items = [
            FinancialItem(name: "Savings", amount: 5_000, year: 2025, category: "Cash", itemType: "asset"),
            FinancialItem(name: "Savings", amount: 5_500, year: 2025, month: 3, category: "Cash", itemType: "asset"),
            FinancialItem(name: "Savings", amount: 6_000, year: 2025, month: 9, category: "Cash", itemType: "asset"),
        ]

        #expect(items.latestEntries().map(\.amount) == [6_000])
        #expect(items.latestEntries(throughMonth: 6).map(\.amount) == [5_500])
        #expect(items.latestEntries(throughMonth: 2).map(\.amount) == [5_000])
    }

    @Test("Each month shows every account at its latest amount so far")
    func monthlyBreakdown() throws {
        let store = try TestStore()
        let viewModel = store.viewModel
        viewModel.addYear(2025)
        store.addItem("House", 300_000, year: 2025, category: "Real Estate", asset: true)
        store.addItem("Savings", 5_000, year: 2025, category: "Cash", asset: true)
        store.addItem("Visa", 1_200, year: 2025, category: "Credit Card", asset: false, month: 3)
        store.addItem("Savings", 6_000, year: 2025, category: "Cash", asset: true, month: 6)

        let months = viewModel.monthlyData(for: 2025)

        #expect(months.map(\.month) == Array(1...12))
        #expect(months.filter(\.hasEntries).map(\.month) == [3, 6])
        // March: the yearly amounts plus the new Visa entry.
        #expect(months[2].assets == 305_000)
        #expect(months[2].liabilities == 1_200)
        // June: Savings is updated and the Visa balance carries over.
        #expect(months[5].assets == 306_000)
        #expect(months[5].netWorth == 304_800)
        // The last month with entries matches the year's totals.
        #expect(months[5].netWorth == viewModel.getYearData(for: 2025).netWorth)
    }

    @Test("Yearly-only data has no months with entries")
    func yearlyOnlyMonths() throws {
        let store = try TestStore()
        store.viewModel.addYear(2025)
        store.addItem("Savings", 5_000, year: 2025, category: "Cash", asset: true)

        #expect(store.viewModel.monthlyData(for: 2025).allSatisfy { !$0.hasEntries })
    }

    @Test("Goals measure against the latest balance")
    func goalsUseLatestBalance() throws {
        let store = try TestStore()
        let viewModel = store.viewModel
        viewModel.addYear(thisYear)
        store.addItem("Savings", 5_000, year: thisYear, category: "Cash", asset: true)
        store.addItem("Savings", 6_000, year: thisYear, category: "Cash", asset: true, month: 9)
        let goal = Goal(title: "Savings", targetAmount: 12_000, targetDate: .now, goalType: "asset")

        #expect(viewModel.goalProgress(for: goal) == 0.5)
    }

    @Test("Insights compare latest balances")
    func insightsUseLatestBalance() throws {
        let store = try TestStore()
        let viewModel = store.viewModel
        viewModel.addYear(2024)
        viewModel.addYear(2025)
        store.addItem("Savings", 5_000, year: 2024, category: "Cash", asset: true)
        store.addItem("Savings", 5_000, year: 2025, category: "Cash", asset: true)
        store.addItem("Savings", 7_000, year: 2025, category: "Cash", asset: true, month: 5)

        let change = try #require(InsightsEngine.yearChange(for: 2025, items: viewModel.insightItems))

        #expect(change.change == 2_000)
        #expect(change.gains.map(\.netWorthEffect) == [2_000])
    }

    @Test("Update Balances leaves out accounts tracked by month")
    func updateBalancesSkipsMonthlyAccounts() throws {
        let store = try TestStore()
        let viewModel = store.viewModel
        viewModel.addYear(2025)
        store.addItem("Savings", 5_000, year: 2025, category: "Cash", asset: true)
        store.addItem("Savings", 6_000, year: 2025, category: "Cash", asset: true, month: 6)
        store.addItem("Visa", 1_200, year: 2025, category: "Credit Card", asset: false)

        #expect(viewModel.yearlyItems(in: 2025).map(\.name) == ["Visa"])
    }

    @Test("A debt updated by month is planned once, at its latest balance")
    func debtUpdatedByMonth() throws {
        let store = try TestStore()
        let viewModel = store.viewModel
        viewModel.addYear(thisYear)
        store.addItem("Visa", 3_000, year: thisYear, category: "Credit Card", asset: false)
        store.addItem("Visa", 2_500, year: thisYear, category: "Credit Card", asset: false, month: 6)

        #expect(viewModel.currentDebts.map(\.amount) == [2_500])
        #expect(viewModel.plannerDebts.map(\.balance) == [2_500])
    }

    @Test("The CSV export still lists every entry")
    func csvKeepsEveryEntry() throws {
        let store = try TestStore()
        store.addItem("Savings", 5_000, year: 2025, category: "Cash", asset: true)
        store.addItem("Savings", 6_000, year: 2025, category: "Cash", asset: true, month: 6)

        let rows = store.viewModel.generateCSV(for: 2025).split(separator: "\n")
        #expect(rows.count == 3)
    }
}
