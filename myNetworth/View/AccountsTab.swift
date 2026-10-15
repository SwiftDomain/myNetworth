//
//  AccountsTab.swift
//  myNetworth
//

import SwiftUI

// MARK: - Accounts Tab

/// The sheets the Accounts tab can open.
private enum AccountsSheet: Identifiable {
    case addYear
    case addItem(ItemType, year: Int)
    case updateBalances(year: Int)

    var id: String {
        switch self {
        case .addYear: "addYear"
        case .addItem(let type, let year): "addItem-\(type.rawValue)-\(year)"
        case .updateBalances(let year): "updateBalances-\(year)"
        }
    }
}

/// This year's assets and debts at their latest amounts, and every year in History.
struct AccountsTab: View {
    var viewModel: NetWorthViewModel
    @State private var path = NavigationPath()
    @State private var sheet: AccountsSheet?
    @State private var newYear = Calendar.current.component(.year, from: .now)
    @State private var yearPendingDeletion: Int?
    @State private var showingDeleteYearConfirmation = false

    /// The latest tracked year that isn't in the future, or the earliest planned year.
    private var currentYear: Int? {
        let thisYear = Calendar.current.component(.year, from: .now)
        return viewModel.years.first { $0 <= thisYear } ?? viewModel.years.last
    }

    private var currency: IntegerFormatStyle<Int>.Currency {
        .currency(code: viewModel.currencyCode).precision(.fractionLength(0))
    }

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                Background(bgColor1: Theme.mainGradient1, bgColor2: Theme.mainGradient2)

                ScrollView {
                    VStack(spacing: 28) {
                        if let currentYear {
                            accounts(in: currentYear)
                            history
                        } else {
                            EmptyStateView(
                                icon: "calendar",
                                message: "No years added yet",
                                subMessage: "Add a year to start tracking your net worth"
                            )
                            .padding(.top, 60)

                            Button("Add Year", systemImage: "calendar.badge.plus") {
                                sheet = .addYear
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Accounts")
            // The backgrounds are dark in every appearance, so keep the bar text light.
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    HideAmountsButton()
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Add Year", systemImage: "calendar.badge.plus") {
                        sheet = .addYear
                    }
                }
            }
            .navigationDestination(for: Int.self) { year in
                YearDetailView(viewModel: viewModel, year: year)
            }
            .sheet(item: $sheet) { sheet in
                switch sheet {
                case .addYear:
                    AddYearView(viewModel: viewModel, newYear: $newYear) { addedYear in
                        path.append(addedYear)
                    }
                case .addItem(let type, let year):
                    AddItemView(viewModel: viewModel, type: type, year: year)
                case .updateBalances(let year):
                    UpdateBalancesView(viewModel: viewModel, year: year)
                }
            }
            .confirmationDialog(
                "Delete this year?",
                isPresented: $showingDeleteYearConfirmation,
                titleVisibility: .visible,
                presenting: yearPendingDeletion
            ) { year in
                Button("Delete \(String(year))", role: .destructive) {
                    viewModel.deleteYear(year)
                }
            } message: { year in
                Text("Every asset and liability recorded for \(String(year)) will be permanently deleted.")
            }
        }
    }

    // MARK: Accounts

    @ViewBuilder
    private func accounts(in year: Int) -> some View {
        let entries = viewModel.latestEntries(in: year)
        let assets = entries.filter { $0.itemType == "asset" }
        let debts = entries.filter { $0.itemType == "liability" }
        let totals = viewModel.getYearData(for: year)

        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(String(year))
                        .font(.title)
                        .bold()
                        .foregroundStyle(Theme.textPrimary)

                    Text("Net worth \(totals.netWorth, format: currency)")
                        .font(.subheadline)
                        .foregroundStyle(Theme.textSecondary)
                        .privacySensitive()
                }

                Spacer()

                Menu {
                    Button("Add Asset", systemImage: "dollarsign.circle") {
                        sheet = .addItem(.asset, year: year)
                    }
                    Button("Add Debt", systemImage: "creditcard") {
                        sheet = .addItem(.liability, year: year)
                    }
                } label: {
                    Label("Add", systemImage: "plus.circle.fill")
                        .labelStyle(.iconOnly)
                        .font(.title)
                }
            }

            if !viewModel.yearlyItems(in: year).isEmpty {
                Button {
                    sheet = .updateBalances(year: year)
                } label: {
                    Label("Update Balances", systemImage: "arrow.triangle.2.circlepath")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }

            if entries.isEmpty {
                EmptyStateView(
                    icon: "tray",
                    message: "No accounts in \(year) yet",
                    subMessage: "Tap + to add what you own and owe"
                )
                .padding(.vertical, 20)
            }

            if !assets.isEmpty {
                sectionHeader("Assets", total: totals.assets, color: Theme.positiveAmount)
                ForEach(assets) { item in
                    FinancialItemCard(viewModel: viewModel, item: item, type: .asset) {
                        viewModel.deleteItem(item)
                    }
                }
            }

            if !debts.isEmpty {
                sectionHeader("Debts", total: totals.liabilities, color: Theme.negativeAmount)
                ForEach(debts) { item in
                    FinancialItemCard(viewModel: viewModel, item: item, type: .liability) {
                        viewModel.deleteItem(item)
                    }
                }
            }

            if !entries.isEmpty {
                NavigationLink(value: year) {
                    Label("\(String(year)) details and monthly entries", systemImage: "chart.pie.fill")
                        .font(.subheadline)
                }
            }
        }
    }

    private func sectionHeader(_ title: String, total: Int, color: Color) -> some View {
        HStack {
            Text(title)
                .font(.headline)
                .foregroundStyle(Theme.textPrimary)

            Spacer()

            Text(total, format: currency)
                .font(.headline)
                .foregroundStyle(color)
                .privacySensitive()
        }
        .padding(.top, 4)
    }

    // MARK: History

    private var history: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("History")
                .font(.title2)
                .bold()
                .foregroundStyle(Theme.textPrimary)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                ForEach(viewModel.years, id: \.self) { year in
                    NavigationLink(value: year) {
                        YearCard(
                            viewModel: viewModel,
                            year: year,
                            data: viewModel.getYearData(for: year)
                        )
                    }
                    .contextMenu {
                        Button(role: .destructive) {
                            yearPendingDeletion = year
                            showingDeleteYearConfirmation = true
                        } label: {
                            Label("Delete Year", systemImage: "trash")
                        }
                    }
                }
            }
        }
    }
}
