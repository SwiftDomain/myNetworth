//
//  HomeTests.swift
//  myNetworthTests
//
//  Feature 2: the net worth card and the Next step suggestion on Home.
//

import Foundation
import SwiftData
import Testing
@testable import myNetworth

@MainActor
@Suite("Home")
struct HomeTests {

    private let twoMonthsAgo = Date.now.addingTimeInterval(-60 * 24 * 60 * 60)

    private func goal() -> Goal {
        Goal(title: "Emergency fund", targetAmount: 20_000, targetDate: .now, goalType: "asset")
    }

    // MARK: Net Worth Card

    @Test("No net worth card without data")
    func noSummaryWithoutData() throws {
        let store = try TestStore()
        store.viewModel.addYear(thisYear)

        #expect(store.viewModel.netWorthSummary?.year == nil)
    }

    @Test("Shows the latest net worth, its change and the trend")
    func netWorthSummary() throws {
        let store = try TestStore()
        let viewModel = store.viewModel
        for year in [thisYear - 2, thisYear - 1, thisYear, thisYear + 1] {
            viewModel.addYear(year)
        }
        store.addItem("Savings", 10_000, year: thisYear - 2, category: "Cash", asset: true)
        store.addItem("Savings", 15_000, year: thisYear - 1, category: "Cash", asset: true)
        store.addItem("Visa", 3_000, year: thisYear - 1, category: "Credit Card", asset: false)
        // This year is tracked but empty, and next year is a plan, so last year is the latest.
        store.addItem("Savings", 90_000, year: thisYear + 1, category: "Cash", asset: true)

        let summary = try #require(viewModel.netWorthSummary)

        #expect(summary.year == thisYear - 1)
        #expect(summary.netWorth == 12_000)
        #expect(summary.change?.previousYear == thisYear - 2)
        #expect(summary.change?.change == 2_000)
        #expect(summary.trend.map(\.year) == [thisYear - 2, thisYear - 1])
        #expect(summary.trend.map(\.netWorth) == [10_000, 12_000])
        #expect(summary.lastUpdated != nil)
    }

    @Test("A single year has no change to show")
    func singleYearSummary() throws {
        let store = try TestStore()
        store.viewModel.addYear(thisYear)
        store.addItem("Savings", 10_000, year: thisYear, category: "Cash", asset: true)

        let summary = try #require(store.viewModel.netWorthSummary)

        #expect(summary.change?.year == nil)
        #expect(summary.trend.count == 1)
    }

    // MARK: Next Step

    @Test("Start by adding a year")
    func addFirstYear() throws {
        let store = try TestStore()
        #expect(store.viewModel.nextStep(strategy: .avalanche) == NextStep.addFirstYear)
    }

    @Test("Start this year from last year's balances")
    func startThisYear() throws {
        let store = try TestStore()
        store.viewModel.addYear(thisYear - 1)
        store.addItem("Savings", 10_000, year: thisYear - 1, category: "Cash", asset: true)

        #expect(store.viewModel.nextStep(strategy: .avalanche) == NextStep.startYear(thisYear, from: thisYear - 1))
    }

    @Test("Fill in this year when it's empty")
    func addAccounts() throws {
        let store = try TestStore()
        store.viewModel.addYear(thisYear)

        #expect(store.viewModel.nextStep(strategy: .avalanche) == NextStep.addAccounts(year: thisYear))
    }

    @Test("Update balances that haven't been checked for over a month")
    func updateStaleBalances() throws {
        let store = try TestStore()
        let viewModel = store.viewModel
        viewModel.addYear(thisYear)
        let savings = store.addItem("Savings", 10_000, year: thisYear, category: "Cash", asset: true)
        store.addItem("Visa", 1_000, year: thisYear, category: "Credit Card", asset: false)
        // One forgotten account is enough, even when another was updated today.
        savings.updatedAt = twoMonthsAgo

        #expect(viewModel.nextStep(strategy: .avalanche) == NextStep.updateBalances(year: thisYear, lastUpdated: twoMonthsAgo))
    }

    @Test("A check-in clears the update suggestion, even when nothing changed")
    func checkInClearsUpdate() throws {
        let store = try TestStore()
        let viewModel = store.viewModel
        viewModel.addYear(thisYear)
        viewModel.addGoal(goal())
        let savings = store.addItem("Savings", 10_000, year: thisYear, category: "Cash", asset: true)
        savings.updatedAt = twoMonthsAgo

        let items = viewModel.yearlyItems(in: thisYear)
        viewModel.updateAmounts([savings.id: 10_000], of: items)

        #expect(viewModel.nextStep(strategy: .avalanche) == nil)
    }

    @Test("Accounts tracked by month don't ask for Update Balances")
    func monthlyAccountsDontAskForUpdate() throws {
        let store = try TestStore()
        let viewModel = store.viewModel
        viewModel.addYear(thisYear)
        viewModel.addGoal(goal())
        let savings = store.addItem("Savings", 10_000, year: thisYear, category: "Cash", asset: true)
        let monthly = store.addItem("Savings", 11_000, year: thisYear, category: "Cash", asset: true, month: 1)
        savings.updatedAt = twoMonthsAgo
        monthly.updatedAt = twoMonthsAgo

        #expect(viewModel.nextStep(strategy: .avalanche) == nil)
    }

    @Test("Set a first goal once the balances are current")
    func setFirstGoal() throws {
        let store = try TestStore()
        store.viewModel.addYear(thisYear)
        store.addItem("Savings", 10_000, year: thisYear, category: "Cash", asset: true)

        #expect(store.viewModel.nextStep(strategy: .avalanche) == NextStep.setFirstGoal)
    }

    @Test("Suggest the debt the payoff plan targets first")
    func payOffNext() throws {
        let store = try TestStore()
        let viewModel = store.viewModel
        viewModel.addYear(thisYear)
        viewModel.addGoal(goal())
        let car = store.addItem("Car loan", 9_000, year: thisYear, category: "Auto Loan", asset: false)
        let visa = store.addItem("Visa", 3_000, year: thisYear, category: "Credit Card", asset: false)
        viewModel.updateTerms(for: car, annualRate: 29.9, minimumPayment: 250, isIncluded: true)
        viewModel.updateTerms(for: visa, annualRate: 19.9, minimumPayment: 90, isIncluded: true)

        #expect(viewModel.nextStep(strategy: .snowball) == NextStep.payOffNext(debtName: "Visa"))
        #expect(viewModel.nextStep(strategy: .avalanche) == NextStep.payOffNext(debtName: "Car loan"))
    }

    @Test("Nothing to suggest when everything is up to date")
    func allCaughtUp() throws {
        let store = try TestStore()
        store.viewModel.addYear(thisYear)
        store.viewModel.addGoal(goal())
        store.addItem("Savings", 10_000, year: thisYear, category: "Cash", asset: true)

        #expect(store.viewModel.nextStep(strategy: .avalanche) == nil)
    }
}
