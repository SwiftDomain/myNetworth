//
//  HomePage.swift
//  myNetworth
//
//  Created by BeastMode on 12/5/25.
//

import SwiftUI
import SwiftData
import Charts
import LocalAuthentication

// MARK: - Main View (Year Selection)

struct HomePage: View {

    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: NetWorthViewModel?
    @State private var isUnlocked = false

    var body: some View {
        Group {
            if let viewModel {
                if viewModel.settings.requireBiometricLock && !isUnlocked {
                    BiometricLockView(isUnlocked: $isUnlocked)
                } else {
                    HomePageContent(viewModel: viewModel)
                }
            } else {
                ProgressView()
            }
        }
        .preferredColorScheme(viewModel?.resolvedColorScheme)
        .task {
            if viewModel == nil {
                viewModel = NetWorthViewModel(modelContext: modelContext)
            }
        }
    }
}

// MARK: - Biometric Lock View

struct BiometricLockView: View {
    @Binding var isUnlocked: Bool
    @State private var authError: String?

    var body: some View {
        ZStack {
            Background(bgColor1: Theme.mainGradient1, bgColor2: Theme.mainGradient2)

            VStack(spacing: 24) {
                Image(systemName: "faceid")
                    .font(.system(size: 60))
                    .foregroundStyle(.blue)

                Text("myNetworth")
                    .font(.largeTitle)
                    .bold()
                    .foregroundStyle(Theme.textPrimary)

                Text("Authentication required")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)

                if let authError {
                    Text(authError)
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                Button("Unlock", systemImage: "lock.open.fill") {
                    authenticate()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .task {
            authenticate()
        }
    }

    private func authenticate() {
        let context = LAContext()
        var error: NSError?

        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            // Biometrics not available, allow access
            isUnlocked = true
            return
        }

        context.evaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics,
            localizedReason: "Unlock your net worth data"
        ) { success, evaluationError in
            if success {
                isUnlocked = true
            } else {
                authError = evaluationError?.localizedDescription
            }
        }
    }
}

// MARK: - Home Page Content

struct HomePageContent: View {

    var viewModel: NetWorthViewModel
    @State private var showingAddYear = false
    @State private var showingSettings = false
    @State private var newYear = Calendar.current.component(.year, from: Date())
    @State private var navigationPath = NavigationPath()

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ZStack {
                Background(bgColor1: Theme.mainGradient1, bgColor2: Theme.mainGradient2)

                ScrollView {
                    VStack(spacing: 20) {
                        // Header
                        VStack(spacing: 8) {
                            Image(systemName: "chart.line.uptrend.xyaxis")
                                .font(.largeTitle)
                                .foregroundStyle(.blue.opacity(0.8))

                            Text("Net Worth Tracker")
                                .font(.largeTitle)
                                .bold()
                                .foregroundStyle(Theme.textPrimary)

                            Text("Track your financial journey year by year")
                                .font(.subheadline)
                                .foregroundStyle(Theme.textSecondary)

                            Text("Family Friendly")
                                .font(.caption)
                                .foregroundStyle(.blue.opacity(0.8))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.blue.opacity(0.2))
                                .clipShape(.rect(cornerRadius: 8))
                        }
                        .padding(.top, 40)
                        .padding(.bottom, 20)

                        // Active Goals Preview
                        if !viewModel.goals.filter({ !$0.isAchieved }).isEmpty {
                            GoalPreviewCard(viewModel: viewModel)
                        }

                        // Years Grid
                        if viewModel.years.isEmpty {
                            EmptyStateView(
                                icon: "calendar",
                                message: "No years added yet",
                                subMessage: "Add a year to start tracking your net worth"
                            )
                            .padding(.top, 60)
                        } else {
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
                                            viewModel.deleteYear(year)
                                        } label: {
                                            Label("Delete Year", systemImage: "trash")
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: Int.self) { year in
                YearDetailView(viewModel: viewModel, year: year)
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 12) {
                        Button("Settings", systemImage: "gearshape.fill") {
                            showingSettings = true
                        }
                        .foregroundStyle(.blue)

                        Button("Add Year", systemImage: "plus.circle.fill") {
                            showingAddYear = true
                        }
                        .foregroundStyle(.blue)
                    }
                }

                ToolbarItem(placement: .navigationBarLeading) {
                    HStack(spacing: 12) {
                        if !viewModel.years.isEmpty {
                            NavigationLink {
                                OverallAnalysisView(viewModel: viewModel)
                            } label: {
                                Image(systemName: "chart.bar.fill")
                                    .font(.title3)
                                    .foregroundStyle(.blue)
                            }
                        }

                        if !viewModel.goals.isEmpty {
                            NavigationLink {
                                GoalsListView(viewModel: viewModel)
                            } label: {
                                Image(systemName: "target")
                                    .font(.title3)
                                    .foregroundStyle(.blue)
                            }
                        }
                    }
                }
            }
            .sheet(isPresented: $showingAddYear) {
                AddYearView(viewModel: viewModel, newYear: $newYear) { addedYear in
                    navigationPath.append(addedYear)
                }
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView(viewModel: viewModel)
            }
        }
    }
}

// MARK: - Goal Preview Card

struct GoalPreviewCard: View {
    var viewModel: NetWorthViewModel

    private var activeGoals: [Goal] {
        viewModel.goals.filter { !$0.isAchieved }
    }

    var body: some View {
        if let goal = activeGoals.first {
            let progress = viewModel.goalProgress(for: goal)
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "target")
                        .foregroundStyle(.blue)
                    Text(goal.title)
                        .font(.headline)
                        .foregroundStyle(Theme.textPrimary)
                    Spacer()
                    Text(goal.targetAmount, format: .currency(code: viewModel.currencyCode).precision(.fractionLength(0)))
                        .font(.subheadline)
                        .foregroundStyle(Theme.textSecondary)
                }

                ProgressView(value: min(max(progress, 0), 1))
                    .tint(progress >= 1 ? .green : .blue)

                Text("\(Int(progress * 100))% complete")
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
            }
            .padding()
            .background(Theme.cardBackground)
            .clipShape(.rect(cornerRadius: 12))
        }
    }
}

// MARK: - Empty State

struct EmptyStateView: View {
    let icon: String
    let message: String
    let subMessage: String

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.largeTitle)
                .foregroundStyle(Theme.textPrimary.opacity(0.3))

            Text(message)
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundStyle(Theme.textPrimary)

            Text(subMessage)
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
        }
    }
}

// MARK: - Add Item View

struct AddItemView: View {

    var viewModel: NetWorthViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var amount = 0
    @State private var selectedCategory = ""
    @State private var selectedMonth = 0

    let type: ItemType
    let year: Int

    private var categories: [String] {
        viewModel.allCategoryNames(for: type)
    }

    var body: some View {
        ZStack {
            Background(
                bgColor1: type == .asset ? Theme.assetGradient1 : Theme.liabilityGradient1,
                bgColor2: type == .asset ? Theme.assetGradient2 : Theme.liabilityGradient2
            )

            NavigationStack {
                VStack {
                    // Header
                    VStack(spacing: 8) {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.largeTitle)
                            .foregroundStyle(.blue.opacity(0.8))

                        Text(type == .asset ? "Add Asset" : "Add Liability")
                            .font(.largeTitle)
                            .bold()
                            .foregroundStyle(Theme.textPrimary)

                        Text("Track your financial journey")
                            .font(.subheadline)
                            .foregroundStyle(Theme.textSecondary)

                        Text(type == .asset ? "New Asset" : "New Liability")
                            .font(.caption)
                            .foregroundStyle(.blue.opacity(0.8))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.blue.opacity(0.2))
                            .clipShape(.rect(cornerRadius: 8))
                    }
                    .padding(.bottom, 20)

                    // Form Card
                    VStack(spacing: 20) {
                        FormField(label: "Name") {
                            TextField("Name", text: $name)
                                .textFieldStyle(.plain)
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .clipShape(.rect(cornerRadius: 10))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(Color(red: 0.4, green: 0.6, blue: 0.85), lineWidth: 1)
                                )
                        }

                        FormField(label: "Amount") {
                            TextField("Amount", value: $amount, format: .number)
                                .keyboardType(.numberPad)
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .clipShape(.rect(cornerRadius: 10))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(Color(red: 0.4, green: 0.6, blue: 0.85), lineWidth: 1)
                                )
                        }

                        FormField(label: "Category") {
                            Picker("Category", selection: $selectedCategory) {
                                Text("Select category").tag("")
                                ForEach(categories, id: \.self) { category in
                                    Text(category).tag(category)
                                }
                            }
                            .pickerStyle(.menu)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.white)
                            .clipShape(.rect(cornerRadius: 10))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color(red: 0.4, green: 0.6, blue: 0.85), lineWidth: 1)
                            )
                        }

                        FormField(label: "Month (optional)") {
                            Picker("Month", selection: $selectedMonth) {
                                Text("Yearly (no specific month)").tag(0)
                                ForEach(1...12, id: \.self) { month in
                                    Text(Calendar.current.monthSymbols[month - 1]).tag(month)
                                }
                            }
                            .pickerStyle(.menu)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.white)
                            .clipShape(.rect(cornerRadius: 10))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color(red: 0.4, green: 0.6, blue: 0.85), lineWidth: 1)
                            )
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

                    Spacer()
                }
                .padding()
                .toolbarTitleDisplayMode(.inlineLarge)
                .navigationTitle("")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel", systemImage: "xmark.circle.fill") {
                            dismiss()
                        }
                        .foregroundStyle(.blue)
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        let isValid = !name.isEmpty && amount > 0 && !selectedCategory.isEmpty
                        Button("Save", systemImage: isValid ? "checkmark.circle.fill" : "checkmark.circle") {
                            guard isValid else { return }
                            let item = FinancialItem(
                                name: name,
                                amount: amount,
                                year: year,
                                month: selectedMonth,
                                category: selectedCategory,
                                itemType: type == .asset ? "asset" : "liability"
                            )
                            viewModel.addItem(item)
                            dismiss()
                        }
                        .foregroundStyle(isValid ? .blue : .gray)
                        .disabled(!isValid)
                    }
                }
            }
        }
    }
}

// MARK: - Form Field Helper

struct FormField<Content: View>: View {
    let label: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(Theme.textPrimary)
            content
        }
    }
}

// MARK: - Category Chart

struct CategoryChartView: View {
    let data: [(String, Int)]
    let title: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.primary)
                .padding()

            if !data.isEmpty {
                Chart(data, id: \.0) { item in
                    SectorMark(
                        angle: .value("Amount", item.1),
                        innerRadius: .ratio(0.5),
                        angularInset: 2
                    )
                    .foregroundStyle(by: .value("Category", item.0))
                }
                .scaledToFit()
            }
        }
        .padding()
        .background(Theme.cardBackground)
        .clipShape(.rect(cornerRadius: 16))
    }
}

// MARK: - Background

struct Background: View {
    let bgColor1: Color
    let bgColor2: Color

    var body: some View {
        LinearGradient(
            colors: [bgColor1, bgColor2],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}

// MARK: - Previews

#Preview("Home Page") {
    HomePage()
        .modelContainer(for: [
            FinancialItem.self, TrackedYear.self, UserSettings.self,
            Goal.self, RecurringItem.self, Milestone.self, CustomCategory.self,
        ], inMemory: true)
}

#Preview("Category Chart") {
    CategoryChartView(
        data: [("Car", 50), ("House", 30), ("Credit Card", 50), ("Jewelry", 30)],
        title: "Test Title",
        color: .black
    )
}
