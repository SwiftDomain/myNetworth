//
//  UpdateBalancesView.swift
//  myNetworth
//

import SwiftUI

// MARK: - Update Balances View

/// Walks through a year's items one at a time so each amount can be kept ("Same") or
/// replaced, then shows how net worth changes before saving everything at once.
struct UpdateBalancesView: View {
    var viewModel: NetWorthViewModel
    let year: Int
    @Environment(\.dismiss) private var dismiss

    /// The items to go through, captured when the flow opens so the order can't shift.
    @State private var items: [FinancialItem]
    /// Amounts confirmed so far, by item ID. Nothing is saved until the end.
    @State private var newAmounts: [UUID: Int] = [:]
    @State private var step = 0
    @State private var amountText = ""
    @State private var showingDiscardConfirmation = false
    @FocusState private var amountFieldFocused: Bool

    init(viewModel: NetWorthViewModel, year: Int) {
        self.viewModel = viewModel
        self.year = year
        _items = State(initialValue: viewModel.yearlyItems(in: year))
    }

    private var currency: IntegerFormatStyle<Int>.Currency {
        .currency(code: viewModel.currencyCode).precision(.fractionLength(0))
    }

    private var changedItems: [FinancialItem] {
        items.filter { item in
            newAmounts[item.id].map { $0 != item.amount } ?? false
        }
    }

    /// How much net worth moves if the changes are saved.
    private var netWorthChange: Int {
        changedItems.reduce(0) { total, item in
            let difference = (newAmounts[item.id] ?? item.amount) - item.amount
            return total + (item.itemType == "asset" ? difference : -difference)
        }
    }

    /// The typed amount, parsed with the user's locale so "5,000" and local digits work.
    private var typedAmount: Int? {
        try? Int(amountText, format: .number)
    }

    private var saveButtonTitle: String {
        switch changedItems.count {
        case 0: "Done"
        case 1: "Save 1 Change"
        case let count: "Save \(count) Changes"
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if step < items.count {
                    itemStep(items[step])
                } else {
                    summary
                }
            }
            .padding()
            .navigationTitle("Update Balances")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        if changedItems.isEmpty {
                            dismiss()
                        } else {
                            showingDiscardConfirmation = true
                        }
                    }
                }
            }
            .confirmationDialog(
                "Discard your changes?",
                isPresented: $showingDiscardConfirmation,
                titleVisibility: .visible
            ) {
                Button("Discard Changes", role: .destructive) {
                    dismiss()
                }
            }
        }
        // Don't lose entered amounts to an accidental swipe down.
        .interactiveDismissDisabled(!changedItems.isEmpty)
        .onAppear {
            amountFieldFocused = true
        }
    }

    // MARK: - Item Step

    private func itemStep(_ item: FinancialItem) -> some View {
        VStack(spacing: 24) {
            VStack(spacing: 6) {
                ProgressView(value: Double(step), total: Double(items.count))
                Text("\(step + 1) of \(items.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 6) {
                Text(item.name)
                    .font(.title2)
                    .bold()
                    .multilineTextAlignment(.center)
                Text("\(item.category) · \(item.itemType == "asset" ? "Asset" : "Liability")")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 8) {
                Text("Last amount: \(item.amount, format: currency)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                TextField("New amount", text: $amountText)
                    .keyboardType(.numberPad)
                    .font(.largeTitle.bold())
                    .multilineTextAlignment(.center)
                    .focused($amountFieldFocused)

                if let typedAmount {
                    Text(typedAmount, format: currency)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 12) {
                Button {
                    advance(to: item.amount)
                } label: {
                    Text("Same")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                Button {
                    if let typedAmount {
                        advance(to: typedAmount)
                    }
                } label: {
                    Text("Update")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(typedAmount == nil)
            }
            .controlSize(.large)

            if step > 0 {
                Button("Back", systemImage: "chevron.left") {
                    goBack()
                }
            }

            Spacer()
        }
    }

    // MARK: - Summary

    private var summary: some View {
        let before = viewModel.getYearData(for: year).netWorth
        let after = before + netWorthChange

        return ScrollView {
            VStack(spacing: 20) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(.green)

                Text(changedItems.isEmpty ? "Nothing changed" : "Review your updates")
                    .font(.title2)
                    .bold()

                VStack(spacing: 4) {
                    Text("Net worth for \(String(year))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(after, format: currency)
                        .font(.largeTitle.bold())
                    if netWorthChange != 0 {
                        Text("\(netWorthChange > 0 ? "+" : "-")\(abs(netWorthChange), format: currency) from \(before, format: currency)")
                            .font(.subheadline)
                            .foregroundStyle(netWorthChange > 0 ? Theme.positiveAmount : Theme.negativeAmount)
                    }
                }

                if !changedItems.isEmpty {
                    VStack(spacing: 10) {
                        ForEach(changedItems) { item in
                            HStack {
                                Text(item.name)
                                Spacer()
                                Text(item.amount, format: currency)
                                    .foregroundStyle(.secondary)
                                Image(systemName: "arrow.right")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(newAmounts[item.id] ?? item.amount, format: currency)
                                    .bold()
                            }
                            .font(.subheadline)
                        }
                    }
                    .padding()
                    .background(Color.secondary.opacity(0.1))
                    .clipShape(.rect(cornerRadius: 12))
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 12) {
                Button {
                    viewModel.updateAmounts(newAmounts, of: changedItems)
                    dismiss()
                } label: {
                    Text(saveButtonTitle)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                if !items.isEmpty {
                    Button("Back", systemImage: "chevron.left") {
                        goBack()
                    }
                }
            }
            .padding(.top)
        }
    }

    // MARK: - Navigation

    private func advance(to amount: Int) {
        newAmounts[items[step].id] = amount
        step += 1
        loadAmountText()
    }

    private func goBack() {
        step -= 1
        loadAmountText()
    }

    /// When revisiting an item, show the new amount entered for it. Otherwise the field
    /// starts empty so a new number can be typed without deleting the old one.
    private func loadAmountText() {
        guard step < items.count else {
            amountText = ""
            amountFieldFocused = false
            return
        }
        let item = items[step]
        if let amount = newAmounts[item.id], amount != item.amount {
            amountText = String(amount)
        } else {
            amountText = ""
        }
        amountFieldFocused = true
    }
}
