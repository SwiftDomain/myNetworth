//
//  LiabilitiesView.swift
//  myNetworth
//
//  Created by BeastMode on 12/5/25.
//

import SwiftUI
import SwiftData

// MARK: - Liabilities View

struct LiabilitiesView: View {

    var viewModel: NetWorthViewModel
    let year: Int

    private var yearLiabilities: [FinancialItem] {
        viewModel.filteredItems(viewModel.liabilities.filter { $0.year == year })
    }

    var body: some View {
        ZStack {
            Background(bgColor1: Theme.liabilityGradient1, bgColor2: Theme.liabilityGradient2)

            ScrollView {
                VStack(spacing: 16) {
                    if yearLiabilities.isEmpty {
                        EmptyStateView(
                            icon: "creditcard",
                            message: "No liabilities yet",
                            subMessage: "Add your debts for \(year)"
                        )
                        .padding(.top, 100)
                    } else {
                        ForEach(yearLiabilities) { liability in
                            FinancialItemCard(
                                item: liability,
                                type: .liability,
                                currencyCode: viewModel.currencyCode,
                                onDelete: { viewModel.deleteLiability(liability) }
                            )
                        }

                        CategoryChartView(
                            data: viewModel.getCategoryData(for: .liability, year: year),
                            title: "Liabilities by Category",
                            color: viewModel.liabilityColor
                        )
                    }
                }
                .padding()
            }
        }
        .searchable(text: Bindable(viewModel).searchText, prompt: "Search liabilities")
    }
}

#Preview {
    LiabilitiesView(
        viewModel: NetWorthViewModel(modelContext: try! ModelContainer(
            for: FinancialItem.self, TrackedYear.self, UserSettings.self,
            Goal.self, RecurringItem.self, Milestone.self, CustomCategory.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        ).mainContext),
        year: 2025
    )
}
