//
//  GoalWidgetTests.swift
//  myNetworthTests
//
//  The Top Goal widget: which goal it shows, and that its numbers match the app's.
//

import Foundation
import SwiftData
import Testing
@testable import myNetworth

@MainActor
@Suite("Goal widget")
struct GoalWidgetTests {

    private let now = Date.now

    private func months(_ count: Int) -> Date {
        Calendar.current.date(byAdding: .month, value: count, to: now) ?? now
    }

    @Test("Features the unreached goal with the nearest date, with undated goals last")
    func featuredGoal() {
        let later = Goal(title: "House", targetAmount: 100_000, targetDate: months(36))
        let sooner = Goal(title: "Emergency fund", targetAmount: 10_000, targetDate: months(6), goalType: "asset")
        let undated = Goal(title: "Someday", targetAmount: 1_000_000, targetDate: .distantFuture)
        undated.hasTargetDate = false
        let reached = Goal(title: "Done", targetAmount: 1, targetDate: months(1))
        reached.isAchieved = true

        #expect(GoalCoach.featuredGoal(in: [undated, later, reached, sooner])?.title == "Emergency fund")
        #expect(GoalCoach.featuredGoal(in: [undated, later])?.title == "House")
        #expect(GoalCoach.featuredGoal(in: [undated])?.title == "Someday")
        #expect(GoalCoach.featuredGoal(in: [reached])?.title == nil)
    }

    @Test("Shows the same progress and pace as the app")
    func matchesApp() throws {
        let store = try TestStore()
        let viewModel = store.viewModel
        viewModel.addYear(thisYear - 1)
        viewModel.addYear(thisYear)
        store.addItem("Savings", 30_000, year: thisYear - 1, category: "Cash", asset: true)
        store.addItem("Savings", 42_000, year: thisYear, category: "Cash", asset: true)
        let goal = Goal(title: "Savings", targetAmount: 60_000, targetDate: months(24), goalType: "asset")
        viewModel.addGoal(goal)
        #expect(viewModel.featuredGoal?.id == goal.id)

        let items = viewModel.assets + viewModel.liabilities
        let snapshot = try #require(GoalSnapshot.make(goals: viewModel.goals, items: items, now: now))

        #expect(snapshot.title == "Savings")
        #expect(snapshot.currentAmount == 42_000)
        #expect(snapshot.progress == viewModel.goalProgress(for: goal))
        #expect(snapshot.pace == viewModel.goalPace(for: goal, now: now))
        // 12,000 a year is 1,000 a month; 18,000 to go takes 18 months.
        #expect(snapshot.pace == GoalPace.onTrack(projected: months(18)))
        #expect(snapshot.targetDate == goal.targetDate)
        #expect(!snapshot.isReached)
    }

    @Test("Shows the most recently reached goal once every goal is reached")
    func allReached() throws {
        let first = Goal(title: "First", targetAmount: 1_000, targetDate: months(-12))
        first.isAchieved = true
        first.achievedDate = Date(timeIntervalSince1970: 1_700_000_000)
        let second = Goal(title: "Second", targetAmount: 2_000, targetDate: months(-6))
        second.isAchieved = true
        second.achievedDate = Date(timeIntervalSince1970: 1_710_000_000)

        let snapshot = try #require(GoalSnapshot.make(goals: [first, second], items: [], now: now))

        #expect(snapshot.title == "Second")
        #expect(snapshot.isReached)
        #expect(GoalSnapshot.make(goals: [], items: [], now: now) == nil)
    }

    @Test("A debt goal shows what's still owed, and no data means no pace")
    func debtGoal() throws {
        let goal = Goal(title: "Debt-free", targetAmount: 0, targetDate: months(12), goalType: "liability")
        goal.startAmount = 10_000
        let items = [
            FinancialItem(name: "Loan", amount: 4_000, year: thisYear, category: "Student Loan", itemType: "liability"),
        ]

        let snapshot = try #require(GoalSnapshot.make(goals: [goal], items: items, now: now))

        #expect(snapshot.isDebtGoal)
        #expect(snapshot.currentAmount == 4_000)
        #expect(snapshot.progress == 0.6)

        let empty = try #require(GoalSnapshot.make(goals: [goal], items: [], now: now))
        #expect(empty.currentAmount == nil)
        #expect(empty.progress == 0)
        #expect(empty.pace == nil)
    }

    @Test("An undated goal has no target date in the widget")
    func undatedGoal() throws {
        let goal = Goal(title: "Six figures", targetAmount: 100_000, targetDate: .distantFuture)
        goal.hasTargetDate = false

        let snapshot = try #require(GoalSnapshot.make(goals: [goal], items: [], now: now))

        #expect(snapshot.targetDate == nil)
    }
}
