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
    
    let assetCategories = ["Cash", "Investments", "Real Estate", "Person", "Retirement", "Other"]
    let liabilityCategories = ["Mortgage", "Auto Loan", "Credit Card", "Student Loan", "Other"]
    
    init() {
        loadData()
    }
    
    var yearlyData: [YearlyData] {
        let allYears = Set(assets.map { $0.year } + liabilities.map { $0.year })
        return allYears.sorted().map { year in
            let totalAssets = assets.filter { $0.year == year }.reduce(0) { $0 + $1.amount }
            let totalLiabilities = liabilities.filter { $0.year == year }.reduce(0) { $0 + $1.amount }
            return YearlyData(
                year: year,
                assets: totalAssets,
                liabilities: totalLiabilities,
                netWorth: totalAssets - totalLiabilities
            )
        }
    }
    
    func getYearData(for year: Int) -> YearlyData {
        let totalAssets = assets.filter { $0.year == year }.reduce(0) { $0 + $1.amount }
        let totalLiabilities = liabilities.filter { $0.year == year }.reduce(0) { $0 + $1.amount }
        return YearlyData(
            year: year,
            assets: totalAssets,
            liabilities: totalLiabilities,
            netWorth: totalAssets - totalLiabilities
        )
    }
    
    func addYear(_ year: Int) {
        if !years.contains(year) {
            years.append(year)
            years.sort(by: >)
            saveData()
        }
    }
    
    func deleteYear(_ year: Int) {
        years.removeAll { $0 == year }
        assets.removeAll { $0.year == year }
        liabilities.removeAll { $0.year == year }
        saveData()
    }
    
    func addAsset(_ item: FinancialItem) {
        assets.append(item)
        saveData()
    }
    
    func addLiability(_ item: FinancialItem) {
        liabilities.append(item)
        saveData()
    }
    
    func deleteAsset(_ item: FinancialItem) {
        assets.removeAll { $0.id == item.id }
        saveData()
    }
    
    func deleteLiability(_ item: FinancialItem) {
        liabilities.removeAll { $0.id == item.id }
        saveData()
    }
    
    func getCategoryData(for type: ItemType, year: Int) -> [(String, Int)] {
        let items = type == .asset ? assets.filter { $0.year == year } : liabilities.filter { $0.year == year }
        var categories: [String: Int] = [:]
        
        for item in items {
            categories[item.category, default: 0] += item.amount
        }
        
        return categories.map { ($0.key, $0.value) }.sorted { $0.1 > $1.1 }
    }
    
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

enum ItemType {
    case asset, liability
}
