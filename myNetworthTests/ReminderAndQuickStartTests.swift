//
//  ReminderAndQuickStartTests.swift
//  myNetworthTests
//
//  Feature 1: the monthly reminder and quick-start setup.
//

import Foundation
import SwiftData
import Testing
import UserNotifications
@testable import myNetworth

// MARK: - Monthly Reminder

@MainActor
@Suite("Monthly reminder")
struct ReminderTests {

    @Test("Repeats on the chosen day and time each month")
    func schedule() {
        let firstAtNine = BalanceReminder.dateComponents(day: 1, minute: BalanceReminder.defaultMinute)
        #expect(firstAtNine.day == 1)
        #expect(firstAtNine.hour == 9)
        #expect(firstAtNine.minute == 0)
        #expect(firstAtNine.month == nil)

        let evening = BalanceReminder.dateComponents(day: 15, minute: 18 * 60 + 30)
        #expect(evening.day == 15)
        #expect(evening.hour == 18)
        #expect(evening.minute == 30)
    }

    @Test("Days that some months don't have are kept within 1–28")
    func dayIsClamped() {
        #expect(BalanceReminder.dateComponents(day: 31, minute: 0).day == 28)
        #expect(BalanceReminder.dateComponents(day: 0, minute: 0).day == 1)
    }

    @Test("The notification never shows amounts")
    func contentHasNoAmounts() {
        let content = BalanceReminder.content()
        let titleHasDigits = content.title.contains { $0.isNumber }
        let bodyHasDigits = content.body.contains { $0.isNumber }

        #expect(content.title == "Time to update your balances")
        #expect(!titleHasDigits)
        #expect(!bodyHasDigits)
    }

    @Test("A tap is counted and waits until Home opens the check-in")
    func routerKeepsTheRequest() {
        let router = AppRouter()

        router.requestCheckIn()

        #expect(router.checkInRequests == 1)
        #expect(router.hasPendingCheckIn)
    }

    // MARK: What the reminder opens

    @Test("Opens setup when nothing has been added")
    func checkInWithNoYears() throws {
        let store = try TestStore()
        #expect(store.viewModel.checkInStep() == NextStep.addFirstYear)
    }

    @Test("Offers to start this year when it hasn't been added")
    func checkInStartsYear() throws {
        let store = try TestStore()
        store.viewModel.addYear(thisYear - 1)
        store.addItem("Savings", 10_000, year: thisYear - 1, category: "Cash", asset: true)

        #expect(store.viewModel.checkInStep() == NextStep.startYear(thisYear, from: thisYear - 1))
    }

    @Test("Opens Update Balances for this year, even when balances are recent")
    func checkInUpdatesBalances() throws {
        let store = try TestStore()
        store.viewModel.addYear(thisYear)
        let savings = store.addItem("Savings", 10_000, year: thisYear, category: "Cash", asset: true)

        #expect(store.viewModel.checkInStep() == NextStep.updateBalances(year: thisYear, lastUpdated: savings.updatedAt))
    }

    @Test("Opens this year's accounts when there's nothing for Update Balances")
    func checkInAddsAccounts() throws {
        let store = try TestStore()
        store.viewModel.addYear(thisYear)
        #expect(store.viewModel.checkInStep() == NextStep.addAccounts(year: thisYear))

        // Accounts tracked by month are updated by adding a monthly entry instead.
        store.addItem("Savings", 10_000, year: thisYear, category: "Cash", asset: true, month: 2)
        #expect(store.viewModel.checkInStep() == NextStep.addAccounts(year: thisYear))
    }
}

// MARK: - Quick Start

@MainActor
@Suite("Quick start")
struct QuickStartTests {

    @Test("Tiles have unique names and use the built-in categories")
    func tiles() {
        let all = StarterAccount.assets + StarterAccount.debts

        #expect(Set(all.map(\.name)).count == all.count)
        #expect(StarterAccount.assets.allSatisfy { $0.isAsset && AssetCategories(rawValue: $0.category) != nil })
        #expect(StarterAccount.debts.allSatisfy { !$0.isAsset && LiabilityCategories(rawValue: $0.category) != nil })
    }

    @Test("Starts this year with the picked accounts and amounts")
    func startTracking() throws {
        let store = try TestStore()
        let viewModel = store.viewModel
        let checking = try #require(StarterAccount.assets.first { $0.name == "Checking" })
        let retirement = try #require(StarterAccount.assets.first { $0.name == "401(k)" })
        let card = try #require(StarterAccount.debts.first { $0.name == "Credit Card" })

        viewModel.startTracking(year: thisYear, amounts: [checking: 4_000, retirement: 60_000, card: 1_500])

        #expect(viewModel.years == [thisYear])
        let items = viewModel.latestEntries(in: thisYear).sorted { $0.name < $1.name }
        #expect(items.map(\.name) == ["401(k)", "Checking", "Credit Card"])
        #expect(items.map(\.category) == ["Retirement", "Cash", "Credit Card"])
        #expect(items.map(\.itemType) == ["asset", "asset", "liability"])
        #expect(items.allSatisfy { $0.month == 0 })
        #expect(viewModel.getYearData(for: thisYear).netWorth == 62_500)
        // Next, Home suggests a goal rather than updating balances that were just entered.
        #expect(viewModel.nextStep(strategy: .avalanche) == NextStep.setFirstGoal)
    }

    @Test("Accounts without an amount are skipped")
    func skipsEmptyAmounts() throws {
        let store = try TestStore()
        let checking = try #require(StarterAccount.assets.first)
        let car = try #require(StarterAccount.assets.first { $0.name == "Car" })

        store.viewModel.startTracking(year: thisYear, amounts: [checking: 2_500, car: 0])

        #expect(store.viewModel.latestEntries(in: thisYear).map(\.name) == [checking.name])
    }
}
