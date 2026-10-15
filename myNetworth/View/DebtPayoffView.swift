//
//  DebtPayoffView.swift
//  myNetworth
//

import SwiftUI
import SwiftData

// MARK: - Debt Payoff Planner

/// Plans paying off the current year's debts: compares the snowball and avalanche methods
/// with an optional extra monthly payment, and shows when each debt gets paid off.
struct DebtPayoffView: View {
    /// Where the chosen strategy is saved. Home reads it to suggest the same debt.
    static let strategyKey = "debtPlanner.strategy"
    /// Where the extra monthly payment is saved, as typed.
    static let extraPaymentKey = "debtPlanner.extraPayment"

    var viewModel: NetWorthViewModel

    // Remembered between visits on this device.
    @AppStorage(DebtPayoffView.extraPaymentKey) private var extraText = ""
    @AppStorage(DebtPayoffView.strategyKey) private var strategy: PayoffStrategy = .snowball
    @State private var debtBeingEdited: FinancialItem?

    private var currency: IntegerFormatStyle<Int>.Currency {
        .currency(code: viewModel.currencyCode).precision(.fractionLength(0))
    }

    private var extraPayment: Int {
        max((try? Int(extraText, format: .number)) ?? 0, 0)
    }

    var body: some View {
        let debts = viewModel.plannerDebts
        let snowball = DebtPlanner.plan(for: debts, strategy: .snowball, extraPayment: extraPayment)
        let avalanche = DebtPlanner.plan(for: debts, strategy: .avalanche, extraPayment: extraPayment)

        ZStack {
            Background(bgColor1: Theme.mainGradient1, bgColor2: Theme.mainGradient2)

            ScrollView {
                VStack(spacing: 20) {
                    if viewModel.currentDebts.isEmpty {
                        EmptyStateView(
                            icon: "checkmark.seal",
                            message: "No debts to pay off",
                            subMessage: "Liabilities you add for this year will show up here"
                        )
                        .padding(.top, 100)
                    } else {
                        summaryCard(debts)

                        if debts.contains(where: { $0.annualRate == 0 && $0.minimumPayment == 0 }) {
                            missingTermsNotice
                        }

                        extraPaymentCard

                        if debts.isEmpty {
                            Text("Turn on at least one debt below to see a plan.")
                                .font(.subheadline)
                                .foregroundStyle(Theme.textSecondary)
                        } else {
                            comparison(snowball: snowball, avalanche: avalanche)
                            timeline(strategy == .snowball ? snowball : avalanche)
                        }

                        debtList
                    }
                }
                .padding()
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .navigationTitle("Debt Payoff Planner")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $debtBeingEdited) { debt in
            DebtTermsEditor(viewModel: viewModel, debt: debt)
        }
    }

    // MARK: - Summary

    private func summaryCard(_ debts: [PlannerDebt]) -> some View {
        let total = debts.reduce(0) { $0 + $1.balance }
        let minimums = debts.reduce(0) { $0 + $1.minimumPayment }

        return VStack(alignment: .leading, spacing: 8) {
            Text("Debt in your plan")
                .font(.caption)
                .foregroundStyle(Theme.textSecondary)

            Text(total, format: currency)
                .font(.title)
                .bold()
                .foregroundStyle(Theme.negativeAmount)
                .privacySensitive()

            Text("\(debts.count) of \(viewModel.currentDebts.count) debts · \(minimums, format: currency) a month in minimums")
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
                .privacySensitive()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Theme.cardBackground)
        .clipShape(.rect(cornerRadius: 12))
    }

    private var missingTermsNotice: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)

            Text("Some debts have no interest rate or minimum payment yet, so they count as 0% with no minimum. Tap a debt below to add them.")
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.orange.opacity(0.15))
        .clipShape(.rect(cornerRadius: 12))
    }

    private var extraPaymentCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Extra payment each month")
                .font(.headline)
                .foregroundStyle(Theme.textPrimary)

            Text("On top of your minimums. It goes to one debt at a time.")
                .font(.caption)
                .foregroundStyle(Theme.textSecondary)

            TextField("0", text: $extraText)
                .keyboardType(.numberPad)
                .font(.title2.bold())
                .foregroundStyle(Theme.textPrimary)
                .padding(12)
                .background(Theme.subtleBackground)
                .clipShape(.rect(cornerRadius: 10))

            if extraPayment > 0 {
                Text("\(extraPayment, format: currency) a month")
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
                    .privacySensitive()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Theme.cardBackground)
        .clipShape(.rect(cornerRadius: 12))
    }

    // MARK: - Comparison

    private func comparison(snowball: PayoffPlan, avalanche: PayoffPlan) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Compare methods")
                .font(.headline)
                .foregroundStyle(Theme.textPrimary)

            HStack(alignment: .top, spacing: 12) {
                strategyCard(snowball, comparedTo: avalanche)
                strategyCard(avalanche, comparedTo: snowball)
            }

            Text("Tap a method to see its payoff order.")
                .font(.caption)
                .foregroundStyle(Theme.textSecondary)
        }
    }

    private func strategyCard(_ plan: PayoffPlan, comparedTo other: PayoffPlan) -> some View {
        let isSelected = plan.strategy == strategy
        let savings = Int((other.totalInterest - plan.totalInterest).rounded())

        return Button {
            strategy = plan.strategy
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(plan.strategy.title)
                        .font(.headline)
                        .foregroundStyle(Theme.textPrimary)
                    Spacer()
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.blue)
                    }
                }

                Text(plan.strategy.summary)
                    .font(.caption2)
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                Divider()
                    .background(Color.white.opacity(0.3))

                if plan.isPayable {
                    Text("Debt-free")
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                    Text(date(monthsFromNow: plan.months), format: .dateTime.month(.abbreviated).year())
                        .font(.title3)
                        .bold()
                        .foregroundStyle(Theme.positiveAmount)
                    Text(duration(months: plan.months))
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)

                    Text("Total interest")
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                        .padding(.top, 4)
                    Text(Int(plan.totalInterest.rounded()), format: currency)
                        .font(.subheadline)
                        .bold()
                        .foregroundStyle(Theme.negativeAmount)
                        .privacySensitive()

                    if other.isPayable && savings > 0 {
                        Text("Saves \(savings, format: currency)")
                            .font(.caption)
                            .bold()
                            .foregroundStyle(Theme.positiveAmount)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Theme.positiveAmount.opacity(0.2))
                            .clipShape(.rect(cornerRadius: 6))
                            .privacySensitive()
                    }
                } else {
                    Text("Not paid off within 50 years at these payments")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(isSelected ? Color.blue.opacity(0.25) : Theme.cardBackground)
            .clipShape(.rect(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Timeline

    private func timeline(_ plan: PayoffPlan) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("\(plan.strategy.title) payoff order")
                .font(.headline)
                .foregroundStyle(Theme.textPrimary)

            if !plan.isPayable {
                Text("These payments don't cover the interest, so the debt never gets paid off. Add minimum payments or an extra amount.")
                    .font(.subheadline)
                    .foregroundStyle(.orange)
            }

            ForEach(Array(plan.milestones.enumerated()), id: \.element.id) { index, milestone in
                HStack(alignment: .top, spacing: 12) {
                    Text("\(index + 1)")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(width: 32, height: 32)
                        .background(Color.blue)
                        .clipShape(.circle)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(milestone.name)
                            .font(.headline)
                            .foregroundStyle(Theme.textPrimary)

                        Text("Paid off \(date(monthsFromNow: milestone.month), format: .dateTime.month(.wide).year())")
                            .font(.subheadline)
                            .foregroundStyle(Theme.positiveAmount)

                        if let nextName = milestone.nextDebtName, let nextPayment = milestone.nextDebtPayment {
                            Text("Then \(nextName) gets \(nextPayment, format: currency) a month")
                                .font(.caption)
                                .foregroundStyle(Theme.textSecondary)
                                .privacySensitive()
                        }
                    }

                    Spacer()
                }
                .padding()
                .background(Theme.cardBackground)
                .clipShape(.rect(cornerRadius: 12))
            }
        }
    }

    // MARK: - Debts

    private var debtList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your debts")
                .font(.headline)
                .foregroundStyle(Theme.textPrimary)

            Text("Tap a debt to set its interest rate and minimum payment. Use the switch to leave a debt out of the plan.")
                .font(.caption)
                .foregroundStyle(Theme.textSecondary)

            ForEach(viewModel.currentDebts) { debt in
                let saved = viewModel.terms(for: debt)
                let isIncluded = viewModel.isIncludedInPlan(debt)

                HStack(spacing: 12) {
                    Button {
                        debtBeingEdited = debt
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(debt.name)
                                .font(.headline)
                                .foregroundStyle(Theme.textPrimary)

                            Text(debt.amount, format: currency)
                                .font(.subheadline)
                                .foregroundStyle(Theme.negativeAmount)
                                .privacySensitive()

                            if let saved, saved.annualRate > 0 || saved.minimumPayment > 0 {
                                Text("\(saved.annualRate, format: .number.precision(.fractionLength(0...2)))% APR · \(saved.minimumPayment, format: currency) minimum")
                                    .font(.caption)
                                    .foregroundStyle(Theme.textSecondary)
                                    .privacySensitive()
                            } else {
                                Label("Add rate and minimum", systemImage: "plus.circle")
                                    .font(.caption)
                                    .foregroundStyle(.orange)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)

                    Toggle("Include \(debt.name) in the plan", isOn: Binding(
                        get: { isIncluded },
                        set: { viewModel.setIncludedInPlan($0, for: debt) }
                    ))
                    .labelsHidden()
                    .tint(.blue)
                }
                .padding()
                .background(Theme.cardBackground)
                .clipShape(.rect(cornerRadius: 12))
                .opacity(isIncluded ? 1 : 0.6)
            }
        }
    }

    // MARK: - Formatting

    private func date(monthsFromNow months: Int) -> Date {
        Calendar.current.date(byAdding: .month, value: months, to: .now) ?? .now
    }

    private func duration(months: Int) -> String {
        let years = months / 12
        let remainder = months % 12
        switch (years, remainder) {
        case (0, _): return "\(remainder) mo"
        case (_, 0): return "\(years) yr"
        default: return "\(years) yr \(remainder) mo"
        }
    }
}

// MARK: - Debt Terms Editor

/// Edits a debt's interest rate, minimum payment and whether it's in the plan.
struct DebtTermsEditor: View {
    var viewModel: NetWorthViewModel
    let debt: FinancialItem
    @Environment(\.dismiss) private var dismiss

    @State private var rateText: String
    @State private var minimumText: String
    @State private var isIncluded: Bool

    init(viewModel: NetWorthViewModel, debt: FinancialItem) {
        self.viewModel = viewModel
        self.debt = debt
        let saved = viewModel.terms(for: debt)
        _rateText = State(initialValue: saved.map { $0.annualRate > 0 ? $0.annualRate.formatted() : "" } ?? "")
        _minimumText = State(initialValue: saved.map { $0.minimumPayment > 0 ? String($0.minimumPayment) : "" } ?? "")
        _isIncluded = State(initialValue: viewModel.isIncludedInPlan(debt))
    }

    /// An empty field counts as 0; anything that isn't a number makes the value invalid.
    private var rate: Double? {
        if rateText.isEmpty { return 0 }
        return try? Double(rateText, format: .number)
    }

    private var minimum: Int? {
        if minimumText.isEmpty { return 0 }
        return try? Int(minimumText, format: .number)
    }

    private var isValid: Bool {
        guard let rate, let minimum else { return false }
        return (0...100).contains(rate) && minimum >= 0
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabeledContent("Balance") {
                        Text(debt.amount, format: .currency(code: viewModel.currencyCode).precision(.fractionLength(0)))
                            .privacySensitive()
                    }
                    LabeledContent("Category", value: debt.category)
                }

                Section {
                    LabeledContent("Interest rate (APR)") {
                        HStack(spacing: 4) {
                            TextField("0", text: $rateText)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                            Text("%")
                        }
                    }

                    LabeledContent("Minimum payment") {
                        TextField("0", text: $minimumText)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                    }
                } footer: {
                    Text("Find these on your latest statement. They're saved for this debt and used in every year it appears.")
                }

                Section {
                    Toggle("Include in payoff plan", isOn: $isIncluded)
                }
            }
            .navigationTitle(debt.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        viewModel.updateTerms(
                            for: debt,
                            annualRate: rate ?? 0,
                            minimumPayment: minimum ?? 0,
                            isIncluded: isIncluded
                        )
                        dismiss()
                    }
                    .disabled(!isValid)
                }
            }
        }
    }
}

// MARK: - Previews

#Preview {
    NavigationStack {
        DebtPayoffView(
            viewModel: NetWorthViewModel(modelContext: try! ModelContainer(
                for: FinancialItem.self, TrackedYear.self, UserSettings.self,
                Goal.self, RecurringItem.self, Milestone.self, CustomCategory.self, DebtTerms.self,
                configurations: ModelConfiguration(isStoredInMemoryOnly: true)
            ).mainContext)
        )
    }
}
