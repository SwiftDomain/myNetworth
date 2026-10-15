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
    @State private var showingDeleteConfirmation = false

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
                    showingDeleteConfirmation = true
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
                    .privacySensitive()

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

            GoalPaceLabel(viewModel: viewModel, goal: goal)
        }
        .padding()
        .background(Theme.cardBackground)
        .clipShape(.rect(cornerRadius: 12))
        .confirmationDialog(
            "Delete \(goal.title)?",
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete Goal", role: .destructive) {
                viewModel.deleteGoal(goal)
            }
        } message: {
            Text("This can't be undone.")
        }
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
                Section {
                    TextField("Title (e.g. 'Reach $500K')", text: $title)

                    TextField("Target Amount", value: $targetAmount, format: .number)
                        .keyboardType(.numberPad)

                    DatePicker("Target Date", selection: $targetDate, displayedComponents: .date)

                    Picker("Goal Type", selection: $goalType) {
                        Text("Net Worth").tag("netWorth")
                        Text("Total Assets").tag("asset")
                        Text("Total Liabilities").tag("liability")
                    }
                } header: {
                    Text("Goal Details")
                } footer: {
                    if goalType == "liability" {
                        Text("Progress counts down from your debt today to the target amount. Enter 0 to aim for debt-free.")
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
                    // A debt goal of 0 means debt-free; other goals need a positive target.
                    .disabled(title.isEmpty || (targetAmount <= 0 && goalType != "liability"))
                }
            }
        }
    }
}

// MARK: - Goal Pace Label

/// One line on how a goal is pacing: reached, on track, or what it takes to make the date.
struct GoalPaceLabel: View {
    var viewModel: NetWorthViewModel
    let goal: Goal

    private var currency: IntegerFormatStyle<Int>.Currency {
        .currency(code: viewModel.currencyCode).precision(.fractionLength(0))
    }

    private var isDebtGoal: Bool { goal.goalType == "liability" }

    var body: some View {
        if let pace = viewModel.goalPace(for: goal) {
            Label {
                text(for: pace)
            } icon: {
                Image(systemName: icon(for: pace))
            }
            .font(.caption)
            .foregroundStyle(color(for: pace))
        }
    }

    @ViewBuilder
    private func text(for pace: GoalPace) -> some View {
        let monthYear = Date.FormatStyle.dateTime.month(.abbreviated).year()
        switch pace {
        case .reached:
            if let achievedDate = goal.achievedDate {
                Text("Reached \(achievedDate, format: monthYear)")
            } else {
                Text("Reached")
            }
        case .onTrack(let projected):
            Text("On track · around \(projected, format: monthYear)")
        case .behind(let perMonth):
            Text("Behind · \(isDebtGoal ? "pay down" : "save") \(perMonth, format: currency) a month to make \(goal.targetDate, format: monthYear)")
                .privacySensitive()
        case .needs(let perMonth):
            Text("\(isDebtGoal ? "Pay down" : "Save") \(perMonth, format: currency) a month to reach it by \(goal.targetDate, format: monthYear)")
                .privacySensitive()
        case .overdue(let remaining):
            Text("Target date passed · \(remaining, format: currency) to go")
                .privacySensitive()
        }
    }

    private func icon(for pace: GoalPace) -> String {
        switch pace {
        case .reached: "checkmark.seal.fill"
        case .onTrack: "checkmark.circle"
        case .behind: "exclamationmark.triangle"
        case .needs: "calendar"
        case .overdue: "clock.badge.exclamationmark"
        }
    }

    private func color(for pace: GoalPace) -> Color {
        switch pace {
        case .reached, .onTrack: Theme.positiveAmount
        case .behind, .overdue: .orange
        case .needs: Theme.textSecondary
        }
    }
}

// MARK: - Goal Celebration

/// Shown once when a goal is reached.
struct GoalCelebrationView: View {
    let goal: Goal
    let currencyCode: String
    let onDismiss: () -> Void
    @State private var isShowing = false

    private var currency: IntegerFormatStyle<Int>.Currency {
        .currency(code: currencyCode).precision(.fractionLength(0))
    }

    private var detail: Text {
        switch goal.goalType {
        case "liability":
            goal.targetAmount == 0
                ? Text("You're debt-free.")
                : Text("Your debt is down to \(goal.targetAmount, format: currency).")
        case "asset":
            Text("Your assets reached \(goal.targetAmount, format: currency).")
        default:
            Text("Your net worth reached \(goal.targetAmount, format: currency).")
        }
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.6)
                .ignoresSafeArea()
                .onTapGesture(perform: onDismiss)

            VStack(spacing: 14) {
                Image(systemName: "party.popper.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.yellow)
                    .symbolEffect(.bounce, value: isShowing)

                Text("Goal reached!")
                    .font(.title)
                    .bold()

                Text(goal.title)
                    .font(.title3)
                    .multilineTextAlignment(.center)

                detail
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .privacySensitive()

                Button(action: onDismiss) {
                    Text("Nice!")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.top, 6)
            }
            .padding(28)
            .background(.regularMaterial, in: .rect(cornerRadius: 24))
            .padding(32)
            .scaleEffect(isShowing ? 1 : 0.85)
            .opacity(isShowing ? 1 : 0)
        }
        .onAppear {
            withAnimation(.spring(duration: 0.4)) {
                isShowing = true
            }
        }
        .sensoryFeedback(.success, trigger: isShowing)
        .accessibilityAddTraits(.isModal)
    }
}
