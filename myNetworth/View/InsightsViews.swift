//
//  InsightsViews.swift
//  myNetworth
//

import SwiftUI

// MARK: - What Changed Card

/// How a year compares with the previous year that has data. The summary at the top is
/// written on the device by Apple Intelligence when it's available, otherwise it's a
/// template built from the same numbers.
struct WhatChangedCard: View {
    var viewModel: NetWorthViewModel
    let year: Int
    @State private var narration: String?

    private func money(_ amount: Int) -> String {
        amount.formatted(.currency(code: viewModel.currencyCode).precision(.fractionLength(0)))
    }

    private func signed(_ amount: Int) -> String {
        InsightsEngine.signed(amount) { money($0) }
    }

    var body: some View {
        if let change = InsightsEngine.yearChange(for: year, items: viewModel.insightItems) {
            let facts = InsightsEngine.facts(for: change) { money($0) }
            card(change)
                .task(id: facts) {
                    narration = nil
                    narration = await InsightNarrator.summary(for: facts)
                }
        }
    }

    private func card(_ change: YearChange) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .foregroundStyle(.yellow)
                Text("What changed since \(String(change.previousYear))")
                    .font(.headline)
                    .foregroundStyle(Theme.textPrimary)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(narration ?? InsightsEngine.templateSummary(for: change) { money($0) })
                    .font(.subheadline)
                    .foregroundStyle(Theme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .privacySensitive()

                if narration != nil {
                    Text("Written on this device by Apple Intelligence")
                        .font(.caption2)
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            .animation(.easeInOut, value: narration)

            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Net worth")
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                    Text(signed(change.change))
                        .font(.title3)
                        .bold()
                        .foregroundStyle(effectColor(change.change))
                        .privacySensitive()
                }

                Spacer()

                if let percent = change.percentChange {
                    Text("\(percent >= 0 ? "+" : "−")\(abs(percent), format: .number.precision(.fractionLength(1)))%")
                        .font(.subheadline)
                        .bold()
                        .foregroundStyle(effectColor(change.change))
                }
            }

            Text("Assets \(signed(change.assetsChange)) · Debts \(signed(change.liabilitiesChange))")
                .font(.caption)
                .foregroundStyle(Theme.textSecondary)
                .privacySensitive()

            if !change.gains.isEmpty {
                moverList("Biggest boosts", change.gains)
            }

            if !change.drops.isEmpty {
                moverList("Biggest drags", change.drops)
            }

            let paidOff = change.removed.filter { !$0.isAsset }.map(\.name)
            let goneAssets = change.removed.filter(\.isAsset).map(\.name)
            let newAssets = change.added.filter(\.isAsset).map { "\($0.name) (\(money($0.current)))" }
            let newDebts = change.added.filter { !$0.isAsset }.map { "\($0.name) (\(money($0.current)))" }

            if !paidOff.isEmpty {
                namesLine("Paid off", paidOff)
            }
            if !newAssets.isEmpty {
                namesLine("New", newAssets, showsAmounts: true)
            }
            if !newDebts.isEmpty {
                namesLine("New debt", newDebts, showsAmounts: true)
            }
            if !goneAssets.isEmpty {
                namesLine("No longer listed", goneAssets)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Theme.subtleBackground)
        .clipShape(.rect(cornerRadius: 16))
    }

    private func moverList(_ title: String, _ items: [ItemChange]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(Theme.textSecondary)

            ForEach(items) { item in
                HStack {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(item.name)
                            .font(.subheadline)
                            .foregroundStyle(Theme.textPrimary)
                        Text(item.category)
                            .font(.caption2)
                            .foregroundStyle(Theme.textSecondary)
                    }
                    Spacer()
                    Text(detail(for: item))
                        .font(.subheadline)
                        .bold()
                        .foregroundStyle(effectColor(item.netWorthEffect))
                        .privacySensitive()
                }
            }
        }
    }

    private func namesLine(_ title: String, _ names: [String], showsAmounts: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundStyle(Theme.textSecondary)
            Text(shortList(names))
                .font(.subheadline)
                .foregroundStyle(Theme.textPrimary)
                .privacySensitive(showsAmounts)
        }
    }

    /// "+$9,000" for an asset; "owe $800 less" for a debt.
    private func detail(for item: ItemChange) -> String {
        let difference = item.current - item.previous
        if item.isAsset {
            return signed(difference)
        }
        return difference < 0 ? "owe \(money(-difference)) less" : "owe \(money(difference)) more"
    }
}

// MARK: - Overall Insights Card

/// Progress across every year with data: total and average change, the best and weakest
/// years, and which categories drove the change.
struct OverallInsightsCard: View {
    var viewModel: NetWorthViewModel

    private func money(_ amount: Int) -> String {
        amount.formatted(.currency(code: viewModel.currencyCode).precision(.fractionLength(0)))
    }

    private func signed(_ amount: Int) -> String {
        InsightsEngine.signed(amount) { money($0) }
    }

    var body: some View {
        let thisYear = Calendar.current.component(.year, from: .now)
        if let insights = InsightsEngine.overall(items: viewModel.insightItems, throughYear: thisYear) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 8) {
                    Image(systemName: "lightbulb.fill")
                        .foregroundStyle(.yellow)
                    Text("Your progress since \(String(insights.firstYear))")
                        .font(.headline)
                        .foregroundStyle(Theme.textPrimary)
                }

                HStack(alignment: .top) {
                    stat("Total change", value: insights.totalChange)
                    Spacer()
                    stat("Average per year", value: insights.averageYearlyChange)
                }

                stepLine("Best year", insights.bestStep)

                if insights.worstStep.year != insights.bestStep.year {
                    stepLine(insights.worstStep.change < 0 ? "Toughest year" : "Slowest year", insights.worstStep)
                }

                if !insights.categoryDrivers.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("What drove it")
                            .font(.caption)
                            .foregroundStyle(Theme.textSecondary)

                        ForEach(insights.categoryDrivers) { category in
                            HStack {
                                Text(category.name)
                                    .font(.subheadline)
                                    .foregroundStyle(Theme.textPrimary)
                                Spacer()
                                Text(detail(for: category))
                                    .font(.subheadline)
                                    .bold()
                                    .foregroundStyle(effectColor(category.netWorthEffect))
                                    .privacySensitive()
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Theme.cardBackground)
            .clipShape(.rect(cornerRadius: 16))
        }
    }

    private func stat(_ title: String, value: Int) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundStyle(Theme.textSecondary)
            Text(signed(value))
                .font(.title3)
                .bold()
                .foregroundStyle(effectColor(value))
                .privacySensitive()
        }
    }

    private func stepLine(_ title: String, _ step: YearStep) -> some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
            Spacer()
            Text("\(String(step.year)): \(signed(step.change)) vs \(String(step.previousYear))")
                .font(.subheadline)
                .foregroundStyle(Theme.textPrimary)
                .privacySensitive()
        }
    }

    /// "+$40,000" for an asset category; "debt down $12,000" for a debt category.
    private func detail(for category: CategoryChange) -> String {
        let difference = category.current - category.previous
        if category.isAsset {
            return signed(difference)
        }
        return "debt \(difference < 0 ? "down" : "up") \(money(abs(difference)))"
    }
}

// MARK: - Helpers

private func effectColor(_ effect: Int) -> Color {
    if effect > 0 { return Theme.positiveAmount }
    if effect < 0 { return Theme.negativeAmount }
    return Theme.textSecondary
}

/// Up to three names joined naturally, e.g. "Car loan, Visa, and 2 more".
private func shortList(_ names: [String]) -> String {
    let shown = Array(names.prefix(3))
    let hidden = names.count - shown.count
    return (hidden > 0 ? shown + ["\(hidden) more"] : shown).formatted(.list(type: .and))
}
