//
//  FinancialItem.swift
//  myNetworth
//
//  Created by BeastMode on 12/5/25.
//
import SwiftUI


// MARK: - Models
struct FinancialItem: Identifiable, Codable {
    var id = UUID()
    var name: String
    var amount: Int
    var year: Int
    var category: String
}

struct YearlyData: Identifiable {
    var id: Int { year }
    var year: Int
    var assets: Int
    var liabilities: Int
    var netWorth: Int
    var assetCategortyTotal: [AssetCategories: Int]
    var liabilityCategortyTotal: [LiabilityCategories: Int]
}


