//
//  AllItemsView.swift
//  myNetworth
//
//  Created by BeastMode on 12/5/25.
//

import SwiftUI
import SwiftData

// MARK: - All Items View

struct AllItemsView: View {

    var viewModel: NetWorthViewModel
    let year: Int

    private var yearAssets: [FinancialItem] {
        viewModel.filteredItems(viewModel.assets.filter { $0.year == year })
    }

    private var yearLiabilities: [FinancialItem] {
        viewModel.filteredItems(viewModel.liabilities.filter { $0.year == year })
    }

    var body: some View {
        ZStack {
            Background(bgColor1: Theme.summaryGradient1, bgColor2: Theme.summaryGradient2)

            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 20) {
                        // Quick Stats
                        HStack(spacing: 12) {
                            StatCard(
                                title: "Assets",
                                amount: viewModel.getYearData(for: year).assets,
                                currencyCode: viewModel.currencyCode,
                                color: Theme.positiveAmount
                            )

                            StatCard(
                                title: "Liabilities",
                                amount: viewModel.getYearData(for: year).liabilities,
                                currencyCode: viewModel.currencyCode,
                                color: Theme.negativeAmount
                            )
                        }

                        // Net Worth
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Net Worth")
                                .font(.caption)
                                .foregroundStyle(Theme.textSecondary)
                            Text(viewModel.getYearData(for: year).netWorth, format: .currency(code: viewModel.currencyCode).precision(.fractionLength(0)))
                                .font(.title2)
                                .bold()
                                .foregroundStyle(.blue)
                                .privacySensitive()
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(
                            LinearGradient(
                                colors: [Color.blue.opacity(0.3), Color.blue.opacity(0.4)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(.rect(cornerRadius: 12))

                        // Assets Section
                        if !yearAssets.isEmpty {
                            ItemSection(
                                viewModel: viewModel,
                                title: "Assets",
                                icon: "dollarsign.circle.fill",
                                color: Theme.positiveAmount,
                                items: yearAssets,
                                type: .asset,
                                onDelete: { viewModel.deleteAsset($0) }
                            )
                        }

                        // Liabilities Section
                        if !yearLiabilities.isEmpty {
                            ItemSection(
                                viewModel: viewModel,
                                title: "Liabilities",
                                icon: "creditcard.fill",
                                color: Theme.negativeAmount,
                                items: yearLiabilities,
                                type: .liability,
                                onDelete: { viewModel.deleteLiability($0) }
                            )
                        }

                        // Empty State
                        if yearAssets.isEmpty && yearLiabilities.isEmpty {
                            EmptyStateView(
                                icon: "tray",
                                message: "No items yet",
                                subMessage: "Add your first asset or liability for \(year)"
                            )
                            .padding(.top, 40)
                        }
                    }
                    .padding()
                }
            }
        }
        .searchable(text: Bindable(viewModel).searchText, prompt: "Search all items")
    }
}

// MARK: - Stat Card

struct StatCard: View {
    let title: String
    let amount: Int
    let currencyCode: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(Theme.textSecondary)
            Text(amount, format: .currency(code: currencyCode).precision(.fractionLength(0)))
                .font(.headline)
                .foregroundStyle(color)
                .privacySensitive()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Theme.cardBackground)
        .clipShape(.rect(cornerRadius: 12))
    }
}

// MARK: - Item Section

struct ItemSection: View {
    var viewModel: NetWorthViewModel
    let title: String
    let icon: String
    let color: Color
    let items: [FinancialItem]
    let type: ItemType
    let onDelete: (FinancialItem) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)
                Text(title)
                    .font(.headline)
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                Text("\(items.count)")
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(color.opacity(0.3))
                    .clipShape(.rect(cornerRadius: 8))
            }

            ForEach(items) { item in
                FinancialItemCard(
                    viewModel: viewModel,
                    item: item,
                    type: type,
                    onDelete: { onDelete(item) }
                )
            }
        }
    }
}

// MARK: - Financial Item Card

struct FinancialItemCard: View {
    var viewModel: NetWorthViewModel
    let item: FinancialItem
    let type: ItemType
    let onDelete: () -> Void
    @State private var showingEditSheet = false
    @State private var showingDeleteConfirmation = false

    var body: some View {
        Button {
            showingEditSheet = true
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.name)
                        .font(.headline)
                        .foregroundStyle(Theme.textPrimary)

                    HStack(spacing: 8) {
                        Text(item.category)
                            .font(.caption)
                            .foregroundStyle(Theme.textSecondary)

                        if item.month > 0 {
                            Text(Calendar.current.shortMonthSymbols[item.month - 1])
                                .font(.caption2)
                                .foregroundStyle(.blue)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.blue.opacity(0.2))
                                .clipShape(.rect(cornerRadius: 4))
                        }
                    }

                    Text(item.amount, format: .currency(code: viewModel.currencyCode).precision(.fractionLength(0)))
                        .font(.title2)
                        .bold()
                        .foregroundStyle(type == .asset ? Theme.positiveAmount : Theme.negativeAmount)
                        .privacySensitive()
                }

                Spacer()

                Button("Delete", systemImage: "trash") {
                    showingDeleteConfirmation = true
                }
                .foregroundStyle(.red.opacity(0.8))
                .labelStyle(.iconOnly)
            }
            .padding()
            .background(Theme.cardBackground)
            .clipShape(.rect(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showingEditSheet) {
            EditItemView(viewModel: viewModel, item: item)
        }
        .confirmationDialog(
            "Delete \(item.name)?",
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive, action: onDelete)
        } message: {
            Text("This can't be undone.")
        }
    }
}

// MARK: - Edit Item View

struct EditItemView: View {
    var viewModel: NetWorthViewModel
    let item: FinancialItem
    @Environment(\.dismiss) private var dismiss

    // Edits go to a draft and are only written back on Done, so Cancel discards them.
    @State private var name: String
    @State private var amount: Int
    @State private var category: String
    @State private var month: Int

    init(viewModel: NetWorthViewModel, item: FinancialItem) {
        self.viewModel = viewModel
        self.item = item
        _name = State(initialValue: item.name)
        _amount = State(initialValue: item.amount)
        _category = State(initialValue: item.category)
        _month = State(initialValue: item.month)
    }

    private var categories: [String] {
        let names = viewModel.allCategoryNames(for: item.itemType == "asset" ? .asset : .liability)
        // Keep the item's current category selectable even if it has since been deleted.
        return names.contains(item.category) ? names : names + [item.category]
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    TextField("Name", text: $name)
                    TextField("Amount", value: $amount, format: .number)
                        .keyboardType(.numberPad)
                }

                Section("Category") {
                    Picker("Category", selection: $category) {
                        ForEach(categories, id: \.self) { option in
                            Text(option).tag(option)
                        }
                    }
                }

                Section("Month") {
                    Picker("Month", selection: $month) {
                        Text("Yearly (no specific month)").tag(0)
                        ForEach(1...12, id: \.self) { option in
                            Text(Calendar.current.monthSymbols[option - 1]).tag(option)
                        }
                    }
                }
            }
            .navigationTitle("Edit Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        viewModel.updateItem(item, name: name, amount: amount, category: category, month: month)
                        dismiss()
                    }
                    .disabled(name.isEmpty)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Previews

#Preview("Financial Item Card") {
    let container = try! ModelContainer(
        for: FinancialItem.self, TrackedYear.self, UserSettings.self,
        Goal.self, RecurringItem.self, Milestone.self, CustomCategory.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    let item = FinancialItem(name: "Test", amount: 32_322, year: 2025, category: "Cash", itemType: "asset")
    container.mainContext.insert(item)
    return FinancialItemCard(
        viewModel: NetWorthViewModel(modelContext: container.mainContext),
        item: item,
        type: .asset,
        onDelete: {}
    )
        .padding()
        .background(Color.black)
}
