//
//  WidgetSnapshot.swift
//  myNetworth
//

import Foundation

/// What the widgets show: the latest year with data, its totals, the change since the previous
/// year with data, and net worth over the years.
///
/// This file is a member of both the app and the widget extension, so the app's tests can
/// check the widget's numbers.
struct WidgetSnapshot: Equatable {
    /// One year's net worth, for the trend graph.
    struct YearPoint: Equatable, Identifiable {
        let year: Int
        let netWorth: Int

        var id: Int { year }
    }

    let year: Int
    let assets: Int
    let liabilities: Int
    /// The previous year with data, if any.
    let previousYear: Int?
    /// The change in net worth since `previousYear`, as a percentage.
    let percentageChange: Double?
    /// Net worth for every year with data up to `year`, oldest first.
    let trend: [YearPoint]

    var netWorth: Int { assets - liabilities }

    /// The snapshot for the latest year up to `now` that has items, or nil when there's none.
    /// Future planning years are left out, and each account counts once at its latest entry.
    static func make(from items: [FinancialItem], now: Date = .now) -> WidgetSnapshot? {
        let years = history(of: items, now: now)
        guard let current = years.last else { return nil }

        let trend = years.map { YearPoint(year: $0.year, netWorth: $0.netWorth) }
        let previous = trend.dropLast().last
        var percentageChange: Double?
        if let previous, previous.netWorth != 0 {
            let change = current.netWorth - previous.netWorth
            percentageChange = Double(change) / Double(abs(previous.netWorth)) * 100
        }

        return WidgetSnapshot(
            year: current.year,
            assets: current.assets,
            liabilities: current.liabilities,
            previousYear: previous?.year,
            percentageChange: percentageChange,
            trend: trend
        )
    }

    /// Totals for every year up to `now` that has items, oldest first.
    static func history(of items: [FinancialItem], now: Date = .now) -> [YearTotals] {
        let thisYear = Calendar.current.component(.year, from: now)
        return Set(items.map(\.year)).filter { $0 <= thisYear }.sorted().map { year in
            let entries = items.filter { $0.year == year }.latestEntries()
            return YearTotals(
                year: year,
                assets: entries.filter { $0.itemType == "asset" }.reduce(0) { $0 + $1.amount },
                liabilities: entries.filter { $0.itemType == "liability" }.reduce(0) { $0 + $1.amount }
            )
        }
    }
}

// MARK: - Goal

/// What the goal widget shows: the goal Home features, or the most recently reached one once
/// every goal is reached.
struct GoalSnapshot: Equatable {
    let title: String
    let isDebtGoal: Bool
    let targetAmount: Int
    /// Net worth, total assets or total debt in the latest year with data. Nil without data.
    let currentAmount: Int?
    let progress: Double
    /// Nil without data.
    let pace: GoalPace?
    /// Nil for a goal without a target date.
    let targetDate: Date?

    var isReached: Bool { pace == GoalPace.reached }

    static func make(goals: [Goal], items: [FinancialItem], now: Date = .now) -> GoalSnapshot? {
        let lastReached = goals
            .filter { $0.isAchieved }
            .max { ($0.achievedDate ?? .distantPast) < ($1.achievedDate ?? .distantPast) }
        guard let goal = GoalCoach.featuredGoal(in: goals) ?? lastReached else { return nil }

        let history = WidgetSnapshot.history(of: items, now: now)
        var currentAmount: Int?
        var progress = 0.0
        if let current = history.last {
            switch goal.goalType {
            case "liability": currentAmount = current.liabilities
            case "asset": currentAmount = current.assets
            default: currentAmount = current.netWorth
            }
            progress = GoalCoach.progress(of: goal, current: current)
        }

        return GoalSnapshot(
            title: goal.title,
            isDebtGoal: goal.goalType == "liability",
            targetAmount: goal.targetAmount,
            currentAmount: currentAmount,
            progress: progress,
            pace: GoalCoach.pace(of: goal, history: history, now: now),
            targetDate: goal.hasTargetDate ? goal.targetDate : nil
        )
    }
}
