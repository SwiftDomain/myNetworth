//
//  TestSupport.swift
//  myNetworthTests
//

import Foundation
import SwiftData
@testable import myNetworth

/// The calendar year the tests run in. Goals and the debt planner measure against it.
let thisYear = Calendar.current.component(.year, from: .now)

/// A view model backed by its own in-memory store, so every test starts empty.
@MainActor
struct TestStore {
    /// Kept so the store stays alive for as long as the test uses it.
    let container: ModelContainer
    let viewModel: NetWorthViewModel

    var context: ModelContext { container.mainContext }

    init() throws {
        let schema = SharedStore.schema
        let configuration = ModelConfiguration(
            UUID().uuidString,
            schema: schema,
            isStoredInMemoryOnly: true,
            cloudKitDatabase: .none
        )
        container = try ModelContainer(for: schema, configurations: [configuration])
        viewModel = NetWorthViewModel(modelContext: container.mainContext)
    }

    @discardableResult
    func addItem(
        _ name: String,
        _ amount: Int,
        year: Int,
        category: String,
        asset: Bool,
        month: Int = 0
    ) -> FinancialItem {
        let item = FinancialItem(
            name: name,
            amount: amount,
            year: year,
            month: month,
            category: category,
            itemType: asset ? "asset" : "liability"
        )
        viewModel.addItem(item)
        return item
    }
}
