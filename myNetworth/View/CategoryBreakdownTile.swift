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
    var currencyCode: String = "USD"
    @Environment(\.assetColor) private var assetColor
    @Environment(\.liabilityColor) private var liabilityColor

    private var categories: [(String, Int, Color)] {
        switch type {
        case .asset:
            return yearData.assetCategoryTotal
                .filter { $0.value > 0 }
                .sorted { $0.value > $1.value }
                .map { key, value in
                    (key.rawValue, value, assetColor)
                }
        case .liability:
            return yearData.liabilityCategoryTotal
                .filter { $0.value > 0 }
                .sorted { $0.value > $1.value }
                .map { key, value in
                    (key.rawValue, value, liabilityColor)
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
            Text(title)
                .font(.headline)
                .foregroundStyle(Theme.textPrimary)

            if categories.isEmpty {
                Text("No \(type == .asset ? "assets" : "liabilities") recorded")
                    .foregroundStyle(Theme.textSecondary.opacity(0.8))
                    .font(.subheadline)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            } else {
                VStack(spacing: 12) {
                    ForEach(categories, id: \.0) { category, amount, color in
                        CategoryRow(
                            name: category,
                            amount: amount,
                            total: total,
                            color: color,
                            currencyCode: currencyCode
                        )
                    }
                }
            }
        }
        .padding()
        .background(Theme.subtleBackground)
        .clipShape(.rect(cornerRadius: 16))
    }
}

// MARK: - Category Row

struct CategoryRow: View {
    let name: String
    let amount: Int
    let total: Int
    let color: Color
    var currencyCode: String = "USD"

    private var percentage: Double {
        guard total > 0 else { return 0 }
        return Double(amount) / Double(total)
    }

    var body: some View {
        VStack(spacing: 6) {
            HStack {
                HStack(spacing: 8) {
                    Circle()
                        .fill(color)
                        .frame(width: 8, height: 8)

                    Text(name)
                        .font(.subheadline)
                        .foregroundStyle(Theme.textPrimary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(amount, format: .currency(code: currencyCode).precision(.fractionLength(0)))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(Theme.textPrimary)

                    Text("\(Int(percentage * 100))%")
                        .font(.caption2)
                        .foregroundStyle(Theme.textSecondary.opacity(0.8))
                }
            }

            // Progress bar (replaced GeometryReader with scaleEffect)
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Color.white.opacity(0.1))
                    .frame(height: 4)
                    .clipShape(.rect(cornerRadius: 2))

                Rectangle()
                    .fill(color)
                    .frame(height: 4)
                    .clipShape(.rect(cornerRadius: 2))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .scaleEffect(x: percentage, anchor: .leading)
            }
            .frame(height: 4)
        }
    }
}
