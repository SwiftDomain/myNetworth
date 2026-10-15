//
//  Coaching.swift
//  myNetworth
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
}

enum GoalCoach {

    /// How many years back the recent pace looks.
    static let paceWindowYears = 3

    /// Judges a goal's pace.
    /// - Parameters:
    ///   - remaining: How far is left to go, in the goal's direction.
    ///   - monthsLeft: Whole months until the target date, 0 once it has passed.
    ///   - pacePerMonth: Recent progress per month in the goal's direction, or nil if unknown.
    static func pace(remaining: Int, monthsLeft: Int, pacePerMonth: Double?, now: Date = .now) -> GoalPace {
        guard remaining > 0 else { return .reached }
        guard monthsLeft > 0 else { return .overdue(remaining: remaining) }

        let needed = Double(remaining) / Double(monthsLeft)
        let neededPerMonth = Int(needed.rounded(.up))
        guard let pacePerMonth else { return .needs(perMonth: neededPerMonth) }
        guard pacePerMonth > 0, pacePerMonth >= needed else { return .behind(perMonth: neededPerMonth) }

        let monthsToGo = Int((Double(remaining) / pacePerMonth).rounded(.up))
        let projected = Calendar.current.date(byAdding: .month, value: monthsToGo, to: now) ?? now
        return .onTrack(projected: projected)
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

// MARK: - Future You

/// Net worth projected forward at the average yearly change so far.
struct NetWorthProjection: Equatable {
    /// The latest year with data, where the projection starts.
    let baseYear: Int
    let baseNetWorth: Int
    /// The first year with data, which the average is measured from.
    let firstYear: Int
    let averageYearlyChange: Int

    /// How many years ahead "Future you" looks.
    static let horizons = [5, 10, 20]

    init(baseYear: Int, baseNetWorth: Int, firstYear: Int, averageYearlyChange: Int) {
        self.baseYear = baseYear
        self.baseNetWorth = baseNetWorth
        self.firstYear = firstYear
        self.averageYearlyChange = averageYearlyChange
    }

    /// Projects from the all-years insights, which need at least two years with data.
    init(_ insights: OverallInsights) {
        self.init(
            baseYear: insights.lastYear,
            baseNetWorth: insights.lastNetWorth,
            firstYear: insights.firstYear,
            averageYearlyChange: insights.averageYearlyChange
        )
    }

    func netWorth(inYears years: Int) -> Int {
        baseNetWorth + averageYearlyChange * years
    }

    /// The projected line: the base year, then each horizon.
    var points: [WidgetSnapshot.YearPoint] {
        [WidgetSnapshot.YearPoint(year: baseYear, netWorth: baseNetWorth)]
            + Self.horizons.map { WidgetSnapshot.YearPoint(year: baseYear + $0, netWorth: netWorth(inYears: $0)) }
    }
}
