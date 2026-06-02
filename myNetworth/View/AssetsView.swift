//
//  AssetsView.swift
//  myNetworth
//
//  Created by BeastMode on 12/5/25.
//

import SwiftUI
import SwiftData

// MARK: - Assets View

struct AssetsView: View {

    var viewModel: NetWorthViewModel

    let year: Int

    private var yearAssets: [FinancialItem] {
        viewModel.filteredItems(viewModel.assets.filter { $0.year == year })
    }

    var body: some View {
        ZStack {
            Background(bgColor1: Theme.assetGradient1, bgColor2: Theme.assetGradient2)

            ScrollView {
                VStack(spacing: 16) {
                    if yearAssets.isEmpty {
                        EmptyStateView(
                            icon: "dollarsign.circle",
                            message: "No assets yet",
                            subMessage: "Add your first asset for \(year)"
                        )
                        .padding(.top, 100)
                    } else {
                        ForEach(yearAssets) { asset in
                            FinancialItemCard(
                                item: asset,
                                type: .asset,
                                currencyCode: viewModel.currencyCode,
                                onDelete: { viewModel.deleteAsset(asset) }
                            )
                        }

                        CategoryChartView(
                            data: viewModel.getCategoryData(for: .asset, year: year),
                            title: "Assets by Category",
                            color: viewModel.assetColor
                        )
                    }
                }
                .padding()
            }
        }
        .searchable(text: Bindable(viewModel).searchText, prompt: "Search assets")
    }
}

#Preview {
    AssetsView(
        viewModel: NetWorthViewModel(modelContext: try! ModelContainer(
            for: FinancialItem.self, TrackedYear.self, UserSettings.self,
            Goal.self, RecurringItem.self, Milestone.self, CustomCategory.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        ).mainContext),
        year: 2025
    )
}
