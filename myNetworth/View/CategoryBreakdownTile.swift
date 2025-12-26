//
//  CategoryBreakdownTile.swift
//  myNetworth
//
//  Created by BeastMode on 12/26/25.
//


import SwiftUI
import Charts

// MARK: - Category Breakdown Tile
struct CategoryBreakdownTile: View {
    let yearData: YearlyData
    let type: ItemType
    
    private var categories: [(String, Int, Color)] {
        switch type {
        case .asset:
            return yearData.assetCategortyTotal
                .filter { $0.value > 0 }
                .sorted { $0.value > $1.value }
                .map { (key, value) in
                    let category = AssetCategories(rawValue: key.rawValue) ?? .other
                    return (key.rawValue, value, category.assetColor)
                }
        case .liability:
            return yearData.liabilityCategortyTotal
                .filter { $0.value > 0 }
                .sorted { $0.value > $1.value }
                .map { (key, value) in
                    let category = LiabilityCategories(rawValue: key.rawValue) ?? .other
                    return (key.rawValue, value, category.liabilityColor)
                }
        }
    }
    
    private var title: String {
        type == .asset ? "Assets by Category" : "Liabilities by Category"
    }
    
    private var total: Int {
        type == .asset ? yearData.assets : yearData.liabilities
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            Text(title)
                .font(.headline)
                .foregroundColor(.white)
            
            if categories.isEmpty {
                Text("No \(type == .asset ? "assets" : "liabilities") recorded")
                    .foregroundColor(.white.opacity(0.6))
                    .font(.subheadline)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            } else {
                // Category List
                VStack(spacing: 12) {
                    ForEach(categories, id: \.0) { category, amount, color in
                        CategoryRow(
                            name: category,
                            amount: amount,
                            total: total,
                            color: color
                        )
                    }
                }
            }
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(16)
    }
}

// MARK: - Category Row
struct CategoryRow: View {
    let name: String
    let amount: Int
    let total: Int
    let color: Color
    
    private var percentage: Double {
        guard total > 0 else { return 0 }
        return Double(amount) / Double(total)
    }
    
    var body: some View {
        VStack(spacing: 6) {
            HStack {
                // Category name with color indicator
                HStack(spacing: 8) {
                    Circle()
                        .fill(color)
                        .frame(width: 8, height: 8)
                    
                    Text(name)
                        .font(.subheadline)
                        .foregroundColor(.white)
                }
                
                Spacer()
                
                // Amount and percentage
                VStack(alignment: .trailing, spacing: 2) {
                    Text(formatNumber(amount))
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.white)
                    
                    Text("\(Int(percentage * 100))%")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.6))
                }
            }
            
            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    Rectangle()
                        .fill(Color.white.opacity(0.1))
                        .frame(height: 4)
                        .cornerRadius(2)
                    
                    // Foreground
                    Rectangle()
                        .fill(color)
                        .frame(width: geometry.size.width * percentage, height: 4)
                        .cornerRadius(2)
                }
            }
            .frame(height: 4)
        }
    }
}
