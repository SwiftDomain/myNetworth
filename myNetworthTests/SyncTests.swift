//
//  SyncTests.swift
//  myNetworthTests
//
//  iCloud sync: records two devices both created are cleaned up the same way on each.
//

import Foundation
import SwiftData
import Testing
@testable import myNetworth

@MainActor
@Suite("iCloud sync")
struct SyncTests {

    private let older = Date(timeIntervalSince1970: 1_700_000_000)
    private let newer = Date(timeIntervalSince1970: 1_710_000_000)

    @Test("A year added on two devices is listed once, then the copy is removed")
    func duplicateYears() throws {
        let store = try TestStore()
        let original = TrackedYear(year: 2024)
        original.createdAt = older
        let copy = TrackedYear(year: 2024)
        copy.createdAt = newer
        store.context.insert(original)
        store.context.insert(copy)
        store.context.insert(TrackedYear(year: 2025))

        // Listed once even before the cleanup.
        #expect(store.viewModel.years == [2025, 2024])

        store.viewModel.refreshFromStore()

        let saved = try store.context.fetch(FetchDescriptor<TrackedYear>())
        let years = saved.map(\.year).sorted()
        #expect(years == [2024, 2025])
        let kept = try #require(saved.first { $0.year == 2024 })
        #expect(kept.createdAt == older)
    }

    @Test("Every device keeps the oldest settings, so a new device's defaults don't win")
    func duplicateSettings() throws {
        let store = try TestStore()
        let original = UserSettings(currencyCode: "EUR")
        original.createdAt = older
        let newDevice = UserSettings(currencyCode: "USD")
        newDevice.createdAt = newer
        store.context.insert(newDevice)
        store.context.insert(original)

        #expect(store.viewModel.currencyCode == "EUR")

        store.viewModel.refreshFromStore()

        let saved = try store.context.fetch(FetchDescriptor<UserSettings>())
        #expect(saved.count == 1)
        #expect(saved.first?.currencyCode == "EUR")
    }

    @Test("Custom categories and debt terms made on two devices are kept once")
    func duplicateCategoriesAndTerms() throws {
        let store = try TestStore()
        let category = CustomCategory(name: "Brokerage", itemType: "asset")
        category.createdAt = older
        let categoryCopy = CustomCategory(name: "brokerage", itemType: "asset")
        categoryCopy.createdAt = newer
        // Same name, other type: a different category.
        let debtCategory = CustomCategory(name: "Brokerage", itemType: "liability")
        let terms = DebtTerms(name: "Visa", category: "Credit Card", annualRate: 24.9, minimumPayment: 90, isIncludedInPlan: true)
        terms.createdAt = older
        let termsCopy = DebtTerms(name: "Visa", category: "Credit Card", annualRate: 19.9, minimumPayment: 50, isIncludedInPlan: true)
        termsCopy.createdAt = newer
        for model in [category, categoryCopy, debtCategory] {
            store.context.insert(model)
        }
        store.context.insert(terms)
        store.context.insert(termsCopy)

        store.viewModel.refreshFromStore()

        let categories = try store.context.fetch(FetchDescriptor<CustomCategory>())
        let names = categories.map { "\($0.itemType) \($0.name)" }.sorted()
        #expect(names == ["asset Brokerage", "liability Brokerage"])
        let savedTerms = try store.context.fetch(FetchDescriptor<DebtTerms>())
        #expect(savedTerms.count == 1)
        #expect(savedTerms.first?.annualRate == 24.9)
    }

    @Test("Nothing is removed when there are no copies")
    func noDuplicates() throws {
        let store = try TestStore()
        store.viewModel.addYear(2024)
        store.viewModel.addYear(2025)
        store.viewModel.addCustomCategory(CustomCategory(name: "Brokerage", itemType: "asset"))

        store.viewModel.refreshFromStore()

        #expect(store.viewModel.years == [2025, 2024])
        #expect(store.viewModel.customCategories.count == 1)
    }
}
