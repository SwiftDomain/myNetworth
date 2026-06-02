//
//  DebtSnowballView.swift
//  myNetworth
//

import SwiftUI

// MARK: - Debt Snowball View

/// Lists the most recent year's liabilities in debt-snowball payoff order
/// (smallest balance first) so the user knows which debt to tackle next.
struct DebtSnowballView: View {
    var viewModel: NetWorthViewModel

    private var debts: [FinancialItem] {
        guard let year = viewModel.mostRecentYear else { return [] }
        return viewModel.snowballOrder(for: year)
    }

    private var totalDebt: Int {
        debts.reduce(0) { $0 + $1.amount }
    }

    var body: some View {
        ZStack {
            Background(bgColor1: Theme.mainGradient1, bgColor2: Theme.mainGradient2)

            ScrollView {
                VStack(spacing: 20) {
                    if debts.isEmpty {
                        EmptyStateView(
                            icon: "snowflake",
                            message: "No liabilities to pay off",
                            subMessage: "Add debts to see your snowball plan"
                        )
                        .padding(.top, 100)
                    } else {
                        SnowballSummaryCard(
                            totalDebt: totalDebt,
                            debtCount: debts.count,
                            currencyCode: viewModel.currencyCode
                        )

                        SnowballExplanationCard()

                        VStack(spacing: 12) {
                            ForEach(debts.enumerated(), id: \.element.id) { index, debt in
                                SnowballRow(
                                    rank: index + 1,
                                    debt: debt,
                                    isNext: index == 0,
                                    currencyCode: viewModel.currencyCode
                                )
                            }
                        }
                    }
                }
                .padding()
            }
        }
        .navigationTitle("Debt Snowball")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Summary Card

struct SnowballSummaryCard: View {
    let totalDebt: Int
    let debtCount: Int
    var currencyCode: String = "USD"

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Total Liabilities")
                .font(.caption)
                .foregroundStyle(Theme.textSecondary)

            Text(totalDebt, format: .currency(code: currencyCode).precision(.fractionLength(0)))
                .font(.title)
                .bold()
                .foregroundStyle(Theme.negativeAmount)

            Text("\(debtCount) debts to pay off")
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Theme.cardBackground)
        .clipShape(.rect(cornerRadius: 12))
    }
}

// MARK: - Explanation Card

struct SnowballExplanationCard: View {
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "snowflake")
                .font(.title2)
                .foregroundStyle(.blue)

            Text("Pay off the smallest balances first to build momentum, rolling each freed-up payment into the next debt.")
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Theme.cardBackground)
        .clipShape(.rect(cornerRadius: 12))
    }
}

// MARK: - Snowball Row

struct SnowballRow: View {
    let rank: Int
    let debt: FinancialItem
    let isNext: Bool
    var currencyCode: String = "USD"

    var body: some View {
        HStack(spacing: 16) {
            Text("\(rank)")
                .font(.headline)
                .foregroundStyle(isNext ? .white : Theme.textPrimary)
                .frame(width: 36, height: 36)
                .background(isNext ? Color.blue : Theme.subtleBackground)
                .clipShape(.circle)

            VStack(alignment: .leading, spacing: 4) {
                Text(debt.name)
                    .font(.headline)
                    .foregroundStyle(Theme.textPrimary)

                Text(debt.category)
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(debt.amount, format: .currency(code: currencyCode).precision(.fractionLength(0)))
                    .font(.subheadline)
                    .bold()
                    .foregroundStyle(Theme.negativeAmount)

                if isNext {
                    Text("Pay first")
                        .font(.caption2)
                        .foregroundStyle(.blue)
                }
            }
        }
        .padding()
        .background(Theme.cardBackground)
        .clipShape(.rect(cornerRadius: 12))
    }
}
