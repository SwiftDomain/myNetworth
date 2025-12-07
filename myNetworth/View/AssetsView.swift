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
            
            Background(bgColor1: .bgAsset1, bgColor2: .bgAsset2)
            
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
                                onDelete: { viewModel.deleteAsset(asset) }
                            )
                        }
                        
                        if !yearAssets.isEmpty {
                            CategoryChartView(
                                data: viewModel.getCategoryData(for: .asset, year: year),
                                title: "Assets by Category",
                                color: .green
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
