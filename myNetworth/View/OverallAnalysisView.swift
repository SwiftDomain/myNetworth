//
//  OverallAnalysisView.swift
//  myNetworth
//
//  Created by BeastMode on 12/5/25.
//

import SwiftUI
import SwiftData
import Charts

// MARK: - Overall Analysis View

struct OverallAnalysisView: View {
    var viewModel: NetWorthViewModel

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Theme.mainGradient1, Theme.mainGradient2],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    if viewModel.yearlyData.isEmpty {
                        EmptyStateView(
                            icon: "chart.bar",
                            message: "No data to analyze",
                            subMessage: "Add assets and liabilities to see insights"
                        )
                        .padding(.top, 100)
                    } else {
                        // Insights (shown when at least two years have data)
                        OverallInsightsCard(viewModel: viewModel)

                        // Net Worth Trend Chart
                        NetWorthChartView(
                            data: viewModel.yearlyData,
                            currencyCode: viewModel.currencyCode,
                            projection: viewModel.netWorthProjection
                        )

                        // Assets vs Liabilities Chart
                        ComparisonChartView(
                            data: viewModel.yearlyData,
                            currencyCode: viewModel.currencyCode
                        )

                        // Debt Payoff Planner
                        NavigationLink {
                            DebtPayoffView(viewModel: viewModel)
                        } label: {
                            HStack {
                                Image(systemName: "chart.line.downtrend.xyaxis")
                                    .foregroundStyle(.blue)
                                Text("Debt Payoff Planner")
                                    .font(.headline)
                                    .foregroundStyle(Theme.textPrimary)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundStyle(Theme.textSecondary)
                            }
                            .padding()
                            .background(Theme.cardBackground)
                            .clipShape(.rect(cornerRadius: 12))
                        }

                        // Year-by-Year Breakdown
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Year-by-Year Breakdown")
                                .font(.headline)
                                .foregroundStyle(Theme.textPrimary)

                            ForEach(viewModel.yearlyData.reversed()) { data in
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Text("\(data.year)")
                                            .font(.title3)
                                            .bold()
                                            .foregroundStyle(Theme.textPrimary)

                                        Spacer()

                                        if let change = viewModel.percentageChange(for: data.year) {
                                            HStack(spacing: 2) {
                                                Image(systemName: change >= 0 ? "arrow.up.right" : "arrow.down.right")
                                                Text(abs(change), format: .number.precision(.fractionLength(1)))
                                                Text("%")
                                            }
                                            .font(.caption)
                                            .foregroundStyle(change >= 0 ? Theme.positiveAmount : Theme.negativeAmount)
                                        }
                                    }

                                    HStack {
                                        VStack(alignment: .leading) {
                                            Text("Assets")
                                                .font(.caption)
                                                .foregroundStyle(Theme.textSecondary)
                                            Text(data.assets, format: .currency(code: viewModel.currencyCode).precision(.fractionLength(0)))
                                                .font(.subheadline)
                                                .foregroundStyle(Theme.positiveAmount)
                                                .privacySensitive()
                                        }

                                        Spacer()

                                        VStack(alignment: .trailing) {
                                            Text("Liabilities")
                                                .font(.caption)
                                                .foregroundStyle(Theme.textSecondary)
                                            Text(data.liabilities, format: .currency(code: viewModel.currencyCode).precision(.fractionLength(0)))
                                                .font(.subheadline)
                                                .foregroundStyle(Theme.negativeAmount)
                                                .privacySensitive()
                                        }

                                        Spacer()

                                        VStack(alignment: .trailing) {
                                            Text("Net Worth")
                                                .font(.caption)
                                                .foregroundStyle(Theme.textSecondary)
                                            Text(data.netWorth, format: .currency(code: viewModel.currencyCode).precision(.fractionLength(0)))
                                                .font(.subheadline)
                                                .bold()
                                                .foregroundStyle(.blue)
                                                .privacySensitive()
                                        }
                                    }
                                }
                                .padding()
                                .background(Theme.cardBackground)
                                .clipShape(.rect(cornerRadius: 12))
                            }
                        }
                        .padding()
                        .background(Theme.subtleBackground)
                        .clipShape(.rect(cornerRadius: 16))
                    }
                }
                .padding()
            }
        }
        .navigationTitle("Overall Analysis")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Net Worth Chart

struct NetWorthChartView: View {
    let data: [YearlyData]
    var currencyCode: String = "USD"
    /// "Future you": drawn as a dashed line and listed under the chart.
    var projection: NetWorthProjection?

    private var currency: IntegerFormatStyle<Int>.Currency {
        .currency(code: currencyCode).precision(.fractionLength(0))
    }

    /// From the first tracked year to the furthest projected one. Years are numbers rather
    /// than labels so that 5, 10 and 20 years ahead are spaced in proportion.
    private var yearRange: ClosedRange<Int> {
        let years = data.map(\.year) + (projection?.points.map(\.year) ?? [])
        let first = years.min() ?? 0
        return first...max(years.max() ?? first, first + 1)
    }

    /// About five evenly spaced years to label.
    private var axisYears: [Int] {
        let span = yearRange.upperBound - yearRange.lowerBound
        let step = max(1, Int((Double(span) / 4).rounded(.up)))
        return Array(stride(from: yearRange.lowerBound, through: yearRange.upperBound, by: step))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Net Worth Over Time")
                .font(.headline)
                .foregroundStyle(Theme.textPrimary)

            Chart {
                ForEach(data) { item in
                    LineMark(
                        x: .value("Year", item.year),
                        y: .value("Net Worth", item.netWorth),
                        series: .value("Line", "Net worth")
                    )
                    .foregroundStyle(.blue)
                    .lineStyle(StrokeStyle(lineWidth: 3))

                    PointMark(
                        x: .value("Year", item.year),
                        y: .value("Net Worth", item.netWorth)
                    )
                    .foregroundStyle(.blue)
                }

                if let projection {
                    ForEach(projection.points) { point in
                        LineMark(
                            x: .value("Year", point.year),
                            y: .value("Net Worth", point.netWorth),
                            series: .value("Line", "Future you")
                        )
                        .foregroundStyle(.purple)
                        .lineStyle(StrokeStyle(lineWidth: 2, dash: [6, 4]))
                    }

                    ForEach(projection.points.dropFirst()) { point in
                        PointMark(
                            x: .value("Year", point.year),
                            y: .value("Net Worth", point.netWorth)
                        )
                        .foregroundStyle(.purple)
                    }
                }
            }
            .frame(height: 250)
            .chartXScale(domain: yearRange)
            .chartXAxis {
                AxisMarks(values: axisYears) { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let year = value.as(Int.self) {
                            Text(String(year))
                                .foregroundStyle(.white)
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { _ in
                    AxisGridLine()
                    AxisValueLabel()
                        .foregroundStyle(.white)
                }
            }
            .privateChartAxis()

            if let projection {
                futureYou(projection)
            }
        }
        .padding()
        .background(Theme.cardBackground)
        .clipShape(.rect(cornerRadius: 16))
    }

    private func futureYou(_ projection: NetWorthProjection) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .foregroundStyle(.purple)
                Text("Future you")
                    .font(.subheadline)
                    .bold()
                    .foregroundStyle(Theme.textPrimary)
            }

            HStack(alignment: .top) {
                ForEach(NetWorthProjection.horizons, id: \.self) { years in
                    VStack(alignment: .leading, spacing: 2) {
                        Text("In \(years) years")
                            .font(.caption)
                            .foregroundStyle(Theme.textSecondary)
                        Text(projection.netWorth(inYears: years), format: currency)
                            .font(.subheadline)
                            .bold()
                            .foregroundStyle(Theme.textPrimary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .privacySensitive()
                        Text(String(projection.baseYear + years))
                            .font(.caption2)
                            .foregroundStyle(Theme.textSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            let change = projection.averageYearlyChange
            Text("If your net worth keeps \(change >= 0 ? "growing" : "falling") by \(abs(change), format: currency) a year, your average since \(String(projection.firstYear)).")
                .font(.caption)
                .foregroundStyle(Theme.textSecondary)
                .privacySensitive()
        }
    }
}

// MARK: - Comparison Chart

struct ComparisonChartView: View {
    let data: [YearlyData]
    var currencyCode: String = "USD"

    private struct BarEntry: Identifiable {
        let id: String
        let year: Int
        let category: String
        let value: Int
        /// The taller of the two bars for a year, drawn first (behind) and wider.
        let isBack: Bool
    }

    // The tracked years, ascending, as category labels for the x-axis. Using a
    // categorical (String) axis lets the two bars per year share a band without
    // collapsing to zero width, and bounds the axis to the min…max entered year.
    private var yearLabels: [String] {
        data.map(\.year).sorted().map(String.init)
    }

    // For each year, emit the taller bar first so it draws behind the shorter one.
    private var chartData: [BarEntry] {
        data.flatMap { item -> [BarEntry] in
            let pair = [
                (category: "Assets", value: item.assets),
                (category: "Liabilities", value: item.liabilities),
            ]
            .sorted { $0.value > $1.value }

            return pair.enumerated().map { index, element in
                BarEntry(
                    id: "\(item.year)-\(element.category)",
                    year: item.year,
                    category: element.category,
                    value: element.value,
                    isBack: index == 0
                )
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Assets vs Liabilities")
                .font(.headline)
                .foregroundStyle(Theme.textPrimary)

            Chart(chartData) { item in
                BarMark(
                    x: .value("Year", String(item.year)),
                    yStart: .value("Amount", 0),
                    yEnd: .value("Amount", item.value),
                    width: .ratio(item.isBack ? 0.55 : 0.3)
                )
                .foregroundStyle(item.category == "Assets" ? Color.green : Color.red)
            }
            .frame(height: 250)
            .chartXScale(domain: yearLabels)
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisGridLine()
                        .foregroundStyle(.white.opacity(0.2))
                    AxisValueLabel {
                        if let intValue = value.as(Int.self) {
                            Text(formatNumber(intValue))
                                .foregroundStyle(.white)
                                .font(.caption)
                        }
                    }
                }
            }
            .chartXAxis {
                AxisMarks { _ in
                    AxisValueLabel()
                        .foregroundStyle(.white)
                }
            }
            .chartLegend(position: .bottom) {
                HStack(spacing: 16) {
                    ForEach(["Assets", "Liabilities"], id: \.self) { category in
                        HStack(spacing: 6) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(category == "Assets" ? Color.green : Color.red)
                                .frame(width: 8, height: 8)

                            Text(category)
                                .foregroundStyle(Theme.textPrimary)
                                .font(.footnote)
                        }
                    }
                }
                .padding(.vertical, 8)
            }
            .privateChartAxis()
        }
        .padding()
        .background(Theme.cardBackground)
        .clipShape(.rect(cornerRadius: 16))
    }
}

#Preview {
    NavigationStack {
        OverallAnalysisView(
            viewModel: NetWorthViewModel(modelContext: try! ModelContainer(
                for: FinancialItem.self, TrackedYear.self, UserSettings.self,
                Goal.self, RecurringItem.self, Milestone.self, CustomCategory.self, DebtTerms.self,
                configurations: ModelConfiguration(isStoredInMemoryOnly: true)
            ).mainContext)
        )
    }
}
