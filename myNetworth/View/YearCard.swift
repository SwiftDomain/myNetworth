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
                    .privacySensitive()

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
                        .privacySensitive()
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(yearLiabilities.count) Liabilities")
                        .font(.caption2)
                        .foregroundStyle(Theme.textPrimary)

                    Text(data.liabilities, format: .currency(code: viewModel.currencyCode).precision(.fractionLength(0)))
                        .font(.caption2)
                        .foregroundStyle(Theme.negativeAmount)
                        .privacySensitive()
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

// MARK: - Year Detail View

/// The parts of a year, picked with the segmented control at the top of the year screen.
enum YearSection: String, CaseIterable, Identifiable {
    case summary = "Summary"
    case assets = "Assets"
    case liabilities = "Debts"
    case monthly = "Monthly"
    case all = "All"

    var id: Self { self }
}

struct YearDetailView: View {
    var viewModel: NetWorthViewModel
    let year: Int
    @State private var section: YearSection
    @State private var showingAddSheet = false

    init(viewModel: NetWorthViewModel, year: Int, initialSection: YearSection = .summary) {
        self.viewModel = viewModel
        self.year = year
        _section = State(initialValue: initialSection)
    }

    var body: some View {
        Group {
            switch section {
            case .summary:
                YearSummaryView(viewModel: viewModel, year: year)
            case .assets:
                AssetsView(viewModel: viewModel, year: year)
            case .liabilities:
                LiabilitiesView(viewModel: viewModel, year: year)
            case .monthly:
                MonthlyBreakdownView(viewModel: viewModel, year: year)
            case .all:
                AllItemsView(viewModel: viewModel, year: year)
            }
        }
        // A segmented control rather than a tab bar, since the app's tab bar is already showing.
        .safeAreaInset(edge: .top, spacing: 0) {
            Picker("Section", selection: $section) {
                ForEach(YearSection.allCases) { section in
                    Text(section.rawValue).tag(section)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(.bar)
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
                if section == .assets || section == .liabilities {
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
                type: section == .assets ? .asset : .liability,
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
    @State private var startFromPreviousYear = true

    /// The year the new year can start from, if any.
    private var sourceYear: Int? {
        viewModel.years.contains(newYear) ? nil : viewModel.carryForwardSource(for: newYear)
    }

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

                        if let sourceYear {
                            let itemCount = viewModel.latestEntries(in: sourceYear).count
                            Toggle(isOn: $startFromPreviousYear) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Start with \(String(sourceYear))'s items")
                                        .font(.headline)
                                        .foregroundStyle(Theme.textPrimary)
                                    Text("Copies \(itemCount) \(itemCount == 1 ? "item" : "items") at their latest amounts, so you only update what changed.")
                                        .font(.caption)
                                        .foregroundStyle(Theme.textSecondary)
                                }
                            }
                            .tint(.blue)
                            .padding()
                            .background(Theme.cardBackground)
                            .clipShape(.rect(cornerRadius: 12))
                        }
                    }
                    .padding(.horizontal)

                    Spacer()

                    Button {
                        let yearToAdd = newYear
                        let copyFrom = startFromPreviousYear ? sourceYear : nil
                        viewModel.addYear(yearToAdd, copyingItemsFrom: copyFrom)
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
    @State private var showingUpdateBalances = false

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
                    // Update Balances
                    if !viewModel.yearlyItems(in: year).isEmpty {
                        Button {
                            showingUpdateBalances = true
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                    .font(.title2)
                                    .foregroundStyle(.blue)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Update Balances")
                                        .font(.headline)
                                        .foregroundStyle(Theme.textPrimary)
                                    Text("Go through each item and keep or change its amount")
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

                    // What Changed (shown when an earlier year has data)
                    WhatChangedCard(viewModel: viewModel, year: year)

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
                        .privateChartAxis()
                    }
                    .padding()
                    .background(Theme.subtleBackground)
                    .clipShape(.rect(cornerRadius: 16))
                }
                .padding()
            }
        }
        .sheet(isPresented: $showingUpdateBalances) {
            UpdateBalancesView(viewModel: viewModel, year: year)
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
                .privacySensitive()
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

    private var data: [MonthlyBalance] {
        viewModel.monthlyData(for: year)
    }

    /// The last month with entries, whose balances are the year's latest.
    private var latest: MonthlyBalance? {
        data.last { $0.hasEntries }
    }

    var body: some View {
        ZStack {
            Background(bgColor1: Theme.mainGradient1, bgColor2: Theme.mainGradient2)

            ScrollView {
                VStack(spacing: 20) {
                    if let latest {
                        // Latest balances. Balances aren't added up across months: each month
                        // already includes every account at its latest amount.
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Latest Balances")
                                .font(.headline)
                                .foregroundStyle(Theme.textPrimary)

                            Text("As of \(Calendar.current.monthSymbols[latest.month - 1])")
                                .font(.caption)
                                .foregroundStyle(Theme.textSecondary)

                            HStack {
                                VStack(alignment: .leading) {
                                    Text("Total Assets")
                                        .font(.caption)
                                        .foregroundStyle(Theme.textSecondary)
                                    Text(latest.assets, format: .currency(code: viewModel.currencyCode).precision(.fractionLength(0)))
                                        .bold()
                                        .foregroundStyle(Theme.positiveAmount)
                                        .privacySensitive()
                                }

                                Spacer()

                                VStack(alignment: .trailing) {
                                    Text("Total Liabilities")
                                        .font(.caption)
                                        .foregroundStyle(Theme.textSecondary)
                                    Text(latest.liabilities, format: .currency(code: viewModel.currencyCode).precision(.fractionLength(0)))
                                        .bold()
                                        .foregroundStyle(Theme.negativeAmount)
                                        .privacySensitive()
                                }
                            }

                            Divider().background(Color.white.opacity(0.3))

                            HStack {
                                Text("Net Worth")
                                    .font(.caption)
                                    .foregroundStyle(Theme.textSecondary)
                                Spacer()
                                Text(latest.netWorth, format: .currency(code: viewModel.currencyCode).precision(.fractionLength(0)))
                                    .bold()
                                    .foregroundStyle(latest.netWorth >= 0 ? Theme.positiveAmount : Theme.negativeAmount)
                                    .privacySensitive()
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

                            let chartData = data.filter(\.hasEntries)
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
                                .privateChartAxis()
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
                            let hasData = item.hasEntries

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
                                            .privacySensitive()
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
                                            .privacySensitive()

                                        Spacer()

                                        Text("L: \(item.liabilities, format: .currency(code: viewModel.currencyCode).precision(.fractionLength(0)))")
                                            .font(.caption)
                                            .foregroundStyle(Theme.negativeAmount)
                                            .privacySensitive()
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
