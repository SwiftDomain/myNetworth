//
//  LiabilitiesView.swift
//  myNetworth
//
//  Created by BeastMode on 12/5/25.
//

import SwiftUI

// MARK: - Liabilities View
struct LiabilitiesView: View {
    @ObservedObject var viewModel: NetWorthViewModel
    let year: Int
    @State private var showingAddSheet = false
    
    var yearLiabilities: [FinancialItem] {
        viewModel.liabilities.filter { $0.year == year }
    }
    
    var body: some View {
        ZStack {

            Background(bgColor1: .bgLiability1, bgColor2: .bgLiability2)
            
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
                                onDelete: { viewModel.deleteLiability(liability) }
                            )
                        }
                        
                        if !yearLiabilities.isEmpty {
                            CategoryChartView(
                                data: viewModel.getCategoryData(for: .liability, year: year),
                                title: "Liabilities by Category",
                                color: .red
                            )
                        }
                    }
                }
                .padding()
            }
        }
        .toolbar {
            Button {
                showingAddSheet = true
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            AddItemView(viewModel: viewModel, type: .liability, year: year)
        }
    }
}

#Preview {

    LiabilitiesView(viewModel: NetWorthViewModel(), year: 2025)
}
