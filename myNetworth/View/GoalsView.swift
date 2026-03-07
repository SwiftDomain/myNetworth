//
//  GoalsView.swift
//  myNetworth
//

import SwiftUI
import SwiftData

// MARK: - Goals List View

struct GoalsListView: View {
    var viewModel: NetWorthViewModel
    @State private var showingAddSheet = false

    var body: some View {
        ZStack {
            Background(bgColor1: Theme.mainGradient1, bgColor2: Theme.mainGradient2)

            ScrollView {
                VStack(spacing: 16) {
                    if viewModel.goals.isEmpty {
                        EmptyStateView(
                            icon: "target",
                            message: "No goals yet",
                            subMessage: "Set a financial goal to track your progress"
                        )
                        .padding(.top, 100)
                    } else {
                        ForEach(viewModel.goals) { goal in
                            GoalCard(viewModel: viewModel, goal: goal)
                        }
                    }
                }
                .padding()
            }
        }
        .navigationTitle("Goals")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            Button("Add Goal", systemImage: "plus.circle.fill") {
                showingAddSheet = true
            }
            .foregroundStyle(.blue)
        }
        .sheet(isPresented: $showingAddSheet) {
            AddGoalView(viewModel: viewModel)
        }
    }
}

// MARK: - Goal Card

struct GoalCard: View {
    var viewModel: NetWorthViewModel
    let goal: Goal

    private var progress: Double {
        viewModel.goalProgress(for: goal)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(goal.title)
                        .font(.headline)
                        .foregroundStyle(Theme.textPrimary)

                    Text(goal.goalType.capitalized)
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                }

                Spacer()

                if goal.isAchieved {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.title2)
                        .foregroundStyle(.green)
                }

                Button("Delete", systemImage: "trash", role: .destructive) {
                    viewModel.deleteGoal(goal)
                }
                .labelStyle(.iconOnly)
                .foregroundStyle(.red.opacity(0.8))
            }

            HStack {
                Text("Target:")
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
                Text(goal.targetAmount, format: .currency(code: viewModel.currencyCode).precision(.fractionLength(0)))
                    .font(.subheadline)
                    .bold()
                    .foregroundStyle(Theme.textPrimary)

                Spacer()

                Text("By: \(goal.targetDate, format: .dateTime.year().month())")
                    .font(.caption)
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

// MARK: - Add Goal View

struct AddGoalView: View {
    var viewModel: NetWorthViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var targetAmount = 0
    @State private var targetDate = Date.now.addingTimeInterval(365 * 24 * 60 * 60)
    @State private var goalType = "netWorth"

    var body: some View {
        NavigationStack {
            Form {
                Section("Goal Details") {
                    TextField("Title (e.g. 'Reach $500K')", text: $title)

                    TextField("Target Amount", value: $targetAmount, format: .number)
                        .keyboardType(.numberPad)

                    DatePicker("Target Date", selection: $targetDate, displayedComponents: .date)

                    Picker("Goal Type", selection: $goalType) {
                        Text("Net Worth").tag("netWorth")
                        Text("Total Assets").tag("asset")
                        Text("Total Liabilities").tag("liability")
                    }
                }
            }
            .navigationTitle("New Goal")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let goal = Goal(
                            title: title,
                            targetAmount: targetAmount,
                            targetDate: targetDate,
                            goalType: goalType
                        )
                        viewModel.addGoal(goal)
                        dismiss()
                    }
                    .disabled(title.isEmpty || targetAmount == 0)
                }
            }
        }
    }
}
