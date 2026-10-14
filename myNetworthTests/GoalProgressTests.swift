//
//  GoalProgressTests.swift
//  myNetworthTests
//
//  Feature 3: goal progress.
//

import Foundation
import SwiftData
import Testing
@testable import myNetworth

@MainActor
@Suite("Goal progress")
struct GoalProgressTests {

    private func goal(_ type: String, target: Int) -> Goal {
        Goal(title: "Goal", targetAmount: target, targetDate: .now, goalType: type)
    }

    @Test("No data means no progress")
    func noData() throws {
        let store = try TestStore()
        #expect(store.viewModel.latestYearWithData == nil)
        #expect(store.viewModel.goalProgress(for: goal("netWorth", target: 1_000)) == 0)
    }

    @Test("Net worth and asset goals measure against the latest year with data")
    func netWorthAndAssetGoals() throws {
        let store = try TestStore()
        let viewModel = store.viewModel
        viewModel.addYear(thisYear - 1)
        store.addItem("Savings", 30_000, year: thisYear - 1, category: "Cash", asset: true)
        store.addItem("Visa", 5_000, year: thisYear - 1, category: "Credit Card", asset: false)
        // This year is tracked but not filled in yet, so last year's numbers still count.
        viewModel.addYear(thisYear)

        #expect(viewModel.latestYearWithData == thisYear - 1)
        #expect(viewModel.goalProgress(for: goal("netWorth", target: 50_000)) == 0.5)
        #expect(viewModel.goalProgress(for: goal("asset", target: 60_000)) == 0.5)
        // Going past the target caps at 100%.
        #expect(viewModel.goalProgress(for: goal("netWorth", target: 20_000)) == 1)
        #expect(viewModel.goalProgress(for: goal("netWorth", target: 0)) == 0)
    }

    @Test("Future planning years don't count as the current numbers")
    func futureYearsIgnored() throws {
        let store = try TestStore()
        let viewModel = store.viewModel
        viewModel.addYear(thisYear - 1)
        viewModel.addYear(thisYear + 1)
        store.addItem("Savings", 10_000, year: thisYear - 1, category: "Cash", asset: true)
        store.addItem("Savings", 90_000, year: thisYear + 1, category: "Cash", asset: true)

        #expect(viewModel.latestYearWithData == thisYear - 1)
        #expect(viewModel.goalProgress(for: goal("asset", target: 20_000)) == 0.5)
    }

    @Test("A negative net worth shows no progress instead of going below zero")
    func negativeNetWorth() throws {
        let store = try TestStore()
        let viewModel = store.viewModel
        viewModel.addYear(thisYear)
        store.addItem("Savings", 1_000, year: thisYear, category: "Cash", asset: true)
        store.addItem("Student loan", 6_000, year: thisYear, category: "Student Loan", asset: false)

        #expect(viewModel.goalProgress(for: goal("netWorth", target: 10_000)) == 0)
    }

    @Test("Debt goals count down from the debt owed when the goal was set")
    func debtGoalCountsDown() throws {
        let store = try TestStore()
        let viewModel = store.viewModel
        viewModel.addYear(thisYear - 1)
        store.addItem("Visa", 20_000, year: thisYear - 1, category: "Credit Card", asset: false)

        let payDown = goal("liability", target: 5_000)
        viewModel.addGoal(payDown)
        #expect(payDown.startAmount == 20_000)
        #expect(viewModel.goalProgress(for: payDown) == 0)

        viewModel.addYear(thisYear)
        let visa = store.addItem("Visa", 12_500, year: thisYear, category: "Credit Card", asset: false)
        #expect(viewModel.goalProgress(for: payDown) == 0.5)

        viewModel.updateItem(visa, name: "Visa", amount: 5_000, category: "Credit Card", month: 0)
        #expect(viewModel.goalProgress(for: payDown) == 1)

        // Owing more than when the goal was set is no progress, not "complete".
        viewModel.updateItem(visa, name: "Visa", amount: 25_000, category: "Credit Card", month: 0)
        #expect(viewModel.goalProgress(for: payDown) == 0)
    }

    @Test("A debt goal that's already met when it's set shows as reached")
    func debtGoalAlreadyMet() throws {
        let store = try TestStore()
        let viewModel = store.viewModel
        viewModel.addYear(thisYear)
        store.addItem("Visa", 3_000, year: thisYear, category: "Credit Card", asset: false)

        let payDown = goal("liability", target: 5_000)
        viewModel.addGoal(payDown)

        #expect(payDown.startAmount == 3_000)
        #expect(viewModel.goalProgress(for: payDown) == 1)
    }

    @Test("Only debt goals record a starting amount")
    func otherGoalsHaveNoStart() throws {
        let store = try TestStore()
        let viewModel = store.viewModel
        viewModel.addYear(thisYear)
        store.addItem("Visa", 3_000, year: thisYear, category: "Credit Card", asset: false)

        let netWorthGoal = goal("netWorth", target: 100_000)
        viewModel.addGoal(netWorthGoal)

        #expect(netWorthGoal.startAmount == nil)
        #expect(viewModel.goals.count == 1)
    }

    @Test("Debt goals saved before starting amounts existed get one at launch")
    func backfillsOldDebtGoals() throws {
        let store = try TestStore()
        store.viewModel.addYear(thisYear - 1)
        store.addItem("Loan", 8_000, year: thisYear - 1, category: "Student Loan", asset: false)
        // Inserted directly, like a goal saved by an older version of the app.
        let oldGoal = goal("liability", target: 0)
        store.context.insert(oldGoal)
        #expect(oldGoal.startAmount == nil)

        let relaunched = NetWorthViewModel(modelContext: store.context)

        #expect(oldGoal.startAmount == 8_000)
        #expect(relaunched.goalProgress(for: oldGoal) == 0)
    }
}
