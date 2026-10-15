//
//  QuickStartView.swift
//  myNetworth
//

import SwiftUI

// MARK: - Quick Start

/// First-run setup: tap the accounts you have, type rough amounts, and this year is created
/// with them, instead of starting from an empty screen.
struct QuickStartView: View {
    /// Set once the setup has been shown, so it only opens by itself on the first launch.
    static let seenKey = "quickStart.seen"

    var viewModel: NetWorthViewModel
    @Environment(\.dismiss) private var dismiss
    @AppStorage(QuickStartView.seenKey) private var hasSeenQuickStart = false
    /// The picked accounts, in the order they were tapped.
    @State private var selected: [StarterAccount] = []
    @State private var amountTexts: [StarterAccount: String] = [:]
    @FocusState private var focusedAccount: StarterAccount?

    private let year = Calendar.current.component(.year, from: .now)

    private var currency: IntegerFormatStyle<Int>.Currency {
        .currency(code: viewModel.currencyCode).precision(.fractionLength(0))
    }

    /// The amounts typed so far, read with the user's locale so "5,000" works.
    private var amounts: [StarterAccount: Int] {
        var result: [StarterAccount: Int] = [:]
        for account in selected {
            if let text = amountTexts[account], let amount = try? Int(text, format: .number), amount > 0 {
                result[account] = amount
            }
        }
        return result
    }

    private var netWorth: Int {
        amounts.reduce(0) { total, entry in
            total + (entry.key.isAsset ? entry.value : -entry.value)
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Background(bgColor1: Theme.mainGradient1, bgColor2: Theme.mainGradient2)

                ScrollView {
                    VStack(alignment: .leading, spacing: 28) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Let's find your net worth")
                                .font(.largeTitle)
                                .bold()
                                .foregroundStyle(Theme.textPrimary)

                            Text("Tap what you have, then add rough amounts. It takes about a minute, and you can add more later.")
                                .font(.subheadline)
                                .foregroundStyle(Theme.textSecondary)

                            Text("Already use myNetworth on another device? Tap Skip, and your numbers will appear once iCloud syncs.")
                                .font(.footnote)
                                .foregroundStyle(Theme.textSecondary)
                        }

                        tiles("What you own", StarterAccount.assets)
                        tiles("What you owe", StarterAccount.debts)

                        if !selected.isEmpty {
                            amountsSection
                        }
                    }
                    .padding()
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle("Get Started")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Skip") { dismiss() }
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { focusedAccount = nil }
                }
            }
            .safeAreaInset(edge: .bottom) {
                startButton
            }
            .onAppear {
                hasSeenQuickStart = true
            }
        }
    }

    // MARK: Tiles

    private func tiles(_ title: String, _ accounts: [StarterAccount]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .foregroundStyle(Theme.textPrimary)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 12) {
                ForEach(accounts) { account in
                    tile(account)
                }
            }
        }
    }

    private func tile(_ account: StarterAccount) -> some View {
        let isSelected = selected.contains(account)
        return Button {
            toggle(account)
        } label: {
            VStack(spacing: 6) {
                Image(systemName: account.icon)
                    .font(.title2)
                Text(account.name)
                    .font(.caption)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundStyle(Theme.textPrimary)
            .frame(maxWidth: .infinity, minHeight: 72)
            .background(isSelected ? Color.blue.opacity(0.35) : Theme.cardBackground)
            .clipShape(.rect(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.blue : Theme.cardBorder, lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func toggle(_ account: StarterAccount) {
        if let index = selected.firstIndex(of: account) {
            selected.remove(at: index)
            amountTexts[account] = nil
        } else {
            selected.append(account)
            focusedAccount = account
        }
    }

    // MARK: Amounts

    private var amountsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Amounts")
                    .font(.headline)
                    .foregroundStyle(Theme.textPrimary)
                Text("Rough numbers are fine. You can change them any time.")
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
            }

            ForEach(selected) { account in
                HStack(spacing: 12) {
                    Image(systemName: account.icon)
                        .foregroundStyle(account.isAsset ? Theme.positiveAmount : Theme.negativeAmount)
                        .frame(width: 28)

                    Text(account.name)
                        .foregroundStyle(Theme.textPrimary)

                    Spacer()

                    TextField("Amount", text: amountText(for: account))
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .foregroundStyle(Theme.textPrimary)
                        .frame(maxWidth: 160)
                        .focused($focusedAccount, equals: account)
                }
                .padding()
                .background(Theme.cardBackground)
                .clipShape(.rect(cornerRadius: 12))
            }
        }
    }

    private func amountText(for account: StarterAccount) -> Binding<String> {
        Binding {
            amountTexts[account] ?? ""
        } set: { text in
            amountTexts[account] = text
        }
    }

    // MARK: Start

    private var startButton: some View {
        VStack(spacing: 8) {
            if !amounts.isEmpty {
                Text("Net worth \(netWorth, format: currency)")
                    .font(.subheadline)
                    .bold()
                    .privacySensitive()
            }

            Button {
                viewModel.startTracking(year: year, amounts: amounts)
                dismiss()
            } label: {
                Text(amounts.isEmpty ? "Pick an account and add its amount" : "Start Tracking \(String(year))")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(amounts.isEmpty)
        }
        .padding()
        .background(.bar)
    }
}
