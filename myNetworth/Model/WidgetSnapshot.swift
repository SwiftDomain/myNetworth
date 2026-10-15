//
//  WidgetSnapshot.swift
//  myNetworth
//

import Foundation

/// What the Home Screen widget shows: the latest year with data, its totals, and the change
/// since the previous year with data.
///
/// This file is a member of both the app and the widget extension, so the app's tests can
/// check the widget's numbers.
struct WidgetSnapshot: Equatable {
    let year: Int
    let assets: Int
    let liabilities: Int
    /// The previous year with data, if any.
    let previousYear: Int?
    /// The change in net worth since `previousYear`, as a percentage.
    let percentageChange: Double?

    var netWorth: Int { assets - liabilities }

    /// The snapshot for the latest year up to `now` that has items, or nil when there's none.
    /// Future planning years are left out, and each account counts once at its latest entry.
    static func make(from items: [FinancialItem], now: Date = .now) -> WidgetSnapshot? {
        let thisYear = Calendar.current.component(.year, from: now)
        let yearsWithData = Set(items.map(\.year)).filter { $0 <= thisYear }.sorted()
        guard let year = yearsWithData.last else { return nil }

        let current = totals(of: items, in: year)
        let previousYear = yearsWithData.dropLast().last
        var percentageChange: Double?
        if let previousYear {
            let previous = totals(of: items, in: previousYear)
            let previousNetWorth = previous.assets - previous.liabilities
            if previousNetWorth != 0 {
                let change = (current.assets - current.liabilities) - previousNetWorth
                percentageChange = Double(change) / Double(abs(previousNetWorth)) * 100
            }
        }

        return WidgetSnapshot(
            year: year,
            assets: current.assets,
            liabilities: current.liabilities,
            previousYear: previousYear,
            percentageChange: percentageChange
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
