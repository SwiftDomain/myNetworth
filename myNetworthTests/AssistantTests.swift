//
//  AssistantTests.swift
//  myNetworthTests
//
//  Feature 5: "Ask a question" — the app's own answers and the facts the on-device model uses.
//

import Foundation
import SwiftData
import Testing
@testable import myNetworth

@MainActor
@Suite("Ask a question")
struct AssistantTests {

    /// Last year: $8,000 of savings. This year: $12,000 of savings and a $2,000 Visa.
    private func twoYears() throws -> TestStore {
        let store = try TestStore()
        store.viewModel.addYear(thisYear - 1)
        store.viewModel.addYear(thisYear)
        store.addItem("Savings", 8_000, year: thisYear - 1, category: "Cash", asset: true)
        store.addItem("Savings", 12_000, year: thisYear, category: "Cash", asset: true)
        store.addItem("Visa", 2_000, year: thisYear, category: "Credit Card", asset: false)
        return store
    }

    private func answer(_ question: SuggestedQuestion, _ viewModel: NetWorthViewModel, extra: Int = 0) -> String {
        viewModel.answer(to: question, strategy: .snowball, extraPayment: extra)
    }

    // MARK: Suggested questions

    @Test("Net worth, with the change since the previous year")
    func netWorth() throws {
        let store = try twoYears()
        let viewModel = store.viewModel
        let text = answer(.netWorth, viewModel)

        #expect(text.hasPrefix("Your net worth is \(viewModel.money(10_000)) in \(thisYear)."))
        #expect(text.contains("up \(viewModel.money(2_000))"))
        #expect(text.hasSuffix("since \(thisYear - 1)."))
    }

    @Test("Every question has an answer before anything is added")
    func noData() throws {
        let store = try TestStore()

        for question in SuggestedQuestion.allCases {
            #expect(!answer(question, store.viewModel).isEmpty)
        }
        #expect(answer(.netWorth, store.viewModel).contains("haven't added"))
        #expect(answer(.whatChanged, store.viewModel).contains("nothing to compare"))
    }

    @Test("What changed uses the same summary as the What Changed card")
    func whatChanged() throws {
        let store = try twoYears()
        let viewModel = store.viewModel
        let change = try #require(InsightsEngine.yearChange(for: thisYear, items: viewModel.insightItems))

        #expect(answer(.whatChanged, viewModel) == InsightsEngine.templateSummary(for: change) { viewModel.money($0) })
    }

    @Test("The biggest debt, with the count and total")
    func biggestDebt() throws {
        let store = try TestStore()
        let viewModel = store.viewModel
        viewModel.addYear(thisYear)
        store.addItem("Car loan", 9_000, year: thisYear, category: "Auto Loan", asset: false)
        store.addItem("Visa", 3_000, year: thisYear, category: "Credit Card", asset: false)

        let text = answer(.biggestDebt, viewModel)

        #expect(text.hasPrefix("Your biggest debt is Car loan at \(viewModel.money(9_000))"))
        #expect(text.hasSuffix("You have 2 debts totaling \(viewModel.money(12_000))."))
    }

    @Test("The debt-free date follows the payoff plan, including the extra payment")
    func debtFree() throws {
        let store = try TestStore()
        let viewModel = store.viewModel
        viewModel.addYear(thisYear)
        #expect(answer(.debtFree, viewModel) == "You don't have any debts to pay off.")

        let visa = store.addItem("Visa", 3_000, year: thisYear, category: "Credit Card", asset: false)
        // Without a minimum payment the plan never finishes.
        #expect(answer(.debtFree, viewModel).contains("wouldn't be paid off"))

        viewModel.updateTerms(for: visa, annualRate: 0, minimumPayment: 100, isIncluded: true)
        let text = answer(.debtFree, viewModel)
        #expect(text.hasPrefix("Using the snowball method, you'd be debt-free around"))
        #expect(text.contains("in 30 months"))

        let withExtra = answer(.debtFree, viewModel, extra: 200)
        #expect(withExtra.contains("and \(viewModel.money(200)) extra a month"))
        #expect(withExtra.contains("in 10 months"))
    }

    @Test("Goals, each with its pace")
    func goals() throws {
        let store = try twoYears()
        let viewModel = store.viewModel
        #expect(answer(.goals, viewModel).contains("haven't set any goals"))

        viewModel.addGoal(Goal(title: "Starter fund", targetAmount: 5_000, targetDate: .now, goalType: "asset"))

        #expect(answer(.goals, viewModel) == "Starter fund: reached.")
    }

    @Test("Where most of the money is, with its share")
    func whereMoney() throws {
        let store = try TestStore()
        let viewModel = store.viewModel
        viewModel.addYear(thisYear)
        store.addItem("401(k)", 30_000, year: thisYear, category: "Retirement", asset: true)
        store.addItem("Checking", 10_000, year: thisYear, category: "Cash", asset: true)

        let text = answer(.whereMoney, viewModel)

        #expect(text.hasPrefix("Most of your assets are in Retirement: \(viewModel.money(30_000)), 75% of \(viewModel.money(40_000))"))
        #expect(text.hasSuffix("Next is Cash at \(viewModel.money(10_000))."))
    }

    // MARK: Facts for the on-device model

    @Test("The facts include every suggested answer, account history and debt terms")
    func facts() throws {
        let store = try twoYears()
        let viewModel = store.viewModel
        let visa = try #require(viewModel.currentDebts.first)
        viewModel.updateTerms(for: visa, annualRate: 24.9, minimumPayment: 90, isIncluded: true)

        let facts = viewModel.assistantFacts(strategy: .snowball, extraPayment: 0)

        for question in SuggestedQuestion.allCases {
            let text = answer(question, viewModel)
            #expect(facts.contains(text))
            #expect(InsightsEngine.usesOnlyKnownNumbers(text, facts: facts))
        }
        #expect(facts.contains("Savings (Cash, asset): \(thisYear - 1) \(viewModel.money(8_000)); \(thisYear) \(viewModel.money(12_000))."))
        #expect(facts.contains("Visa has a 24.9% interest rate and a \(viewModel.money(90)) minimum payment."))
        #expect(facts.contains("Net worth by year: \(thisYear - 1): \(viewModel.money(8_000)); \(thisYear): \(viewModel.money(10_000))."))
    }

    @Test("The facts say so when there's nothing yet")
    func emptyFacts() throws {
        let store = try TestStore()
        #expect(store.viewModel.assistantFacts(strategy: .snowball, extraPayment: 0).contains("No numbers have been added yet."))
    }

    @Test("Typed questions need Apple Intelligence", .timeLimit(.minutes(1)))
    func typedQuestionWithoutModel() async {
        guard !MoneyAssistant.isAvailable else { return }
        #expect(await MoneyAssistant.answer("What's my net worth?", facts: "Net worth: $10,000.") == MoneyAssistant.Reply.failed)
    }
}
