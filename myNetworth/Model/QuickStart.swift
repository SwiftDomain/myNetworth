//
//  QuickStart.swift
//  myNetworth
//

import Foundation

/// A common account offered as a tile in quick-start setup.
struct StarterAccount: Identifiable, Hashable {
    let name: String
    let category: String
    let isAsset: Bool
    /// An SF Symbol for the tile.
    let icon: String

    var id: String { name }

    var itemType: String { isAsset ? "asset" : "liability" }

    static let assets: [StarterAccount] = [
        StarterAccount(name: "Checking", category: AssetCategories.cash.rawValue, isAsset: true, icon: "building.columns"),
        StarterAccount(name: "Savings", category: AssetCategories.cash.rawValue, isAsset: true, icon: "banknote"),
        StarterAccount(name: "401(k)", category: AssetCategories.retirement.rawValue, isAsset: true, icon: "chart.line.uptrend.xyaxis"),
        StarterAccount(name: "IRA", category: AssetCategories.retirement.rawValue, isAsset: true, icon: "leaf"),
        StarterAccount(name: "Brokerage", category: AssetCategories.investments.rawValue, isAsset: true, icon: "chart.bar"),
        StarterAccount(name: "Home", category: AssetCategories.realEstate.rawValue, isAsset: true, icon: "house"),
        StarterAccount(name: "Car", category: AssetCategories.vehicle.rawValue, isAsset: true, icon: "car"),
        StarterAccount(name: "Crypto", category: AssetCategories.crypto.rawValue, isAsset: true, icon: "bitcoinsign.circle"),
    ]

    static let debts: [StarterAccount] = [
        StarterAccount(name: "Credit Card", category: LiabilityCategories.creditCard.rawValue, isAsset: false, icon: "creditcard"),
        StarterAccount(name: "Car Loan", category: LiabilityCategories.autoLoan.rawValue, isAsset: false, icon: "car.circle"),
        StarterAccount(name: "Student Loan", category: LiabilityCategories.studentLoan.rawValue, isAsset: false, icon: "graduationcap"),
        StarterAccount(name: "Mortgage", category: LiabilityCategories.mortgage.rawValue, isAsset: false, icon: "house.circle"),
        StarterAccount(name: "Personal Loan", category: LiabilityCategories.other.rawValue, isAsset: false, icon: "doc.text"),
    ]
}
