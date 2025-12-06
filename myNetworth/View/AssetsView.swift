//
//  AssetsView.swift
//  myNetworth
//
//  Created by BeastMode on 12/5/25.
//

import SwiftUI

// MARK: - Assets View
struct AssetsView: View {
    
    @ObservedObject var viewModel: NetWorthViewModel
    @State private var showingAddSheet = false
    
    let year: Int
    
    var yearAssets: [FinancialItem] {
        viewModel.assets.filter { $0.year == year }
    }
    
    var body: some View {
        
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.05, green: 0.25, blue: 0.15), Color(red: 0.1, green: 0.35, blue: 0.2)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 16) {
                
                if !yearAssets.isEmpty {
                    CategoryChartView(
                        data: viewModel.getCategoryData(for: .asset, year: year),
                        title: "Assets by Category",
                        color: .green
                    )
                    .padding(.horizontal, 20)
                }
                
                ScrollView {
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
                                onDelete: { viewModel.deleteAsset(asset) }
                            )
                        }
                        
                    }
                }
                .padding()
            }
        }
    }
}

#Preview {
    AssetsView(viewModel: NetWorthViewModel(), year: 2025)
}
