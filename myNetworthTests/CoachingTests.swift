//
//  CoachingTests.swift
//  myNetworthTests
//
//  Feature 3: goal pace, goals that complete themselves, and the "Future you" projection.
//

import Foundation
import SwiftData
import Testing
@testable import myNetworth

// MARK: - Pace

@MainActor
@Suite("Goal pace")
struct GoalPaceTests {

    private let now = Date.now

    private func months(_ count: Int) -> Date {
        Calendar.current.date(byAdding: .month, value: count, to: now) ?? now
    }

    @Test("Reached, overdue, or not enough history")
    func basicCases() {
        #expect(GoalCoach.pace(remaining: 0, monthsLeft: 12, pacePerMonth: 500, now: now) == GoalPace.reached)
        #expect(GoalCoach.pace(remaining: 5_000, monthsLeft: 0, pacePerMonth: 500, now: now) == GoalPace.overdue(remaining: 5_000))
        #expect(GoalCoach.pace(remaining: 12_000, monthsLeft: 12, pacePerMonth: nil, now: now) == GoalPace.needs(perMonth: 1_000))
    }

    @Test("On track when the recent pace makes the date, with when it gets there")
    func onTrack() {
        let pace = GoalCoach.pace(remaining: 12_000, monthsLeft: 12, pacePerMonth: 1_500, now: now)
        #expect(pace == GoalPace.onTrack(projected: months(8)))
    }

    @Test("Behind when the recent pace is too slow or going the wrong way")
    func behind() {
        #expect(GoalCoach.pace(remaining: 12_000, monthsLeft: 12, pacePerMonth: 500, now: now) == GoalPace.behind(perMonth: 1_000))
        #expect(GoalCoach.pace(remaining: 12_000, monthsLeft: 12, pacePerMonth: -200, now: now) == GoalPace.behind(perMonth: 1_000))
        // What's needed is rounded up, so it really is enough.
        #expect(GoalCoach.pace(remaining: 10_000, monthsLeft: 3, pacePerMonth: 0, now: now) == GoalPace.behind(perMonth: 3_334))
    }

    @Test("Months left counts a part month as one and is zero once the date has passed")
    func monthsLeft() {
        #expect(GoalCoach.monthsLeft(from: now, to: months(14)) == 14)
        #expect(GoalCoach.monthsLeft(from: now, to: now.addingTimeInterval(10 * 24 * 60 * 60)) == 1)
        #expect(GoalCoach.monthsLeft(from: now, to: now.addingTimeInterval(-60)) == 0)
    }

    @Test("Recent pace looks back up to three years")
    func pacePerMonth() {
        let values = [(year: 2020, value: 0), (year: 2022, value: 24_000), (year: 2025, value: 60_000)]
        #expect(GoalCoach.pacePerMonth(values: values) == 1_000)
        #expect(GoalCoach.pacePerMonth(values: [(year: 2025, value: 60_000)]) == nil)
    }

    // MARK: From the view model

    private func makeStore(assets: [Int: Int] = [:], debts: [Int: Int] = [:]) throws -> TestStore {
        let store = try TestStore()
        for year in Set(assets.keys).union(debts.keys) {
            store.viewModel.addYear(year)
        }
        for (year, amount) in assets {
            store.addItem("Savings", amount, year: year, category: "Cash", asset: true)
        }
        for (year, amount) in debts {
            store.addItem("Loan", amount, year: year, category: "Student Loan", asset: false)
        }
        return store
    }

    @Test("An asset goal on track")
    func assetGoalOnTrack() throws {
        let store = try makeStore(assets: [thisYear - 1: 30_000, thisYear: 42_000])
        let goal = Goal(title: "Savings", targetAmount: 60_000, targetDate: months(24), goalType: "asset")

        // 12,000 a year is 1,000 a month; 18,000 to go takes 18 months.
        #expect(store.viewModel.goalPace(for: goal, now: now) == GoalPace.onTrack(projected: months(18)))
    }

    @Test("A net worth goal behind, with what it takes")
    func netWorthGoalBehind() throws {
        let store = try makeStore(assets: [thisYear - 1: 30_000, thisYear: 42_000])
        let goal = Goal(title: "Big goal", targetAmount: 100_000, targetDate: months(24))

        // 58,000 to go in 24 months is 2,417 a month, more than the 1,000 pace.
        #expect(store.viewModel.goalPace(for: goal, now: now) == GoalPace.behind(perMonth: 2_417))
    }

    @Test("A debt goal counts paying down as progress")
    func debtGoalPace() throws {
        let store = try makeStore(debts: [thisYear - 1: 20_000, thisYear: 14_000])
        let goal = Goal(title: "Debt-free", targetAmount: 0, targetDate: months(36), goalType: "liability")

        // 6,000 a year paid down is 500 a month; 14,000 left takes 28 months.
        #expect(store.viewModel.goalPace(for: goal, now: now) == GoalPace.onTrack(projected: months(28)))
    }

    @Test("One year of data gives what's needed without judging the pace")
    func singleYear() throws {
        let store = try makeStore(assets: [thisYear: 42_000])
        let goal = Goal(title: "Savings", targetAmount: 54_000, targetDate: months(12), goalType: "asset")

        #expect(store.viewModel.goalPace(for: goal, now: now) == GoalPace.needs(perMonth: 1_000))
    }

    @Test("Without a date, only when the pace gets there")
    func noDatePace() {
        #expect(GoalCoach.pace(remaining: 12_000, monthsLeft: nil, pacePerMonth: 1_000, now: now) == GoalPace.noDate(projected: months(12)))
        #expect(GoalCoach.pace(remaining: 12_000, monthsLeft: nil, pacePerMonth: nil, now: now) == GoalPace.noDate(projected: nil))
        #expect(GoalCoach.pace(remaining: 12_000, monthsLeft: nil, pacePerMonth: -200, now: now) == GoalPace.noDate(projected: nil))
        #expect(GoalCoach.pace(remaining: 0, monthsLeft: nil, pacePerMonth: nil, now: now) == GoalPace.reached)
    }

    @Test("A goal without a date is never behind")
    func undatedGoal() throws {
        let store = try makeStore(assets: [thisYear - 1: 30_000, thisYear: 42_000])
        let goal = Goal(title: "Six figures", targetAmount: 100_000, targetDate: .distantFuture)
        goal.hasTargetDate = false

        // 58,000 to go at 1,000 a month takes 58 months.
        #expect(store.viewModel.goalPace(for: goal, now: now) == GoalPace.noDate(projected: months(58)))
    }

    @Test("No pace without data, and reached goals stay reached")
    func noDataAndReached() throws {
        let store = try TestStore()
        let goal = Goal(title: "Savings", targetAmount: 10_000, targetDate: months(12))
        #expect(store.viewModel.goalPace(for: goal, now: now) == nil)

        goal.isAchieved = true
        #expect(store.viewModel.goalPace(for: goal, now: now) == GoalPace.reached)
    }
}

// MARK: - Completing Goals

@MainActor
@Suite("Goals that complete themselves")
struct GoalCompletionTests {

    @Test("A goal is marked reached when the numbers hit it, and celebrated once")
    func completesAndCelebrates() throws {
        let store = try TestStore()
        let viewModel = store.viewModel
        viewModel.addYear(thisYear)
        let savings = store.addItem("Savings", 40_000, year: thisYear, category: "Cash", asset: true)
        let goal = Goal(title: "Fifty", targetAmount: 50_000, targetDate: .now.addingTimeInterval(365 * 24 * 60 * 60))
        viewModel.addGoal(goal)
        #expect(!goal.isAchieved)
        #expect(viewModel.goalToCelebrate?.id == nil)

        viewModel.updateItem(savings, name: "Savings", amount: 55_000, category: "Cash", month: 0)

        #expect(goal.isAchieved)
        #expect(goal.achievedDate != nil)
        #expect(viewModel.goalToCelebrate?.id == goal.id)

        viewModel.markCelebrated(goal)
        #expect(viewModel.goalToCelebrate?.id == nil)

        // Dropping below the target later doesn't undo it.
        viewModel.updateItem(savings, name: "Savings", amount: 45_000, category: "Cash", month: 0)
        #expect(goal.isAchieved)
    }

    @Test("A goal already met when it's set is reached without a celebration")
    func alreadyMet() throws {
        let store = try TestStore()
        let viewModel = store.viewModel
        viewModel.addYear(thisYear)
        store.addItem("Savings", 60_000, year: thisYear, category: "Cash", asset: true)
        let goal = Goal(title: "Fifty", targetAmount: 50_000, targetDate: .now)

        viewModel.addGoal(goal)

        #expect(goal.isAchieved)
        #expect(viewModel.goalToCelebrate?.id == nil)
    }

    @Test("Goals reached before this update are celebrated at launch")
    func reachedAtLaunch() throws {
        let store = try TestStore()
        store.viewModel.addYear(thisYear)
        store.addItem("Savings", 60_000, year: thisYear, category: "Cash", asset: true)
        // Saved by an older version, which never marked goals reached.
        let goal = Goal(title: "Fifty", targetAmount: 50_000, targetDate: .now)
        store.context.insert(goal)

        let relaunched = NetWorthViewModel(modelContext: store.context)

        #expect(goal.isAchieved)
        #expect(relaunched.goalToCelebrate?.id == goal.id)
    }
}

// MARK: - Milestones

@MainActor
@Suite("Milestones become goals")
struct MilestoneMigrationTests {

    @Test("Each milestone becomes a net worth goal with no date, and the milestone is removed")
    func movesMilestones() throws {
        let store = try TestStore()
        store.viewModel.addYear(thisYear)
        store.addItem("Savings", 60_000, year: thisYear, category: "Cash", asset: true)
        // Saved by an older version, which kept milestones apart from goals.
        let created = Date(timeIntervalSince1970: 1_700_000_000)
        let open = Milestone(title: "Six figures", targetNetWorth: 100_000)
        open.createdAt = created
        let passed = Milestone(title: "Fifty", targetNetWorth: 50_000)
        let achievedDate = Date(timeIntervalSince1970: 1_710_000_000)
        let marked = Milestone(title: "First ten", targetNetWorth: 10_000)
        marked.isAchieved = true
        marked.achievedDate = achievedDate
        store.context.insert(open)
        store.context.insert(passed)
        store.context.insert(marked)
        try store.context.save()

        let relaunched = NetWorthViewModel(modelContext: store.context)

        let leftover = try store.context.fetch(FetchDescriptor<Milestone>())
        #expect(leftover.isEmpty)
        let goals = relaunched.goals
        #expect(goals.count == 3)

        let sixFigures = try #require(goals.first { $0.title == "Six figures" })
        #expect(sixFigures.targetAmount == 100_000)
        #expect(sixFigures.goalType == "netWorth")
        #expect(!sixFigures.hasTargetDate)
        #expect(sixFigures.targetDate == .distantFuture)
        #expect(sixFigures.createdAt == created)
        #expect(!sixFigures.isAchieved)

        // Already passed, so reached without a celebration.
        let fifty = try #require(goals.first { $0.title == "Fifty" })
        #expect(fifty.isAchieved)
        #expect(fifty.isCelebrated)

        let firstTen = try #require(goals.first { $0.title == "First ten" })
        #expect(firstTen.isAchieved)
        #expect(firstTen.achievedDate == achievedDate)

        #expect(relaunched.goalToCelebrate?.id == nil)
    }

    @Test("Nothing changes when there are no milestones")
    func noMilestones() throws {
        let store = try TestStore()
        store.viewModel.addGoal(Goal(title: "Savings", targetAmount: 10_000, targetDate: .now.addingTimeInterval(365 * 24 * 60 * 60)))

        let relaunched = NetWorthViewModel(modelContext: store.context)

        #expect(relaunched.goals.count == 1)
        #expect(relaunched.goals.first?.hasTargetDate == true)
    }
}

// MARK: - Future You

@MainActor
@Suite("Future you")
struct ProjectionTests {

    @Test("Projects at the average yearly change")
    func projection() {
        let projection = NetWorthProjection(baseYear: 2025, baseNetWorth: 100_000, firstYear: 2020, averageYearlyChange: 10_000)

        #expect(projection.netWorth(inYears: 5) == 150_000)
        #expect(projection.netWorth(inYears: 20) == 300_000)
        #expect(projection.points.map(\.year) == [2025, 2030, 2035, 2045])
        #expect(projection.points.first?.netWorth == 100_000)
    }

    @Test("Starts from the latest year with data, leaving out planning years")
    func fromViewModel() throws {
        let store = try TestStore()
        for year in [thisYear - 3, thisYear - 1, thisYear + 2] {
            store.viewModel.addYear(year)
        }
        store.addItem("Savings", 40_000, year: thisYear - 3, category: "Cash", asset: true)
        store.addItem("Savings", 60_000, year: thisYear - 1, category: "Cash", asset: true)
        store.addItem("Savings", 500_000, year: thisYear + 2, category: "Cash", asset: true)

        let projection = try #require(store.viewModel.netWorthProjection)

        #expect(projection.baseYear == thisYear - 1)
        #expect(projection.firstYear == thisYear - 3)
        #expect(projection.averageYearlyChange == 10_000)
        #expect(projection.netWorth(inYears: 5) == 110_000)
    }

    @Test("Needs two years of data")
    func needsTwoYears() throws {
        let store = try TestStore()
        store.viewModel.addYear(thisYear)
        store.addItem("Savings", 40_000, year: thisYear, category: "Cash", asset: true)

        #expect(store.viewModel.netWorthProjection == nil)
    }
}
