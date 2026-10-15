//
//  GoalCoach.swift
//  myNetworth
//
//  How goals are measured and paced. This file is a member of both the app and the widget
//  extension, so the goal widget shows the same progress and pace as the app.
//

import Foundation

// MARK: - Goal Pace

/// How a goal is doing against its target date.
enum GoalPace: Equatable {
    /// The goal has been reached.
    case reached
    /// The target date has passed with `remaining` still to go.
    case overdue(remaining: Int)
    /// The recent pace reaches the goal by its date, around `projected`.
    case onTrack(projected: Date)
    /// The recent pace is too slow; `perMonth` a month would still make the date.
    case behind(perMonth: Int)
    /// There isn't enough history to judge the pace; `perMonth` a month makes the date.
    case needs(perMonth: Int)
    /// The goal has no target date; at the recent pace it's reached around `projected`,
    /// or nil when the pace is unknown or going the wrong way.
    case noDate(projected: Date?)
}

enum GoalCoach {

    /// How many years back the recent pace looks.
    static let paceWindowYears = 3

    /// Judges a goal's pace.
    /// - Parameters:
    ///   - remaining: How far is left to go, in the goal's direction.
    ///   - monthsLeft: Whole months until the target date, 0 once it has passed, or nil for a
    ///     goal with no target date.
    ///   - pacePerMonth: Recent progress per month in the goal's direction, or nil if unknown.
    static func pace(remaining: Int, monthsLeft: Int?, pacePerMonth: Double?, now: Date = .now) -> GoalPace {
        guard remaining > 0 else { return .reached }
        guard let monthsLeft else {
            // Without a date there's nothing to be behind; only when the pace gets there.
            guard let pacePerMonth, pacePerMonth > 0 else { return .noDate(projected: nil) }
            return .noDate(projected: projectedDate(remaining: remaining, pacePerMonth: pacePerMonth, now: now))
        }
        guard monthsLeft > 0 else { return .overdue(remaining: remaining) }

        let needed = Double(remaining) / Double(monthsLeft)
        let neededPerMonth = Int(needed.rounded(.up))
        guard let pacePerMonth else { return .needs(perMonth: neededPerMonth) }
        guard pacePerMonth > 0, pacePerMonth >= needed else { return .behind(perMonth: neededPerMonth) }

        return .onTrack(projected: projectedDate(remaining: remaining, pacePerMonth: pacePerMonth, now: now))
    }

    /// When `remaining` is covered at `pacePerMonth`, counting a part month as one.
    private static func projectedDate(remaining: Int, pacePerMonth: Double, now: Date) -> Date {
        let monthsToGo = Int((Double(remaining) / pacePerMonth).rounded(.up))
        return Calendar.current.date(byAdding: .month, value: monthsToGo, to: now) ?? now
    }

    /// Whole months from `now` until `target`, counting a part month as one, or 0 when the
    /// date has passed.
    static func monthsLeft(from now: Date, to target: Date) -> Int {
        guard target > now else { return 0 }
        let months = Calendar.current.dateComponents([.month], from: now, to: target).month ?? 0
        return max(months, 1)
    }

    /// Progress per month over the last few years with data, from yearly values sorted oldest
    /// first. Nil with fewer than two years in that window.
    static func pacePerMonth(values: [(year: Int, value: Int)]) -> Double? {
        guard let latest = values.last,
              let earliest = values.first(where: { $0.year >= latest.year - paceWindowYears }),
              earliest.year < latest.year else { return nil }
        let years = Double(latest.year - earliest.year)
        return Double(latest.value - earliest.value) / (years * 12)
    }
}

// MARK: - Measuring Goals

/// One year's totals, which goals are measured against.
struct YearTotals: Equatable {
    let year: Int
    let assets: Int
    let liabilities: Int

    var netWorth: Int { assets - liabilities }
}

extension GoalCoach {

    /// What a goal measures in a year, oriented so that higher is better: net worth, total
    /// assets, or total debt as a negative number.
    static func measure(_ goal: Goal, in totals: YearTotals) -> Int {
        switch goal.goalType {
        case "liability": -totals.liabilities
        case "asset": totals.assets
        default: totals.netWorth
        }
    }

    /// How far along a goal is against the latest year's totals, from 0 (not started) to 1
    /// (reached).
    static func progress(of goal: Goal, current: YearTotals) -> Double {
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

    /// How a goal is pacing toward its target date, judged from yearly totals sorted oldest
    /// first and ending with the latest year with data. Nil when there's no data yet.
    static func pace(of goal: Goal, history: [YearTotals], now: Date = .now) -> GoalPace? {
        if goal.isAchieved { return .reached }
        guard let latest = history.last else { return nil }

        let target = goal.goalType == "liability" ? -goal.targetAmount : goal.targetAmount
        let values = history.map { (year: $0.year, value: measure(goal, in: $0)) }
        return pace(
            remaining: target - measure(goal, in: latest),
            monthsLeft: goal.hasTargetDate ? monthsLeft(from: now, to: goal.targetDate) : nil,
            pacePerMonth: pacePerMonth(values: values),
            now: now
        )
    }

    /// The goal Home and the goal widget show: the unreached goal with the nearest target
    /// date. Goals without a date come after dated ones, oldest first.
    static func featuredGoal(in goals: [Goal]) -> Goal? {
        goals
            .filter { !$0.isAchieved }
            .min { ($0.targetDate, $0.createdAt) < ($1.targetDate, $1.createdAt) }
    }
}
