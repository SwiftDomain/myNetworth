//
//  Coaching.swift
//  myNetworth
//

import Foundation

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
