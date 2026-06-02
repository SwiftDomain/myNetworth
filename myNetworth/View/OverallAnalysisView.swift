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
                        // Net Worth Trend Chart
                        NetWorthChartView(
                            data: viewModel.yearlyData,
                            currencyCode: viewModel.currencyCode
                        )

                        // Assets vs Liabilities Chart
                        ComparisonChartView(
                            data: viewModel.yearlyData,
                            currencyCode: viewModel.currencyCode
                        )

                        // Debt Payoff Section
                        NavigationLink {
                            DebtPayoffView(viewModel: viewModel)
                        } label: {
                            HStack {
                                Image(systemName: "chart.line.downtrend.xyaxis")
                                    .foregroundStyle(.blue)
                                Text("Debt Payoff Projections")
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
                                        }

                                        Spacer()

                                        VStack(alignment: .trailing) {
                                            Text("Liabilities")
                                                .font(.caption)
                                                .foregroundStyle(Theme.textSecondary)
                                            Text(data.liabilities, format: .currency(code: viewModel.currencyCode).precision(.fractionLength(0)))
                                                .font(.subheadline)
                                                .foregroundStyle(Theme.negativeAmount)
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

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Net Worth Over Time")
                .font(.headline)
                .foregroundStyle(Theme.textPrimary)

            Chart(data) { item in
                LineMark(
                    x: .value("Year", item.year),
                    y: .value("Net Worth", item.netWorth)
                )
                .foregroundStyle(.blue)
                .lineStyle(StrokeStyle(lineWidth: 3))

                PointMark(
                    x: .value("Year", item.year),
                    y: .value("Net Worth", item.netWorth)
                )
                .foregroundStyle(.blue)
            }
            .frame(height: 250)
            .chartXAxis {
                AxisMarks { _ in
                    AxisGridLine()
                    AxisValueLabel()
                        .foregroundStyle(.white)
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { _ in
                    AxisGridLine()
                    AxisValueLabel()
                        .foregroundStyle(.white)
                }
            }
        }
        .padding()
        .background(Theme.cardBackground)
        .clipShape(.rect(cornerRadius: 16))
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
                    x: .value("Year", item.year),
                    yStart: .value("Amount", 0),
                    yEnd: .value("Amount", item.value),
                    width: .ratio(item.isBack ? 0.8 : 0.4)
                )
                .foregroundStyle(by: .value("category", item.category))
            }
            .frame(height: 250)
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
            .chartForegroundStyleScale([
                "Assets": .green,
                "Liabilities": .red,
            ])
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
                Goal.self, RecurringItem.self, Milestone.self, CustomCategory.self,
                configurations: ModelConfiguration(isStoredInMemoryOnly: true)
            ).mainContext)
        )
    }
}
