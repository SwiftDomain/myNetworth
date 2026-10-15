//
//  HomeTab.swift
//  myNetworth
//

import SwiftUI
import Charts

// MARK: - Home Tab

/// Where Home can take the user.
private enum HomeDestination: Hashable {
    case year(Int, YearSection)
    case debtPlanner
}

/// The sheets Home can open.
private enum HomeSheet: Identifiable {
    case addYear
    case updateBalances(year: Int)
    case addGoal

    var id: String {
        switch self {
        case .addYear: "addYear"
        case .updateBalances(let year): "updateBalances-\(year)"
        case .addGoal: "addGoal"
        }
    }
}

struct HomeTab: View {
    var viewModel: NetWorthViewModel
    @AppStorage(DebtPayoffView.strategyKey) private var strategy = PayoffStrategy.snowball
    @State private var path = NavigationPath()
    @State private var sheet: HomeSheet?
    @State private var newYear = Calendar.current.component(.year, from: .now)

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                Background(bgColor1: Theme.mainGradient1, bgColor2: Theme.mainGradient2)

                ScrollView {
                    VStack(spacing: 20) {
                        let summary = viewModel.netWorthSummary

                        if let summary {
                            NavigationLink(value: HomeDestination.year(summary.year, .summary)) {
                                NetWorthCard(summary: summary, currencyCode: viewModel.currencyCode)
                            }
                            .buttonStyle(.plain)
                        }

                        if let step = viewModel.nextStep(strategy: strategy) {
                            NextStepCard(step: step) {
                                perform(step)
                            }
                        } else {
                            AllCaughtUpCard()
                        }

                        if viewModel.goals.contains(where: { !$0.isAchieved }) {
                            GoalPreviewCard(viewModel: viewModel)
                        }

                        if let summary {
                            WhatChangedCard(viewModel: viewModel, year: summary.year)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("myNetworth")
            // The backgrounds are dark in every appearance, so keep the bar text light.
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    HideAmountsButton()
                }
            }
            .navigationDestination(for: HomeDestination.self) { destination in
                switch destination {
                case .year(let year, let section):
                    YearDetailView(viewModel: viewModel, year: year, initialSection: section)
                case .debtPlanner:
                    DebtPayoffView(viewModel: viewModel)
                }
            }
            .sheet(item: $sheet) { sheet in
                switch sheet {
                case .addYear:
                    AddYearView(viewModel: viewModel, newYear: $newYear) { addedYear in
                        path.append(HomeDestination.year(addedYear, .summary))
                    }
                case .updateBalances(let year):
                    UpdateBalancesView(viewModel: viewModel, year: year)
                case .addGoal:
                    AddGoalView(viewModel: viewModel)
                }
            }
        }
    }

    private func perform(_ step: NextStep) {
        switch step {
        case .addFirstYear:
            newYear = Calendar.current.component(.year, from: .now)
            sheet = .addYear
        case .startYear(let year, _):
            newYear = year
            sheet = .addYear
        case .addAccounts(let year):
            path.append(HomeDestination.year(year, .assets))
        case .updateBalances(let year, _):
            sheet = .updateBalances(year: year)
        case .setFirstGoal:
            sheet = .addGoal
        case .payOffNext:
            path.append(HomeDestination.debtPlanner)
        }
    }
}

// MARK: - Net Worth Card

/// The latest net worth, how it changed since the previous year, and the trend so far.
struct NetWorthCard: View {
    let summary: NetWorthSummary
    let currencyCode: String

    private var currency: IntegerFormatStyle<Int>.Currency {
        .currency(code: currencyCode).precision(.fractionLength(0))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Net Worth")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)

                Spacer()

                Text(String(summary.year))
                    .font(.subheadline)
                    .bold()
                    .foregroundStyle(.blue)
            }

            Text(summary.netWorth, format: currency)
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .privacySensitive()

            if let change = summary.change {
                HStack(spacing: 6) {
                    Image(systemName: change.change >= 0 ? "arrow.up.right" : "arrow.down.right")

                    Text(abs(change.change), format: currency)
                        .privacySensitive()

                    if let percent = change.percentChange {
                        Text("(\(abs(percent), format: .number.precision(.fractionLength(1)))%)")
                    }

                    Text("since \(String(change.previousYear))")
                        .foregroundStyle(Theme.textSecondary)
                }
                .font(.subheadline)
                .foregroundStyle(change.change >= 0 ? Theme.positiveAmount : Theme.negativeAmount)
            }

            if summary.trend.count >= 2 {
                Chart(summary.trend) { point in
                    LineMark(
                        x: .value("Year", point.year),
                        y: .value("Net Worth", point.netWorth)
                    )
                    .interpolationMethod(.monotone)
                    .foregroundStyle(.blue)

                    PointMark(
                        x: .value("Year", point.year),
                        y: .value("Net Worth", point.netWorth)
                    )
                    .symbolSize(20)
                    .foregroundStyle(.blue)
                }
                .chartXAxis(.hidden)
                .chartYAxis(.hidden)
                .frame(height: 64)
                .accessibilityHidden(true)
            }

            if let lastUpdated = summary.lastUpdated {
                Text("Updated \(lastUpdated, format: .relative(presentation: .named))")
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Theme.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Theme.cardBorder, lineWidth: 1)
                )
        )
    }
}

// MARK: - Next Step Card

/// The one suggested action, which does it when tapped.
struct NextStepCard: View {
    let step: NextStep
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(.blue)
                    .frame(width: 36)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Next step")
                        .font(.caption)
                        .textCase(.uppercase)
                        .foregroundStyle(Theme.textSecondary)

                    Text(title)
                        .font(.headline)
                        .foregroundStyle(Theme.textPrimary)

                    detail
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundStyle(Theme.textSecondary)
            }
            .padding()
            .background(Theme.cardBackground)
            .clipShape(.rect(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }

    private var icon: String {
        switch step {
        case .addFirstYear, .startYear: "calendar.badge.plus"
        case .addAccounts: "plus.circle"
        case .updateBalances: "arrow.triangle.2.circlepath"
        case .setFirstGoal: "target"
        case .payOffNext: "chart.line.downtrend.xyaxis"
        }
    }

    private var title: String {
        switch step {
        case .addFirstYear: "Add your first year"
        case .startYear(let year, _): "Start \(String(year))"
        case .addAccounts(let year): "Add your \(String(year)) accounts"
        case .updateBalances(let year, _): "Update \(String(year)) balances"
        case .setFirstGoal: "Set your first goal"
        case .payOffNext(let debtName): "Pay off \(debtName) next"
        }
    }

    private var detail: Text {
        switch step {
        case .addFirstYear:
            Text("Enter what you own and owe to see your net worth.")
        case .startYear(_, let sourceYear?):
            Text("Begin with \(String(sourceYear))'s balances and update what changed.")
        case .startYear(_, nil):
            Text("Add this year to keep tracking your net worth.")
        case .addAccounts:
            Text("Enter what you own and owe this year.")
        case .updateBalances(_, let lastUpdated):
            Text("Last checked \(lastUpdated, format: .relative(presentation: .named)).")
        case .setFirstGoal:
            Text("Pick a number to aim for and watch your progress.")
        case .payOffNext:
            Text("Your payoff plan puts extra payments here first.")
        }
    }
}

// MARK: - All Caught Up Card

private struct AllCaughtUpCard: View {
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "checkmark.seal.fill")
                .font(.title2)
                .foregroundStyle(.green)
                .frame(width: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text("You're all caught up")
                    .font(.headline)
                    .foregroundStyle(Theme.textPrimary)

                Text("Your balances are current. Check back next month.")
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
            }

            Spacer()
        }
        .padding()
        .background(Theme.cardBackground)
        .clipShape(.rect(cornerRadius: 16))
    }
}
