//
//  WidgetTests.swift
//  myNetworthTests
//
//  The Home Screen widget: what it shows, and that it ships inside the app.
//

import Foundation
import Testing
@testable import myNetworth

@MainActor
@Suite("Widget")
struct WidgetTests {

    private func item(_ name: String, _ amount: Int, year: Int, asset: Bool = true, month: Int = 0) -> FinancialItem {
        FinancialItem(
            name: name,
            amount: amount,
            year: year,
            month: month,
            category: asset ? "Cash" : "Credit Card",
            itemType: asset ? "asset" : "liability"
        )
    }

    @Test("Shows the latest year with data, not an empty or future year")
    func latestYearWithData() throws {
        let items = [
            item("Savings", 10_000, year: thisYear - 3),
            item("Savings", 12_000, year: thisYear - 1),
            item("Visa", 2_000, year: thisYear - 1, asset: false),
            item("Savings", 90_000, year: thisYear + 1),
        ]

        let snapshot = try #require(WidgetSnapshot.make(from: items))

        #expect(snapshot.year == thisYear - 1)
        #expect(snapshot.assets == 12_000)
        #expect(snapshot.liabilities == 2_000)
        #expect(snapshot.netWorth == 10_000)
        // Compared with the previous year that has data, skipping the gap.
        #expect(snapshot.previousYear == thisYear - 3)
        #expect(snapshot.percentageChange == 0)
        #expect(snapshot.trend.map(\.year) == [thisYear - 3, thisYear - 1])
    }

    @Test("The trend has each year's net worth up to the latest, oldest first")
    func trend() throws {
        let items = [
            item("Savings", 30_000, year: thisYear),
            item("Savings", 20_000, year: thisYear - 2),
            item("Visa", 5_000, year: thisYear - 2, asset: false),
            item("Savings", 22_000, year: thisYear - 1),
            // A monthly update counts once, at the latest amount.
            item("Savings", 25_000, year: thisYear - 1, month: 9),
            // A planning year isn't part of the trend.
            item("Savings", 90_000, year: thisYear + 1),
        ]

        let snapshot = try #require(WidgetSnapshot.make(from: items))

        #expect(snapshot.trend.map(\.year) == [thisYear - 2, thisYear - 1, thisYear])
        #expect(snapshot.trend.map(\.netWorth) == [15_000, 25_000, 30_000])
        #expect(snapshot.trend.last?.netWorth == snapshot.netWorth)
    }

    @Test("Percentage change since the previous year")
    func percentageChange() throws {
        let items = [
            item("Savings", 8_000, year: thisYear - 1),
            item("Savings", 10_000, year: thisYear),
        ]

        let snapshot = try #require(WidgetSnapshot.make(from: items))

        #expect(snapshot.percentageChange == 25)
    }

    @Test("Monthly updates count once, at the latest amount")
    func monthlyUpdatesCountOnce() throws {
        let items = [
            item("Savings", 5_000, year: thisYear),
            item("Savings", 6_000, year: thisYear, month: 3),
        ]

        let snapshot = try #require(WidgetSnapshot.make(from: items))

        #expect(snapshot.assets == 6_000)
        #expect(snapshot.previousYear == nil)
        #expect(snapshot.percentageChange == nil)
    }

    @Test("No snapshot without data up to this year")
    func noData() {
        #expect(WidgetSnapshot.make(from: [])?.year == nil)
        #expect(WidgetSnapshot.make(from: [item("Savings", 5_000, year: thisYear + 1)])?.year == nil)
    }

    @Test("No percentage when the previous net worth was zero")
    func noPercentFromZero() throws {
        let items = [
            item("Savings", 5_000, year: thisYear - 1),
            item("Visa", 5_000, year: thisYear - 1, asset: false),
            item("Savings", 6_000, year: thisYear),
        ]

        let snapshot = try #require(WidgetSnapshot.make(from: items))

        #expect(snapshot.previousYear == thisYear - 1)
        #expect(snapshot.percentageChange == nil)
    }

    @Test("Hide Amounts moves to the shared settings the widget reads, once")
    func hideAmountsMovesToSharedDefaults() {
        let key = SharedStore.hideAmountsKey
        let shared = SharedStore.defaults
        let standard = UserDefaults.standard
        guard shared !== standard else { return }
        let savedShared = shared.object(forKey: key)
        let savedStandard = standard.object(forKey: key)
        defer {
            if let savedShared { shared.set(savedShared, forKey: key) } else { shared.removeObject(forKey: key) }
            if let savedStandard { standard.set(savedStandard, forKey: key) } else { standard.removeObject(forKey: key) }
        }
        shared.removeObject(forKey: key)
        standard.set(true, forKey: key)

        SharedStore.moveSettingsToSharedDefaults()

        let movedValue = shared.bool(forKey: key)
        let leftInStandard = standard.object(forKey: key) != nil
        #expect(movedValue)
        #expect(!leftInStandard)

        // Once it's in the shared settings, later changes there aren't overwritten.
        shared.set(false, forKey: key)
        standard.set(true, forKey: key)
        SharedStore.moveSettingsToSharedDefaults()
        let keptValue = shared.bool(forKey: key)
        #expect(!keptValue)
    }

    @Test("The widget extension is built into the app")
    func widgetIsEmbedded() throws {
        let plugIns = try #require(Bundle.main.builtInPlugInsURL)
        let widget = try #require(Bundle(url: plugIns.appending(path: "NetWorthWidgetExtension.appex")))
        let mainIdentifier = try #require(Bundle.main.bundleIdentifier)
        let widgetIdentifier = try #require(widget.bundleIdentifier)
        let extensionInfo = widget.object(forInfoDictionaryKey: "NSExtension") as? [String: Any]

        #expect(widgetIdentifier.hasPrefix(mainIdentifier + "."))
        #expect(extensionInfo?["NSExtensionPointIdentifier"] as? String == "com.apple.widgetkit-extension")
    }

    @Test("The widget has the same version and build as the app, as the App Store requires")
    func widgetVersionMatchesApp() throws {
        let plugIns = try #require(Bundle.main.builtInPlugInsURL)
        let widget = try #require(Bundle(url: plugIns.appending(path: "NetWorthWidgetExtension.appex")))
        let appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        let appBuild = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        let widgetVersion = widget.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        let widgetBuild = widget.object(forInfoDictionaryKey: "CFBundleVersion") as? String

        #expect(appVersion != nil)
        #expect(widgetVersion == appVersion)
        #expect(widgetBuild == appBuild)
    }
}
