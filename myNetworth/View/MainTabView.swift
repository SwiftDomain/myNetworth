//
//  MainTabView.swift
//  myNetworth
//

import SwiftUI
import Charts
import WidgetKit

// MARK: - Privacy

/// Shows or hides every amount in the app.
struct HideAmountsButton: View {
    @AppStorage(SharedStore.hideAmountsKey, store: SharedStore.defaults) private var hideAmounts = false

    var body: some View {
        Button(
            hideAmounts ? "Show Amounts" : "Hide Amounts",
            systemImage: hideAmounts ? "eye.slash.fill" : "eye.fill"
        ) {
            hideAmounts.toggle()
        }
    }
}

/// Hides a chart's value axis while amounts are hidden, so its scale doesn't give them away.
private struct PrivateChartAxis: ViewModifier {
    @Environment(\.redactionReasons) private var redactionReasons

    func body(content: Content) -> some View {
        content.chartYAxis(redactionReasons.contains(.privacy) ? .hidden : .automatic)
    }
}

extension View {
    func privateChartAxis() -> some View {
        modifier(PrivateChartAxis())
    }
}

// MARK: - Main Tab View

enum AppTab: Hashable {
    case home, accounts, plan, settings
}

struct MainTabView: View {
    var viewModel: NetWorthViewModel
    @AppStorage(SharedStore.hideAmountsKey, store: SharedStore.defaults) private var hideAmounts = false
    @AppStorage(QuickStartView.seenKey) private var hasSeenQuickStart = false
    @State private var selectedTab = AppTab.home
    @State private var showingQuickStart = false

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Home", systemImage: "house.fill", value: AppTab.home) {
                HomeTab(viewModel: viewModel)
            }

            Tab("Accounts", systemImage: "list.bullet.rectangle.portrait.fill", value: AppTab.accounts) {
                AccountsTab(viewModel: viewModel)
            }

            Tab("Plan", systemImage: "target", value: AppTab.plan) {
                PlanTab(viewModel: viewModel)
            }

            Tab("Settings", systemImage: "gearshape.fill", value: AppTab.settings) {
                SettingsView(viewModel: viewModel)
            }
        }
        .overlay {
            if let goal = viewModel.goalToCelebrate {
                GoalCelebrationView(goal: goal, currencyCode: viewModel.currencyCode) {
                    viewModel.markCelebrated(goal)
                }
            }
        }
        // Amounts marked `.privacySensitive()` are masked while this is on.
        .redacted(reason: hideAmounts ? .privacy : [])
        .onChange(of: AppRouter.shared.checkInRequests) {
            selectedTab = .home
        }
        .onChange(of: hideAmounts) {
            // The widgets mask amounts too, so redraw them straight away.
            WidgetCenter.shared.reloadAllTimelines()
        }
        .onAppear {
            // New users start with setup rather than an empty app, once.
            if viewModel.years.isEmpty && !hasSeenQuickStart {
                showingQuickStart = true
            }
        }
        .fullScreenCover(isPresented: $showingQuickStart) {
            QuickStartView(viewModel: viewModel)
        }
    }
}

// MARK: - Plan Tab

struct PlanTab: View {
    var viewModel: NetWorthViewModel

    private var currency: IntegerFormatStyle<Int>.Currency {
        .currency(code: viewModel.currencyCode).precision(.fractionLength(0))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Background(bgColor1: Theme.mainGradient1, bgColor2: Theme.mainGradient2)

                ScrollView {
                    VStack(spacing: 16) {
                        NavigationLink {
                            GoalsListView(viewModel: viewModel)
                        } label: {
                            PlanRow(icon: "target", color: .blue, title: "Goals", detail: goalsDetail)
                        }

                        NavigationLink {
                            DebtPayoffView(viewModel: viewModel)
                        } label: {
                            PlanRow(
                                icon: "chart.line.downtrend.xyaxis",
                                color: .orange,
                                title: "Debt Payoff Planner",
                                detail: debtDetail,
                                isDetailPrivate: true
                            )
                        }

                        NavigationLink {
                            OverallAnalysisView(viewModel: viewModel)
                        } label: {
                            PlanRow(
                                icon: "chart.bar.fill",
                                color: .green,
                                title: "Analysis",
                                detail: Text("Net worth over time, year by year")
                            )
                        }

                        NavigationLink {
                            AskView(viewModel: viewModel)
                        } label: {
                            PlanRow(
                                icon: "bubble.left.and.text.bubble.right",
                                color: .purple,
                                title: "Ask About Your Money",
                                detail: Text("Questions about your numbers, answered on your iPhone")
                            )
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Plan")
            // The backgrounds are dark in every appearance, so keep the bar text light.
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    HideAmountsButton()
                }
            }
        }
    }

    private var goalsDetail: Text {
        let activeGoals = viewModel.goals.filter { !$0.isAchieved }
        guard let goal = viewModel.featuredGoal else {
            return viewModel.goals.isEmpty
                ? Text("Set a goal and track your progress")
                : Text("Every goal reached")
        }
        let percent = Int((viewModel.goalProgress(for: goal) * 100).rounded())
        return Text("\(activeGoals.count) active · \(goal.title) \(percent)%")
    }

    private var debtDetail: Text {
        let debts = viewModel.plannerDebts
        guard !debts.isEmpty else {
            return viewModel.currentDebts.isEmpty
                ? Text("No debts to pay off")
                : Text("Choose which debts to include")
        }
        let total = debts.reduce(0) { $0 + $1.balance }
        return Text("\(debts.count) \(debts.count == 1 ? "debt" : "debts") · \(total, format: currency)")
    }
}

/// A large row linking to one of the planning screens.
private struct PlanRow: View {
    let icon: String
    let color: Color
    let title: String
    let detail: Text
    var isDetailPrivate = false

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
                .frame(width: 40, height: 40)
                .background(color.opacity(0.15))
                .clipShape(.rect(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(Theme.textPrimary)

                if isDetailPrivate {
                    detail
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                        .privacySensitive()
                } else {
                    detail
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundStyle(Theme.textSecondary)
        }
        .padding()
        .background(Theme.cardBackground)
        .clipShape(.rect(cornerRadius: 16))
    }
}
