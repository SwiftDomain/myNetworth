//
//  YearCard.swift
//  myNetworth
//
//  Created by BeastMode on 12/5/25.
//

import SwiftUI
import SwiftData
import Charts

// MARK: - Year Card

struct YearCard: View {

    var viewModel: NetWorthViewModel
    let year: Int
    let data: YearlyData

    private var yearAssets: [FinancialItem] {
        viewModel.assets.filter { $0.year == year }
    }

    private var yearLiabilities: [FinancialItem] {
        viewModel.liabilities.filter { $0.year == year }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "calendar")
                    .font(.title2)
                    .foregroundStyle(.blue.opacity(0.8))

                Spacer()

                Text("\(year, format: .number.grouping(.never))")
                    .font(.title)
                    .bold()
                    .foregroundStyle(.blue)
            }

            Divider()
                .background(Color.white.opacity(0.3))

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Net Worth")
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                    Spacer()
                }

                Text(data.netWorth, format: .currency(code: viewModel.currencyCode).precision(.fractionLength(0)))
                    .font(.title2)
                    .bold()
                    .foregroundStyle(data.netWorth >= 0 ? Theme.positiveAmount : Theme.negativeAmount)

                // Percentage change badge
                if let change = viewModel.percentageChange(for: year) {
                    HStack(spacing: 4) {
                        Image(systemName: change >= 0 ? "arrow.up.right" : "arrow.down.right")
                        Text(abs(change), format: .number.precision(.fractionLength(1)))
                        Text("%")
                    }
                    .font(.caption2)
                    .foregroundStyle(change >= 0 ? Theme.positiveAmount : Theme.negativeAmount)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background((change >= 0 ? Theme.positiveAmount : Theme.negativeAmount).opacity(0.2))
                    .clipShape(.rect(cornerRadius: 6))
                }
            }

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(yearAssets.count) Assets")
                        .font(.caption2)
                        .foregroundStyle(Theme.textPrimary)

                    Text(data.assets, format: .currency(code: viewModel.currencyCode).precision(.fractionLength(0)))
                        .font(.caption2)
                        .foregroundStyle(Theme.positiveAmount)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(yearLiabilities.count) Liabilities")
                        .font(.caption2)
                        .foregroundStyle(Theme.textPrimary)

                    Text(data.liabilities, format: .currency(code: viewModel.currencyCode).precision(.fractionLength(0)))
                        .font(.caption2)
                        .foregroundStyle(Theme.negativeAmount)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Theme.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Theme.cardBorder, lineWidth: 1)
                )
        )
    }
}

// MARK: - Year Detail View (with Tabs)

struct YearDetailView: View {
    var viewModel: NetWorthViewModel
    @State private var selectedTab = 0
    @State private var showingAddSheet = false

    let year: Int

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Summary", systemImage: "chart.pie.fill", value: 0) {
                YearSummaryView(viewModel: viewModel, year: year)
            }

            Tab("Assets", systemImage: "dollarsign.circle.fill", value: 1) {
                AssetsView(viewModel: viewModel, year: year)
            }

            Tab("Liabilities", systemImage: "creditcard.fill", value: 2) {
                LiabilitiesView(viewModel: viewModel, year: year)
            }

            Tab("Monthly", systemImage: "calendar.badge.clock", value: 3) {
                MonthlyBreakdownView(viewModel: viewModel, year: year)
            }

            Tab("All", systemImage: "list.bullet", value: 4) {
                AllItemsView(viewModel: viewModel, year: year)
            }
        }
        .navigationTitle("\(year, format: .number.grouping(.never))")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("\(year, format: .number.grouping(.never))")
                    .font(.title3)
                    .bold()
                    .foregroundStyle(.blue)
            }

            ToolbarItem(placement: .navigationBarTrailing) {
                if selectedTab == 1 || selectedTab == 2 {
                    Button("Add Item", systemImage: "plus.circle.fill") {
                        showingAddSheet = true
                    }
                    .foregroundStyle(.blue)
                }
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            AddItemView(
                viewModel: viewModel,
                type: selectedTab == 1 ? .asset : .liability,
                year: year
            )
        }
    }
}

// MARK: - Add Year View

struct AddYearView: View {

    var viewModel: NetWorthViewModel
    @Binding var newYear: Int
    var onYearAdded: ((Int) -> Void)?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.05, green: 0.1, blue: 0.2)
                    .ignoresSafeArea()

                VStack(spacing: 30) {
                    Image(systemName: "calendar.badge.plus")
                        .font(.system(size: 80))
                        .foregroundStyle(.blue.opacity(0.8))

                    Text("Add New Year")
                        .font(.title)
                        .bold()
                        .foregroundStyle(Theme.textPrimary)

                    VStack(spacing: 16) {
                        ScrollableYearPicker(newYear: $newYear)

                        if viewModel.years.contains(newYear) {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(.orange)
                                Text("This year already exists")
                                    .font(.caption)
                                    .foregroundStyle(.orange)
                            }
                        }
                    }
                    .padding(.horizontal)

                    Spacer()

                    Button {
                        let yearToAdd = newYear
                        viewModel.addYear(yearToAdd)
                        dismiss()
                        onYearAdded?(yearToAdd)
                    } label: {
                        Text("Add Year")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                LinearGradient(
                                    colors: [.blue, .blue.opacity(0.8)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .clipShape(.rect(cornerRadius: 12))
                    }
                    .disabled(viewModel.years.contains(newYear))
                    .opacity(viewModel.years.contains(newYear) ? 0.5 : 1)
                    .padding(.horizontal)
                }
                .padding()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(.blue)
                }
            }
        }
    }
}

// MARK: - Scrollable Year Picker

struct ScrollableYearPicker: View {

    @Binding var newYear: Int

    private let years: [Int] = {
        let currentYear = Calendar.current.component(.year, from: Date())
        return Array((currentYear - 20)...(currentYear + 10))
    }()

    var body: some View {
        VStack(spacing: 24) {
            Text("\(newYear)")
                .font(.largeTitle)
                .bold()
                .foregroundStyle(.blue)

            ScrollViewReader { proxy in
                ScrollView(.horizontal) {
                    HStack(spacing: 12) {
                        ForEach(years, id: \.self) { year in
                            Button {
                                withAnimation {
                                    newYear = year
                                }
                            } label: {
                                Text(String(year))
                                    .font(.headline)
                                    .foregroundStyle(newYear == year ? .white : .gray)
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 12)
                                    .background(
                                        RoundedRectangle(cornerRadius: 10)
                                            .fill(newYear == year ? Color.blue : Color.clear)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 10)
                                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                            )
                                    )
                            }
                            .id(year)
                        }
                    }
                    .padding()
                }
                .scrollIndicators(.hidden)
                .onAppear {
                    proxy.scrollTo(newYear, anchor: .center)
                }
            }
        }
    }
}

// MARK: - Year Summary View

struct YearSummaryView: View {

    var viewModel: NetWorthViewModel
    let year: Int

    private var yearData: YearlyData {
        viewModel.getYearData(for: year)
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Theme.summaryGradient1, Theme.summaryGradient2],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    // Summary Cards
                    VStack(spacing: 20) {
                        SummaryCard(
                            title: "Net Worth",
                            amount: yearData.netWorth,
                            currencyCode: viewModel.currencyCode,
                            itemType: "Networth",
                            isLarge: true
                        )

                        HStack(spacing: 12) {
                            SummaryCard(
                                title: "Assets",
                                amount: yearData.assets,
                                currencyCode: viewModel.currencyCode,
                                itemType: "assets",
                                isLarge: false
                            )

                            SummaryCard(
                                title: "Liabilities",
                                amount: yearData.liabilities,
                                currencyCode: viewModel.currencyCode,
                                itemType: "liabilities",
                                isLarge: false
                            )
                        }
                    }
                    .padding()
                    .background(Theme.subtleBackground)
                    .clipShape(.rect(cornerRadius: 16))

                    // Assets Breakdown
                    CategoryBreakdownTile(
                        yearData: yearData,
                        type: .asset,
                        currencyCode: viewModel.currencyCode
                    )

                    // Liabilities Breakdown
                    CategoryBreakdownTile(
                        yearData: yearData,
                        type: .liability,
                        currencyCode: viewModel.currencyCode
                    )

                    // Financial Overview Chart
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Financial Overview")
                            .font(.headline)
                            .foregroundStyle(Theme.textPrimary)

                        Chart {
                            BarMark(
                                x: .value("Type", "Assets"),
                                y: .value("Amount", yearData.assets)
                            )
                            .foregroundStyle(Theme.positiveAmount)

                            BarMark(
                                x: .value("Type", "Liabilities"),
                                y: .value("Amount", yearData.liabilities)
                            )
                            .foregroundStyle(Theme.negativeAmount)
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
                                            .font(.caption2)
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
                    }
                    .padding()
                    .background(Theme.subtleBackground)
                    .clipShape(.rect(cornerRadius: 16))
                }
                .padding()
            }
        }
    }
}

// MARK: - Summary Card

struct SummaryCard: View {
    let title: String
    let amount: Int
    let currencyCode: String
    let itemType: String
    var isLarge: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(isLarge ? .title : .callout)
                .foregroundStyle(Theme.textPrimary)

            Text(amount, format: .currency(code: currencyCode).precision(.fractionLength(0)))
                .font(isLarge ? .title : .subheadline)
                .bold()
                .foregroundStyle(amountColor)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var amountColor: Color {
        switch itemType {
        case "assets": Theme.positiveAmount
        case "liabilities": Theme.negativeAmount
        default: amount > 0 ? Theme.positiveAmount : Theme.negativeAmount
        }
    }
}

// MARK: - Monthly Breakdown View

struct MonthlyBreakdownView: View {

    var viewModel: NetWorthViewModel
    let year: Int

    private var data: [(month: Int, assets: Int, liabilities: Int, netWorth: Int)] {
        viewModel.monthlyData(for: year)
    }

    private var hasMonthlyData: Bool {
        data.contains { $0.assets > 0 || $0.liabilities > 0 }
    }

    var body: some View {
        ZStack {
            Background(bgColor1: Theme.mainGradient1, bgColor2: Theme.mainGradient2)

            ScrollView {
                VStack(spacing: 20) {
                    if hasMonthlyData {
                        // YTD Summary
                        let ytdAssets = data.reduce(0) { $0 + $1.assets }
                        let ytdLiabilities = data.reduce(0) { $0 + $1.liabilities }
                        let ytdNetWorth = ytdAssets - ytdLiabilities

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Year-to-Date Summary")
                                .font(.headline)
                                .foregroundStyle(Theme.textPrimary)

                            HStack {
                                VStack(alignment: .leading) {
                                    Text("Total Assets")
                                        .font(.caption)
                                        .foregroundStyle(Theme.textSecondary)
                                    Text(ytdAssets, format: .currency(code: viewModel.currencyCode).precision(.fractionLength(0)))
                                        .bold()
                                        .foregroundStyle(Theme.positiveAmount)
                                }

                                Spacer()

                                VStack(alignment: .trailing) {
                                    Text("Total Liabilities")
                                        .font(.caption)
                                        .foregroundStyle(Theme.textSecondary)
                                    Text(ytdLiabilities, format: .currency(code: viewModel.currencyCode).precision(.fractionLength(0)))
                                        .bold()
                                        .foregroundStyle(Theme.negativeAmount)
                                }
                            }

                            Divider().background(Color.white.opacity(0.3))

                            HStack {
                                Text("Net Worth (Monthly)")
                                    .font(.caption)
                                    .foregroundStyle(Theme.textSecondary)
                                Spacer()
                                Text(ytdNetWorth, format: .currency(code: viewModel.currencyCode).precision(.fractionLength(0)))
                                    .bold()
                                    .foregroundStyle(ytdNetWorth >= 0 ? Theme.positiveAmount : Theme.negativeAmount)
                            }
                        }
                        .padding()
                        .background(Theme.cardBackground)
                        .clipShape(.rect(cornerRadius: 12))

                        // Monthly Trend Chart
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Monthly Net Worth Trend")
                                .font(.headline)
                                .foregroundStyle(Theme.textPrimary)

                            let chartData = data.filter { $0.assets > 0 || $0.liabilities > 0 }
                            if !chartData.isEmpty {
                                Chart(chartData, id: \.month) { item in
                                    LineMark(
                                        x: .value("Month", Calendar.current.shortMonthSymbols[item.month - 1]),
                                        y: .value("Net Worth", item.netWorth)
                                    )
                                    .foregroundStyle(.blue)

                                    PointMark(
                                        x: .value("Month", Calendar.current.shortMonthSymbols[item.month - 1]),
                                        y: .value("Net Worth", item.netWorth)
                                    )
                                    .foregroundStyle(.blue)
                                }
                                .frame(height: 200)
                                .chartYAxis {
                                    AxisMarks(position: .leading) { value in
                                        AxisGridLine()
                                            .foregroundStyle(.white.opacity(0.2))
                                        AxisValueLabel()
                                            .foregroundStyle(.white)
                                    }
                                }
                                .chartXAxis {
                                    AxisMarks { _ in
                                        AxisValueLabel()
                                            .foregroundStyle(.white)
                                    }
                                }
                            }
                        }
                        .padding()
                        .background(Theme.cardBackground)
                        .clipShape(.rect(cornerRadius: 12))
                    }

                    // Monthly Breakdown List
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Monthly Breakdown")
                            .font(.headline)
                            .foregroundStyle(Theme.textPrimary)

                        ForEach(data, id: \.month) { item in
                            let monthName = Calendar.current.monthSymbols[item.month - 1]
                            let hasData = item.assets > 0 || item.liabilities > 0

                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text(monthName)
                                        .font(.subheadline)
                                        .bold()
                                        .foregroundStyle(Theme.textPrimary)

                                    Spacer()

                                    if hasData {
                                        Text(item.netWorth, format: .currency(code: viewModel.currencyCode).precision(.fractionLength(0)))
                                            .font(.subheadline)
                                            .bold()
                                            .foregroundStyle(item.netWorth >= 0 ? Theme.positiveAmount : Theme.negativeAmount)
                                    } else {
                                        Text("No data")
                                            .font(.caption)
                                            .foregroundStyle(Theme.textSecondary)
                                    }
                                }

                                if hasData {
                                    HStack {
                                        Text("A: \(item.assets, format: .currency(code: viewModel.currencyCode).precision(.fractionLength(0)))")
                                            .font(.caption)
                                            .foregroundStyle(Theme.positiveAmount)

                                        Spacer()

                                        Text("L: \(item.liabilities, format: .currency(code: viewModel.currencyCode).precision(.fractionLength(0)))")
                                            .font(.caption)
                                            .foregroundStyle(Theme.negativeAmount)
                                    }
                                }
                            }
                            .padding()
                            .background(hasData ? Theme.cardBackground : Theme.subtleBackground)
                            .clipShape(.rect(cornerRadius: 10))
                        }
                    }
                }
                .padding()
            }
        }
    }
}

// MARK: - Previews

#Preview("Year Card") {
    YearCard(
        viewModel: NetWorthViewModel(modelContext: try! ModelContainer(
            for: FinancialItem.self, TrackedYear.self, UserSettings.self,
            Goal.self, RecurringItem.self, Milestone.self, CustomCategory.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        ).mainContext),
        year: 2025,
        data: YearlyData(
            year: 2025,
            assets: 250_000,
            liabilities: 100_000,
            netWorth: 150_000,
            assetCategoryTotal: [.cash: 50_000, .investments: 200_000],
            liabilityCategoryTotal: [.mortgage: 100_000]
        )
    )
    .background(Color.black.ignoresSafeArea())
}
