//
//  DebtPlannerTests.swift
//  myNetworthTests
//
//  Feature 4: the debt payoff planner and debt terms.
//

import Foundation
import SwiftData
import Testing
@testable import myNetworth

// MARK: - Planner

@MainActor
@Suite("Debt payoff planner")
struct DebtPlannerTests {

    private func debt(_ name: String, _ balance: Int, rate: Double, minimum: Int) -> PlannerDebt {
        PlannerDebt(id: UUID(), name: name, balance: balance, annualRate: rate, minimumPayment: minimum)
    }

    private var mixedDebts: [PlannerDebt] {
        [
            debt("Car loan", 9_000, rate: 6, minimum: 250),
            debt("Visa", 3_000, rate: 24.9, minimum: 90),
            debt("Store card", 800, rate: 29.9, minimum: 35),
        ]
    }

    @Test("A single debt matches the standard loan formula")
    func matchesAmortization() {
        // $1,000 at 12% a year, paying $100 a month.
        let plan = DebtPlanner.plan(
            for: [debt("Card", 1_000, rate: 12, minimum: 100)],
            strategy: .snowball,
            extraPayment: 0
        )
        let exactMonths = -log(1 - 0.01 * 1_000 / 100) / log(1.01)

        #expect(plan.isPayable)
        #expect(plan.months == Int(exactMonths.rounded(.up)))
        #expect(abs(plan.totalInterest - (exactMonths * 100 - 1_000)) < 1)
    }

    @Test("Snowball targets the smallest balance, avalanche the highest rate")
    func payoffOrder() {
        let debts = [
            debt("Big high-rate", 9_000, rate: 29.9, minimum: 250),
            debt("Small low-rate", 800, rate: 5, minimum: 35),
        ]
        let snowball = DebtPlanner.payoffOrder(of: debts, strategy: .snowball).map { debts[$0].name }
        let avalanche = DebtPlanner.payoffOrder(of: debts, strategy: .avalanche).map { debts[$0].name }

        #expect(snowball == ["Small low-rate", "Big high-rate"])
        #expect(avalanche == ["Big high-rate", "Small low-rate"])
    }

    @Test("Avalanche pays less interest when the big debt has the high rate")
    func avalancheSavesInterest() {
        let debts = [
            debt("Big high-rate", 9_000, rate: 29.9, minimum: 250),
            debt("Small low-rate", 800, rate: 5, minimum: 35),
        ]
        let snowball = DebtPlanner.plan(for: debts, strategy: .snowball, extraPayment: 200)
        let avalanche = DebtPlanner.plan(for: debts, strategy: .avalanche, extraPayment: 200)

        #expect(avalanche.totalInterest < snowball.totalInterest)
        #expect(avalanche.months <= snowball.months)
        // Snowball's quick win: the small debt is gone within a few months.
        #expect(snowball.milestones.first?.name == "Small low-rate")
        #expect((snowball.milestones.first?.month ?? .max) < (avalanche.milestones.first?.month ?? 0))
    }

    @Test("A paid-off debt's payment rolls on to the next one")
    func paymentsRollOver() throws {
        let plan = DebtPlanner.plan(for: mixedDebts, strategy: .snowball, extraPayment: 100)

        #expect(plan.isPayable)
        #expect(plan.milestones.map(\.name) == ["Store card", "Visa", "Car loan"])
        let first = try #require(plan.milestones.first)
        #expect(first.nextDebtName == "Visa")
        // Visa gets its own minimum, the store card's minimum and the extra.
        #expect(first.nextDebtPayment == 90 + 35 + 100)
        let second = try #require(plan.milestones.dropFirst().first)
        #expect(second.nextDebtName == "Car loan")
        #expect(second.nextDebtPayment == 250 + 90 + 35 + 100)
        #expect(plan.milestones.last?.nextDebtName == nil)
        #expect(plan.milestones.map(\.month) == plan.milestones.map(\.month).sorted())
        #expect(plan.milestones.last?.month == plan.months)
    }

    @Test("Extra payments shorten the plan and cut the interest")
    func extraPaymentHelps() {
        let base = DebtPlanner.plan(for: mixedDebts, strategy: .avalanche, extraPayment: 0)
        let more = DebtPlanner.plan(for: mixedDebts, strategy: .avalanche, extraPayment: 300)

        #expect(more.months < base.months)
        #expect(more.totalInterest < base.totalInterest)
    }

    @Test("A negative extra payment counts as none")
    func negativeExtraIgnored() {
        let none = DebtPlanner.plan(for: mixedDebts, strategy: .avalanche, extraPayment: 0)
        let negative = DebtPlanner.plan(for: mixedDebts, strategy: .avalanche, extraPayment: -500)

        #expect(negative.months == none.months)
        #expect(negative.totalInterest == none.totalInterest)
    }

    @Test("Payments that don't cover the interest never finish")
    func unpayable() {
        // $10,000 at 24% is $200 of interest a month, more than the $150 payment.
        let tooSmall = DebtPlanner.plan(
            for: [debt("Card", 10_000, rate: 24, minimum: 150)],
            strategy: .avalanche,
            extraPayment: 0
        )
        #expect(!tooSmall.isPayable)
        #expect(tooSmall.months == DebtPlanner.maxMonths)

        let noPayment = DebtPlanner.plan(
            for: [debt("Card", 1_000, rate: 0, minimum: 0)],
            strategy: .snowball,
            extraPayment: 0
        )
        #expect(!noPayment.isPayable)
    }

    @Test("Interest-free debts finish exactly, and no debts means nothing to plan")
    func interestFreeAndEmpty() {
        let familyLoan = DebtPlanner.plan(
            for: [debt("Family loan", 1_200, rate: 0, minimum: 100)],
            strategy: .snowball,
            extraPayment: 0
        )
        #expect(familyLoan.months == 12)
        #expect(familyLoan.totalInterest == 0)

        let empty = DebtPlanner.plan(for: [], strategy: .snowball, extraPayment: 0)
        #expect(empty.isPayable)
        #expect(empty.months == 0)
        #expect(empty.milestones.isEmpty)
    }
}

// MARK: - Debt Terms

@MainActor
@Suite("Debt terms")
struct DebtTermsTests {

    @Test("Mortgages are left out of the plan by default")
    func mortgageLeftOut() throws {
        let store = try TestStore()
        let viewModel = store.viewModel
        viewModel.addYear(thisYear)
        let mortgage = store.addItem("Home", 300_000, year: thisYear, category: "Mortgage", asset: false)
        let visa = store.addItem("Visa", 3_000, year: thisYear, category: "Credit Card", asset: false)

        #expect(!viewModel.isIncludedInPlan(mortgage))
        #expect(viewModel.isIncludedInPlan(visa))
        #expect(viewModel.plannerDebts.map(\.name) == ["Visa"])

        viewModel.setIncludedInPlan(true, for: mortgage)
        #expect(viewModel.plannerDebts.map(\.name) == ["Home", "Visa"])
    }

    @Test("Saved terms are used and carry over to the same debt in a later year")
    func termsCarryAcrossYears() throws {
        let store = try TestStore()
        let viewModel = store.viewModel
        viewModel.addYear(thisYear - 1)
        let lastYearVisa = store.addItem("Visa", 4_000, year: thisYear - 1, category: "Credit Card", asset: false)
        viewModel.updateTerms(for: lastYearVisa, annualRate: 24.9, minimumPayment: 90, isIncluded: true)

        viewModel.addYear(thisYear)
        let visa = store.addItem("Visa", 3_000, year: thisYear, category: "Credit Card", asset: false)

        let saved = try #require(viewModel.terms(for: visa))
        #expect(saved.annualRate == 24.9)
        #expect(saved.minimumPayment == 90)

        let planned = try #require(viewModel.plannerDebts.first)
        #expect(planned.id == visa.id)
        #expect(planned.balance == 3_000)
        #expect(planned.annualRate == 24.9)
        #expect(planned.minimumPayment == 90)

        // Terms match on name and category, so a different kind of debt doesn't pick them up.
        let otherVisa = store.addItem("Visa", 500, year: thisYear, category: "Other", asset: false)
        #expect(viewModel.terms(for: otherVisa)?.annualRate == nil)
    }

    @Test("Changing terms edits the saved record instead of adding another")
    func updateTermsInPlace() throws {
        let store = try TestStore()
        let viewModel = store.viewModel
        viewModel.addYear(thisYear)
        let visa = store.addItem("Visa", 3_000, year: thisYear, category: "Credit Card", asset: false)

        viewModel.updateTerms(for: visa, annualRate: 19.9, minimumPayment: 75, isIncluded: true)
        viewModel.updateTerms(for: visa, annualRate: 24.9, minimumPayment: 90, isIncluded: true)
        #expect(viewModel.debtTerms.count == 1)
        #expect(viewModel.terms(for: visa)?.annualRate == 24.9)

        // Leaving a debt out of the plan keeps its rate and payment.
        viewModel.setIncludedInPlan(false, for: visa)
        #expect(viewModel.debtTerms.count == 1)
        #expect(viewModel.terms(for: visa)?.annualRate == 24.9)
        #expect(viewModel.terms(for: visa)?.minimumPayment == 90)
        #expect(!viewModel.isIncludedInPlan(visa))
        #expect(viewModel.plannerDebts.isEmpty)
    }

    @Test("The plan uses this year's debts, skipping paid-off ones and future years")
    func currentDebts() throws {
        let store = try TestStore()
        let viewModel = store.viewModel
        viewModel.addYear(thisYear)
        viewModel.addYear(thisYear + 1)
        store.addItem("Visa", 3_000, year: thisYear, category: "Credit Card", asset: false)
        store.addItem("Car", 9_000, year: thisYear, category: "Auto Loan", asset: false)
        store.addItem("Old card", 0, year: thisYear, category: "Credit Card", asset: false)
        store.addItem("Future loan", 50_000, year: thisYear + 1, category: "Other", asset: false)

        #expect(viewModel.currentDebtYear == thisYear)
        #expect(viewModel.currentDebts.map(\.name) == ["Car", "Visa"])
        // Debts without saved terms count as interest-free with no minimum payment.
        #expect(viewModel.plannerDebts.allSatisfy { $0.annualRate == 0 && $0.minimumPayment == 0 })
    }
}
