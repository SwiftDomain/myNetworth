//
//  NetWorthViewModel.swift
//  myNetworth
//
//  Created by BeastMode on 12/5/25.
//
import SwiftUI
import Combine

// MARK: - View Model
class NetWorthViewModel: ObservableObject {
    
    @Published var assets: [FinancialItem] = []
    @Published var liabilities: [FinancialItem] = []
    @Published var years: [Int] = []

    
    init() {
        loadData()
    }
    
    /* Computed property yearlyData.  An array of YearlyData*/
    var yearlyData: [YearlyData] {
        let allYears = Set(assets.map { $0.year } + liabilities.map { $0.year })
        return allYears.sorted().map { year in
            let totalAssets = assets.filter { $0.year == year }.reduce(0) { $0 + $1.amount }
            let totalLiabilities = liabilities.filter { $0.year == year }.reduce(0) { $0 + $1.amount }
            return YearlyData(
                year: year,
                assets: totalAssets,
                liabilities: totalLiabilities,
                netWorth: totalAssets - totalLiabilities,
                assetCategortyTotal: [.cash:12],
                liabilityCategortyTotal: [.autoLoan:23]
            )
        }
    }
    
    /* Get all the assets and liabilities for a given year. */
    func getYearData(for year: Int) -> YearlyData {
        
        let totalAssets = assets.filter { $0.year == year }.reduce(0) { $0 + $1.amount }
        let totalLiabilities = liabilities.filter { $0.year == year }.reduce(0) { $0 + $1.amount }
        
        var totalAssetCategories: [AssetCategories: Int] = [:]
        var totalLiabilityCategories: [LiabilityCategories: Int] = [:]
        
        
        for category in AssetCategories.allCases {
                totalAssetCategories[category] = assets.filter { $0.year == year && $0.category == category.rawValue}.reduce(0) { $0 + $1.amount }
        }
        
        for category in LiabilityCategories.allCases {
            totalLiabilityCategories[category] = liabilities.filter { $0.year == year && $0.category == category.rawValue}.reduce(0) { $0 + $1.amount }            
        }
        
        return YearlyData(
            year: year,
            assets: totalAssets,
            liabilities: totalLiabilities,
            netWorth: totalAssets - totalLiabilities,
            assetCategortyTotal: totalAssetCategories,
            liabilityCategortyTotal: totalLiabilityCategories
        )
    }
    
    /* Add a year */
    func addYear(_ year: Int) {
        if !years.contains(year) {
            years.append(year)
            years.sort(by: >)
            saveData()
        }
    }
    
    /* Delete a year with all the data from the year.  Assets and liabilites. */
    func deleteYear(_ year: Int) {
        years.removeAll { $0 == year }
        assets.removeAll { $0.year == year }
        liabilities.removeAll { $0.year == year }
        saveData()
    }
    
    /* Add an asset */
    func addAsset(_ item: FinancialItem) {
        assets.append(item)
        saveData()
    }
    
    /* Add a liability */
    func addLiability(_ item: FinancialItem) {
        liabilities.append(item)
        saveData()
    }
    
    /* Delete the asset */
    func deleteAsset(_ item: FinancialItem) {
        assets.removeAll { $0.id == item.id }
        saveData()
    }
    
    /* Delete the liability */
    func deleteLiability(_ item: FinancialItem) {
        liabilities.removeAll { $0.id == item.id }
        saveData()
    }
    
    /* Return a dictionary with all assets or liabilities for the itemType i.e (Asset or Liability) */
    func getCategoryData(for type: ItemType, year: Int) -> [(String, Int)] {
        
        let items = type == .asset ? assets.filter { $0.year == year } : liabilities.filter { $0.year == year }
        var categories: [String: Int] = [:]
        
        for item in items {
            categories[item.category, default: 0] += item.amount
        }
        
        return categories.map { ($0.key, $0.value) }.sorted { $0.1 > $1.1 }
        
    }
    
    /* Save the data to memory */
    private func saveData() {
        let defaults = UserDefaults.standard
        
        if let assetsData = try? JSONEncoder().encode(assets),
           let assetsString = String(data: assetsData, encoding: .utf8) {
            defaults.set(assetsString, forKey: "assets")
        }
        
        if let liabilitiesData = try? JSONEncoder().encode(liabilities),
           let liabilitiesString = String(data: liabilitiesData, encoding: .utf8) {
            defaults.set(liabilitiesString, forKey: "liabilities")
        }
        
        if let yearsData = try? JSONEncoder().encode(years),
           let yearsString = String(data: yearsData, encoding: .utf8) {
            defaults.set(yearsString, forKey: "years")
        }
        
    }
    
    /* Load data from memory */
    private func loadData() {
        
        let defaults = UserDefaults.standard
        
        if let assetsString = defaults.string(forKey: "assets"),
           let assetsData = assetsString.data(using: .utf8),
           let decodedAssets = try? JSONDecoder().decode([FinancialItem].self, from: assetsData) {
            self.assets = decodedAssets
        }
        
        if let liabilitiesString = defaults.string(forKey: "liabilities"),
           let liabilitiesData = liabilitiesString.data(using: .utf8),
           let decodedLiabilities = try? JSONDecoder().decode([FinancialItem].self, from: liabilitiesData) {
            self.liabilities = decodedLiabilities
        }
        
        if let yearsString = defaults.string(forKey: "years"),
           let yearsData = yearsString.data(using: .utf8),
           let decodedYears = try? JSONDecoder().decode([Int].self, from: yearsData) {
            self.years = decodedYears
            self.years.sort(by: >)
        }
        
    }
    
    
    func refreshData() {
        loadData()
    }
}

/* Financial item type */
enum ItemType {
    case asset, liability
}

/* Asset categories */
enum AssetCategories: String, Codable, CaseIterable {
    
    case cash = "Cash", investments = "Investments", realEstate = "Real Estate", retirement = "Retirement", vehicle = "Vehicle", crypto = "Crypto", furniture = "Furniture", jewelry = "Jewelry", other = "Other"
    
    var assetColor: Color {
        
        switch self {
            
        case .cash: return .green
        case .investments: return .orange
        case .realEstate: return .yellow
        case .other: return .black
        case .crypto: return .mint
        case .retirement: return .blue
        case .vehicle: return .brown
        case .furniture: return .orange
        case .jewelry: return .red
            
        }
    }
}

/* Liability categories */
enum LiabilityCategories: String, Codable, CaseIterable{
    
    case mortgage = "Mortgage", autoLoan = "Auto Loan", creditCard = "Credit Card", studentLoan = "Student Loan", other = "Other"
    
    var liabilityColor: Color{
        
        switch self {
            
        case .mortgage: return .green
        case .autoLoan: return .orange
        case .creditCard: return .red
        case .studentLoan: return .blue
        case .other: return .black
            
        }
    }
}
