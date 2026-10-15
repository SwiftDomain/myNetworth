//
//  Dashboard.swift
//  myNetworth
//

import Foundation

// MARK: - Net Worth Summary

/// What Home shows at the top: the latest net worth and how it's moving.
struct NetWorthSummary {
    /// The latest year, not in the future, that has items.
    let year: Int
    let netWorth: Int
    /// The change since the previous year with data, if there is one.
    let change: YearChange?
    /// Each year with data up to `year`, oldest first, for the trend line.
    let trend: [YearlyData]
    /// When the year's numbers were last changed.
    let lastUpdated: Date?
}

// MARK: - Next Step

/// The one thing Home suggests doing next, most important first.
enum NextStep: Equatable {
    /// Nothing has been added yet.
    case addFirstYear
    /// The calendar year isn't tracked yet. It can start from `from`'s balances, if any.
    case startYear(Int, from: Int?)
    /// The calendar year is tracked but has nothing in it.
    case addAccounts(year: Int)
    /// The year's balances haven't been checked for a while; `lastUpdated` is the oldest.
    case updateBalances(year: Int, lastUpdated: Date)
    /// There are no goals yet.
    case setFirstGoal
    /// The debt the payoff plan puts extra payments toward.
    case payOffNext(debtName: String)
}
