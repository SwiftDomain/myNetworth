//
//  DebtPlanner.swift
//  myNetworth
//

import Foundation

// MARK: - Payoff Strategy

enum PayoffStrategy: String, CaseIterable, Identifiable {
    case snowball
    case avalanche

    var id: Self { self }

    var title: String {
        switch self {
        case .snowball: "Snowball"
        case .avalanche: "Avalanche"
        }
    }

    var summary: String {
        switch self {
        case .snowball: "Smallest balance first, for quick wins"
        case .avalanche: "Highest rate first, to pay less interest"
        }
    }
}

// MARK: - Planner Input and Output

/// One debt as the planner sees it.
struct PlannerDebt: Identifiable {
    let id: UUID
    let name: String
    let balance: Int
    /// Annual interest rate as a percentage, e.g. 24.9.
    let annualRate: Double
    let minimumPayment: Int
}

/// A debt reaching zero during a plan.
struct PayoffMilestone: Identifiable {
    var id: UUID { debtID }
    let debtID: UUID
    let name: String
    /// Months from now, starting at 1.
    let month: Int
    /// The debt that gets the freed-up money next, and what it then gets each month.
    let nextDebtName: String?
    let nextDebtPayment: Int?
}

struct PayoffPlan {
    let strategy: PayoffStrategy
    /// Months until every debt is paid off.
    let months: Int
    let totalInterest: Double
    /// Debts in the order they're paid off.
    let milestones: [PayoffMilestone]
    /// False when the payments never clear the debt, because they don't cover the interest.
    let isPayable: Bool
}

// MARK: - Planner

enum DebtPlanner {

    /// Plans longer than this (50 years) are treated as never paying off.
    static let maxMonths = 600

    /// Simulates paying off `debts` month by month. Every debt gets its minimum payment;
    /// the extra amount, plus the minimum of each debt already paid off, goes to the first
    /// unpaid debt in the strategy's order.
    static func plan(for debts: [PlannerDebt], strategy: PayoffStrategy, extraPayment: Int) -> PayoffPlan {
        let order = payoffOrder(of: debts, strategy: strategy)
        let minimums = debts.map { Double($0.minimumPayment) }
        let budget = minimums.reduce(0, +) + Double(max(extraPayment, 0))
        var balances = debts.map { Double(max($0.balance, 0)) }
        var totalInterest = 0.0
        var milestones: [PayoffMilestone] = []
        var month = 0

        func isPaidOff(_ index: Int) -> Bool {
            balances[index] < 0.005
        }

        while !debts.indices.allSatisfy(isPaidOff) {
            guard month < maxMonths else {
                return PayoffPlan(
                    strategy: strategy, months: month, totalInterest: totalInterest,
                    milestones: milestones, isPayable: false
                )
            }
            month += 1

            for index in debts.indices where !isPaidOff(index) {
                let interest = balances[index] * debts[index].annualRate / 100 / 12
                balances[index] += interest
                totalInterest += interest
            }

            var available = budget
            for index in debts.indices where !isPaidOff(index) {
                let payment = min(minimums[index], balances[index])
                balances[index] -= payment
                available -= payment
            }

            // Whatever is left goes to the debts in strategy order.
            for index in order where !isPaidOff(index) && available > 0 {
                let payment = min(available, balances[index])
                balances[index] -= payment
                available -= payment
            }

            for index in order where isPaidOff(index) && !milestones.contains(where: { $0.debtID == debts[index].id }) {
                let next = order.first { !isPaidOff($0) }
                let nextPayment = next.map { next in
                    // The next debt keeps its own minimum and receives everything the other
                    // remaining debts don't need for theirs.
                    let othersMinimums = order
                        .filter { $0 != next && !isPaidOff($0) }
                        .reduce(0) { $0 + minimums[$1] }
                    return Int((budget - othersMinimums).rounded())
                }
                milestones.append(PayoffMilestone(
                    debtID: debts[index].id,
                    name: debts[index].name,
                    month: month,
                    nextDebtName: next.map { debts[$0].name },
                    nextDebtPayment: nextPayment
                ))
            }
        }

        return PayoffPlan(
            strategy: strategy, months: month, totalInterest: totalInterest,
            milestones: milestones, isPayable: true
        )
    }

    /// Indices of `debts` in the order the strategy targets them.
    static func payoffOrder(of debts: [PlannerDebt], strategy: PayoffStrategy) -> [Int] {
        debts.indices.sorted { a, b in
            let first = debts[a], second = debts[b]
            switch strategy {
            case .snowball:
                if first.balance != second.balance { return first.balance < second.balance }
                if first.annualRate != second.annualRate { return first.annualRate > second.annualRate }
            case .avalanche:
                if first.annualRate != second.annualRate { return first.annualRate > second.annualRate }
                if first.balance != second.balance { return first.balance < second.balance }
            }
            return first.name < second.name
        }
    }
}
