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
        let thisYear = Calendar.current.component(.year, from: now)
        let yearsWithData = Set(items.map(\.year)).filter { $0 <= thisYear }.sorted()
        guard let year = yearsWithData.last else { return nil }

        let current = totals(of: items, in: year)
        let trend = yearsWithData.map { pointYear in
            let yearTotals = totals(of: items, in: pointYear)
            return YearPoint(year: pointYear, netWorth: yearTotals.assets - yearTotals.liabilities)
        }
        let previous = trend.dropLast().last
        var percentageChange: Double?
        if let previous, previous.netWorth != 0 {
            let change = (current.assets - current.liabilities) - previous.netWorth
            percentageChange = Double(change) / Double(abs(previous.netWorth)) * 100
        }

        return WidgetSnapshot(
            year: year,
            assets: current.assets,
            liabilities: current.liabilities,
            previousYear: previous?.year,
            percentageChange: percentageChange,
            trend: trend
        )
    }

    private static func totals(of items: [FinancialItem], in year: Int) -> (assets: Int, liabilities: Int) {
        let entries = items.filter { $0.year == year }.latestEntries()
        return (
            assets: entries.filter { $0.itemType == "asset" }.reduce(0) { $0 + $1.amount },
            liabilities: entries.filter { $0.itemType == "liability" }.reduce(0) { $0 + $1.amount }
        )
    }
}
