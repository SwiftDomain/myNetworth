//
//  AllItemsView.swift
//  myNetworth
//
//  Created by BeastMode on 12/5/25.
//

import SwiftUI

// MARK: - All Items View
struct AllItemsView: View {
   
    @ObservedObject var viewModel: NetWorthViewModel
   
    @State private var showingAddSheet = false
    @State private var addItemType: ItemType = .asset
    
    let year: Int
    
    var yearAssets: [FinancialItem] {
        viewModel.assets.filter { $0.year == year }
    }
    
    var yearLiabilities: [FinancialItem] {
        viewModel.liabilities.filter { $0.year == year }
    }
    
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.05, green: 0.15, blue: 0.35), Color(red: 0.1, green: 0.25, blue: 0.45)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Add Buttons at Top
                HStack(spacing: 12) {
                    Button {
                        addItemType = .asset
                        showingAddSheet = true
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Add Asset")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            LinearGradient(
                                colors: [Color.green.opacity(0.6), Color.green.opacity(0.8)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(12)
                    }
                    
                    Button {
                        addItemType = .liability
                        showingAddSheet = true
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Add Liability")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            LinearGradient(
                                colors: [Color.red.opacity(0.6), Color.red.opacity(0.8)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(12)
                    }
                }
                .padding()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Quick Stats
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Assets")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.7))
                                Text(viewModel.getYearData(for: year).assets, format: .currency(code: "USD"))
                                    .font(.headline)
                                    .foregroundColor(.green)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(12)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Liabilities")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.7))
                                Text(viewModel.getYearData(for: year).liabilities, format: .currency(code: "USD"))
                                    .font(.headline)
                                    .foregroundColor(.red)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(12)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Net Worth")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.7))
                            Text(viewModel.getYearData(for: year).netWorth, format: .currency(code: "USD"))
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.blue)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(
                            LinearGradient(
                                colors: [Color.blue.opacity(0.3), Color.blue.opacity(0.4)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(12)
                        
                        // Assets Section
                        if !yearAssets.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Image(systemName: "dollarsign.circle.fill")
                                        .foregroundColor(.green)
                                    Text("Assets")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                    Spacer()
                                    Text("\(yearAssets.count)")
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.7))
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.green.opacity(0.3))
                                        .cornerRadius(8)
                                }
                                
                                ForEach(yearAssets) { asset in
                                    FinancialItemCard(
                                        item: asset,
                                        type: .asset,
                                        onDelete: { viewModel.deleteAsset(asset) }
                                    )
                                }
                            }
                        }
                        
                        // Liabilities Section
                        if !yearLiabilities.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Image(systemName: "creditcard.fill")
                                        .foregroundColor(.red)
                                    Text("Liabilities")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                    Spacer()
                                    Text("\(yearLiabilities.count)")
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.7))
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.red.opacity(0.3))
                                        .cornerRadius(8)
                                }
                                
                                ForEach(yearLiabilities) { liability in
                                    FinancialItemCard(
                                        item: liability,
                                        type: .liability,
                                        onDelete: { viewModel.deleteLiability(liability) }
                                    )
                                }
                            }
                        }
                        
                        // Empty State
                        if yearAssets.isEmpty && yearLiabilities.isEmpty {
                            EmptyStateView(
                                icon: "tray",
                                message: "No items yet",
                                subMessage: "Add your first asset or liability for \(year)"
                            )
                            .padding(.top, 40)
                        }
                    }
                    .padding()
                }
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            AddItemView(viewModel: viewModel, type: addItemType, year: year)
        }
    }
}

// MARK: - Supporting Views
struct FinancialItemCard: View {
    let item: FinancialItem
    let type: ItemType
    let onDelete: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text(item.category)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
                
                Text(item.amount, format: .currency(code: "USD"))
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(type == .asset ? .green : .red)
            }
            
            Spacer()
            
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .foregroundColor(.red.opacity(0.8))
            }
        }
        .padding()
        .background(Color.white.opacity(0.1))
        .cornerRadius(12)
    }
}

#Preview {
    AllItemsView(viewModel: NetWorthViewModel(), year: 2025)
}

