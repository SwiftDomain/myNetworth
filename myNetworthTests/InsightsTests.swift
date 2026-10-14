//
//  InsightsTests.swift
//  myNetworthTests
//
//  Feature 5: "what changed" insights and the on-device summary's number check.
//

import Foundation
import SwiftData
import Testing
@testable import myNetworth

@MainActor
@Suite("What changed insights")
struct InsightsTests {

    private let money: (Int) -> String = { "$\($0)" }

    private func item(_ name: String, _ category: String, _ amount: Int, year: Int, asset: Bool = true) -> InsightItem {
        InsightItem(name: name, category: category, isAsset: asset, amount: amount, year: year)
    }

    /// 2023: net worth $17,000. 2024: nothing entered. 2025: net worth $29,000, with the
    /// Visa paid off, crypto bought, savings down and investments up.
    private var sample: [InsightItem] {
        [
            item("Savings", "Cash", 10_000, year: 2023),
            item("Brokerage", "Investments", 20_000, year: 2023),
            item("Visa", "Credit Card", 5_000, year: 2023, asset: false),
            item("Car loan", "Auto Loan", 8_000, year: 2023, asset: false),

            item("Savings", "Cash", 8_000, year: 2025),
            item("Brokerage", "Investments", 26_000, year: 2025),
            item("Crypto", "Crypto", 1_000, year: 2025),
            item("Car loan", "Auto Loan", 6_000, year: 2025, asset: false),
        ]
    }

    // MARK: Year Over Year

    @Test("Compares with the closest earlier year that has data")
    func comparesWithPreviousYearWithData() throws {
        let change = try #require(InsightsEngine.yearChange(for: 2025, items: sample))

        #expect(change.previousYear == 2023)
        #expect(change.previousNetWorth == 17_000)
        #expect(change.netWorth == 29_000)
        #expect(change.change == 12_000)
        #expect(change.assetsChange == 5_000)
        #expect(change.liabilitiesChange == -7_000)
        #expect(abs((change.percentChange ?? 0) - 12_000.0 / 17_000.0 * 100) < 0.0001)
    }

    @Test("There's nothing to compare for the first year or a year without data")
    func noComparison() {
        #expect(InsightsEngine.yearChange(for: 2023, items: sample)?.year == nil)
        #expect(InsightsEngine.yearChange(for: 2024, items: sample)?.year == nil)
    }

    @Test("Sorts items into gains, drops, new and paid off")
    func moversAndChanges() throws {
        let change = try #require(InsightsEngine.yearChange(for: 2025, items: sample))

        #expect(change.gains.map(\.name) == ["Brokerage", "Car loan"])
        #expect(change.gains.map(\.netWorthEffect) == [6_000, 2_000])
        #expect(change.drops.map(\.name) == ["Savings"])
        #expect(change.drops.map(\.netWorthEffect) == [-2_000])
        #expect(change.added.map(\.name) == ["Crypto"])
        #expect(change.removed.map(\.name) == ["Visa"])
        #expect(change.topCategory?.name == "Investments")
        #expect(change.topCategory?.netWorthEffect == 6_000)
    }

    @Test("Only the biggest three gains are listed")
    func moverCount() throws {
        let items = (1...5).flatMap { index in
            [
                item("Account \(index)", "Cash", 1_000, year: 2024),
                item("Account \(index)", "Cash", 1_000 + index * 100, year: 2025),
            ]
        }
        let change = try #require(InsightsEngine.yearChange(for: 2025, items: items))

        #expect(change.gains.map(\.name) == ["Account 5", "Account 4", "Account 3"])
    }

    @Test("No percentage when the previous net worth was zero")
    func noPercentFromZero() throws {
        let items = [
            item("Savings", "Cash", 5_000, year: 2024),
            item("Visa", "Credit Card", 5_000, year: 2024, asset: false),
            item("Savings", "Cash", 6_000, year: 2025),
        ]
        let change = try #require(InsightsEngine.yearChange(for: 2025, items: items))

        #expect(change.percentChange == nil)
        #expect(!InsightsEngine.templateSummary(for: change, money: money).contains("%"))
    }

    // MARK: Across All Years

    @Test("Finds the best and worst years across all years with data")
    func overall() throws {
        let items = [
            item("Savings", "Cash", 10_000, year: 2021),
            item("Savings", "Cash", 25_000, year: 2022),
            item("Savings", "Cash", 20_000, year: 2023),
            item("Savings", "Cash", 30_000, year: 2024),
            item("Savings", "Cash", 90_000, year: 2030), // a planning year, left out
        ]
        let insights = try #require(InsightsEngine.overall(items: items, throughYear: 2024))

        #expect(insights.firstYear == 2021)
        #expect(insights.lastYear == 2024)
        #expect(insights.totalChange == 20_000)
        #expect(insights.averageYearlyChange == 6_666)
        #expect(insights.bestStep.year == 2022)
        #expect(insights.bestStep.change == 15_000)
        #expect(insights.worstStep.year == 2023)
        #expect(insights.worstStep.change == -5_000)
        #expect(insights.categoryDrivers.map(\.name) == ["Cash"])
    }

    @Test("Needs at least two years")
    func overallNeedsTwoYears() {
        let items = [item("Savings", "Cash", 10_000, year: 2024)]
        #expect(InsightsEngine.overall(items: items, throughYear: 2024)?.firstYear == nil)
    }

    // MARK: Text

    @Test("Signed amounts")
    func signedAmounts() {
        #expect(InsightsEngine.signed(1_200, money: money) == "+$1200")
        #expect(InsightsEngine.signed(-300, money: money) == "−$300")
        #expect(InsightsEngine.signed(0, money: money) == "$0")
    }

    @Test("The plain summary describes the change, the top category and paid-off debts")
    func templateSummary() throws {
        let change = try #require(InsightsEngine.yearChange(for: 2025, items: sample))
        let summary = InsightsEngine.templateSummary(for: change, money: money)

        #expect(summary.hasPrefix("Your net worth rose $12000 ("))
        #expect(summary.contains("since 2023, to $29000."))
        #expect(summary.contains("Investments made the biggest difference (+$6000)."))
        #expect(summary.hasSuffix("You paid off Visa."))
    }

    @Test("The facts for the on-device model list every change")
    func facts() throws {
        let change = try #require(InsightsEngine.yearChange(for: 2025, items: sample))
        let facts = InsightsEngine.facts(for: change, money: money)

        #expect(facts.contains("Net worth was $17000 in 2023 and $29000 in 2025, so it went up by $12000."))
        #expect(facts.contains("Total assets went up by $5000. Total debts went down by $7000."))
        #expect(facts.contains("Biggest increases to net worth: Brokerage (+$6000); Car loan (+$2000)."))
        #expect(facts.contains("Biggest decreases to net worth: Savings (−$2000)."))
        #expect(facts.contains("Debts paid off: Visa."))
        #expect(facts.contains("New assets: Crypto ($1000)."))
    }

    // MARK: Number Check

    @Test("Finds the numbers written in a sentence")
    func findsNumbers() {
        let numbers = InsightsEngine.numbers(in: "Net worth rose $12,400 (6.2%) since 2024.")
        #expect(numbers == ["12,400", "6.2", "2024"])
    }

    @Test("Rejects a summary with a number that isn't in the facts")
    func numberGuard() {
        let facts = "Net worth was $17,000 in 2023 and $29,000 in 2025, so it went up by $12,000."

        #expect(InsightsEngine.usesOnlyKnownNumbers("Your net worth grew by $12,000 since 2023.", facts: facts))
        #expect(InsightsEngine.usesOnlyKnownNumbers("Nice work this year!", facts: facts))
        #expect(!InsightsEngine.usesOnlyKnownNumbers("Your net worth grew by $13,000.", facts: facts))
        #expect(!InsightsEngine.usesOnlyKnownNumbers("That's a 70% increase.", facts: facts))
    }

    @Test("The plain summary passes the same number check as the on-device one")
    func templatePassesGuard() throws {
        let change = try #require(InsightsEngine.yearChange(for: 2025, items: sample))
        let facts = InsightsEngine.facts(for: change, money: money)
        let summary = InsightsEngine.templateSummary(for: change, money: money)

        #expect(InsightsEngine.usesOnlyKnownNumbers(summary, facts: facts))
    }

    @Test("The on-device summary is either unavailable or only uses numbers from the facts", .timeLimit(.minutes(1)))
    func narratorUsesKnownNumbers() async throws {
        let change = try #require(InsightsEngine.yearChange(for: 2025, items: sample))
        let facts = InsightsEngine.facts(for: change, money: money)

        if let summary = await InsightNarrator.summary(for: facts) {
            #expect(InsightsEngine.usesOnlyKnownNumbers(summary, facts: facts))
        }
    }

    // MARK: View Model

    @Test("The view model hands every item to the insights engine")
    func insightItemsFromViewModel() throws {
        let store = try TestStore()
        store.viewModel.addYear(2025)
        store.addItem("Savings", 5_000, year: 2025, category: "Cash", asset: true)
        store.addItem("Visa", 1_200, year: 2025, category: "Credit Card", asset: false)

        let items = store.viewModel.insightItems.sorted { $0.name < $1.name }

        #expect(items.map(\.name) == ["Savings", "Visa"])
        #expect(items.map(\.isAsset) == [true, false])
        #expect(items.map(\.amount) == [5_000, 1_200])
        #expect(InsightsEngine.netWorth(of: items, in: 2025) == 3_800)
    }
}
