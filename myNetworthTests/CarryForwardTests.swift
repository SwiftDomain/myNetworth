//
//  CarryForwardTests.swift
//  myNetworthTests
//
//  Feature 1: accounts that carry forward, and the Update Balances check-in.
//

import Foundation
import SwiftData
import Testing
@testable import myNetworth

@MainActor
@Suite("Accounts that carry forward")
struct CarryForwardTests {

    @Test("A new year starts from the closest earlier year with yearly items")
    func carryForwardSource() throws {
        let store = try TestStore()
        let viewModel = store.viewModel
        viewModel.addYear(2022)
        viewModel.addYear(2023)
        viewModel.addYear(2024)
        store.addItem("Savings", 1_000, year: 2022, category: "Cash", asset: true)
        store.addItem("Savings", 2_000, year: 2023, category: "Cash", asset: true)
        // 2024 only has a monthly entry, so there's nothing yearly to copy from it.
        store.addItem("Bonus", 500, year: 2024, category: "Cash", asset: true, month: 4)

        #expect(viewModel.carryForwardSource(for: 2025) == 2023)
        #expect(viewModel.carryForwardSource(for: 2023) == 2022)
        #expect(viewModel.carryForwardSource(for: 2022) == nil)
    }

    @Test("Starting from a previous year copies its yearly items and amounts")
    func addYearCopiesItems() throws {
        let store = try TestStore()
        let viewModel = store.viewModel
        viewModel.addYear(2024)
        store.addItem("Savings", 5_000, year: 2024, category: "Cash", asset: true)
        store.addItem("Visa", 1_200, year: 2024, category: "Credit Card", asset: false)
        store.addItem("Bonus", 800, year: 2024, category: "Cash", asset: true, month: 6)

        viewModel.addYear(2025, copyingItemsFrom: 2024)

        let copies = viewModel.yearlyItems(in: 2025).sorted { $0.name < $1.name }
        #expect(copies.map(\.name) == ["Savings", "Visa"])
        #expect(copies.map(\.amount) == [5_000, 1_200])
        #expect(copies.map(\.category) == ["Cash", "Credit Card"])
        #expect(copies.map(\.itemType) == ["asset", "liability"])
        #expect(viewModel.getYearData(for: 2025).netWorth == 3_800)
        #expect(viewModel.years == [2025, 2024])

        // The copies are new items; the year they came from is unchanged.
        let originals = viewModel.yearlyItems(in: 2024)
        #expect(originals.count == 2)
        #expect(Set(copies.map(\.id)).isDisjoint(with: originals.map(\.id)))
    }

    @Test("Starting empty adds the year with no items")
    func addEmptyYear() throws {
        let store = try TestStore()
        let viewModel = store.viewModel
        viewModel.addYear(2024)
        store.addItem("Savings", 5_000, year: 2024, category: "Cash", asset: true)

        viewModel.addYear(2025)

        #expect(viewModel.years == [2025, 2024])
        #expect(viewModel.yearlyItems(in: 2025).isEmpty)
    }

    @Test("Adding a year that already exists doesn't copy items again")
    func addExistingYear() throws {
        let store = try TestStore()
        let viewModel = store.viewModel
        viewModel.addYear(2024)
        store.addItem("Savings", 5_000, year: 2024, category: "Cash", asset: true)

        viewModel.addYear(2025, copyingItemsFrom: 2024)
        viewModel.addYear(2025, copyingItemsFrom: 2024)

        #expect(viewModel.years == [2025, 2024])
        #expect(viewModel.yearlyItems(in: 2025).count == 1)
    }

    @Test("Update Balances saves only the amounts that changed")
    func updateAmounts() throws {
        let store = try TestStore()
        let viewModel = store.viewModel
        viewModel.addYear(2025)
        let savings = store.addItem("Savings", 5_000, year: 2025, category: "Cash", asset: true)
        let car = store.addItem("Car", 9_000, year: 2025, category: "Vehicle", asset: true)
        let visa = store.addItem("Visa", 1_200, year: 2025, category: "Credit Card", asset: false)
        let visaUpdatedAt = visa.updatedAt

        // Savings was updated, Visa was confirmed as the same, Car was skipped.
        viewModel.updateAmounts([savings.id: 6_500, visa.id: 1_200], of: [savings, car, visa])

        #expect(savings.amount == 6_500)
        #expect(car.amount == 9_000)
        #expect(visa.amount == 1_200)
        #expect(visa.updatedAt == visaUpdatedAt)
        let year = viewModel.getYearData(for: 2025)
        #expect(year.assets == 15_500)
        #expect(year.liabilities == 1_200)
    }
}
