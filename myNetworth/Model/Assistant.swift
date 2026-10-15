//
//  Assistant.swift
//  myNetworth
//

import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

// MARK: - Suggested Questions

/// Questions the app answers itself from the numbers, with or without Apple Intelligence.
enum SuggestedQuestion: String, CaseIterable, Identifiable {
    case netWorth
    case whatChanged
    case biggestDebt
    case debtFree
    case goals
    case whereMoney

    var id: Self { self }

    var title: String {
        switch self {
        case .netWorth: "What's my net worth?"
        case .whatChanged: "What changed?"
        case .biggestDebt: "What's my biggest debt?"
        case .debtFree: "When will I be debt-free?"
        case .goals: "Am I on track for my goals?"
        case .whereMoney: "Where is most of my money?"
        }
    }
}

// MARK: - Answers From the Numbers

extension NetWorthViewModel {

    /// Formats a whole amount in the user's currency, e.g. "$12,400".
    func money(_ amount: Int) -> String {
        amount.formatted(.currency(code: currencyCode).precision(.fractionLength(0)))
    }

    /// Answers a suggested question from the numbers. `strategy` and `extraPayment` are the
    /// debt planner's, so the debt-free date matches it.
    func answer(to question: SuggestedQuestion, strategy: PayoffStrategy, extraPayment: Int, now: Date = .now) -> String {
        switch question {
        case .netWorth: netWorthAnswer()
        case .whatChanged: whatChangedAnswer()
        case .biggestDebt: biggestDebtAnswer()
        case .debtFree: debtFreeAnswer(strategy: strategy, extraPayment: extraPayment, now: now)
        case .goals: goalsAnswer(now: now)
        case .whereMoney: whereMoneyAnswer()
        }
    }

    private func netWorthAnswer() -> String {
        guard let summary = netWorthSummary else {
            return "You haven't added any numbers yet. Set up your accounts to see your net worth."
        }
        var text = "Your net worth is \(money(summary.netWorth)) in \(summary.year)."
        if let change = summary.change {
            text += " That's \(change.change >= 0 ? "up" : "down") \(money(abs(change.change)))"
            if let percent = change.percentChange {
                text += " (\(abs(percent).formatted(.number.precision(.fractionLength(1))))%)"
            }
            text += " since \(change.previousYear)."
        }
        return text
    }

    private func whatChangedAnswer() -> String {
        guard let summary = netWorthSummary,
              let change = InsightsEngine.yearChange(for: summary.year, items: insightItems) else {
            return "There's nothing to compare yet. Add a second year to see what changed."
        }
        return InsightsEngine.templateSummary(for: change) { money($0) }
    }

    private func biggestDebtAnswer() -> String {
        let debts = currentDebts
        guard let biggest = debts.first, let year = currentDebtYear else {
            return "You don't have any debts recorded right now."
        }
        var text = "Your biggest debt is \(biggest.name) at \(money(biggest.amount)) in \(year)."
        if debts.count == 1 {
            text += " It's your only debt."
        } else {
            let total = debts.reduce(0) { $0 + $1.amount }
            text += " You have \(debts.count) debts totaling \(money(total))."
        }
        return text
    }

    private func debtFreeAnswer(strategy: PayoffStrategy, extraPayment: Int, now: Date) -> String {
        let debts = plannerDebts
        guard !debts.isEmpty else {
            return currentDebts.isEmpty
                ? "You don't have any debts to pay off."
                : "Your debts are all left out of the payoff plan. Include them in the Debt Payoff Planner to see a date."
        }
        let plan = DebtPlanner.plan(for: debts, strategy: strategy, extraPayment: extraPayment)
        guard plan.isPayable else {
            return "At your current payments your debts wouldn't be paid off within 50 years. Add minimum payments or an extra amount in the Debt Payoff Planner."
        }
        let date = Calendar.current.date(byAdding: .month, value: plan.months, to: now) ?? now
        let method = "the \(strategy.title.lowercased()) method"
        let extra = extraPayment > 0 ? " and \(money(extraPayment)) extra a month" : ""
        return "Using \(method)\(extra), you'd be debt-free around \(date.formatted(.dateTime.month(.abbreviated).year())), "
            + "in \(plan.months) months, paying about \(money(Int(plan.totalInterest.rounded()))) in interest."
    }

    private func goalsAnswer(now: Date) -> String {
        guard !goals.isEmpty else {
            return "You haven't set any goals yet. Add one in Plan › Goals."
        }
        return goals.map { goal in
            "\(goal.title): \(paceDescription(for: goal, now: now))."
        }
        .joined(separator: "\n")
    }

    private func paceDescription(for goal: Goal, now: Date) -> String {
        let monthYear = Date.FormatStyle.dateTime.month(.abbreviated).year()
        let verb = goal.goalType == "liability" ? "pay down" : "save"
        switch goalPace(for: goal, now: now) {
        case .reached:
            return "reached"
        case .onTrack(let projected):
            return "on track, reaching it around \(projected.formatted(monthYear))"
        case .behind(let perMonth):
            return "behind; \(verb) \(money(perMonth)) a month to make \(goal.targetDate.formatted(monthYear))"
        case .needs(let perMonth):
            return "\(verb) \(money(perMonth)) a month to reach it by \(goal.targetDate.formatted(monthYear))"
        case .overdue(let remaining):
            return "past its date with \(money(remaining)) to go"
        case .noDate(let projected?):
            return "no target date; at your pace you'd reach it around \(projected.formatted(monthYear))"
        case .noDate(nil):
            return "no target date"
        case nil:
            return "add your numbers to see its progress"
        }
    }

    private func whereMoneyAnswer() -> String {
        guard let year = latestYearWithData else {
            return "You haven't added any assets yet."
        }
        let categories = getCategoryData(for: .asset, year: year)
        let total = categories.reduce(0) { $0 + $1.1 }
        guard let top = categories.first, total > 0 else {
            return "You don't have any assets recorded in \(year)."
        }
        let share = Int((Double(top.1) / Double(total) * 100).rounded())
        var text = "Most of your assets are in \(top.0): \(money(top.1)), \(share)% of \(money(total)) in \(year)."
        if categories.count > 1 {
            let next = categories[1]
            text += " Next is \(next.0) at \(money(next.1))."
        }
        return text
    }

    // MARK: Facts for the On-Device Model

    /// Everything the on-device model may use to answer a question, written out by the app.
    /// Every number it can use appears here, so answers can be checked against it.
    func assistantFacts(strategy: PayoffStrategy, extraPayment: Int, now: Date = .now) -> String {
        let thisYear = Calendar.current.component(.year, from: now)
        let years = Array(InsightsEngine.yearsWithData(insightItems).filter { $0 <= thisYear }.suffix(6))
        var lines = ["Today is \(now.formatted(.dateTime.month(.wide).year())). Amounts are in \(currencyCode)."]

        guard !years.isEmpty else {
            lines.append("No numbers have been added yet.")
            return lines.joined(separator: "\n")
        }

        lines.append("Net worth by year: " + years.map { "\($0): \(money(getYearData(for: $0).netWorth))" }.joined(separator: "; ") + ".")
        if let latest = years.last {
            let data = getYearData(for: latest)
            lines.append("In \(latest): assets \(money(data.assets)), debts \(money(data.liabilities)), net worth \(money(data.netWorth)).")
        }

        for question in SuggestedQuestion.allCases {
            lines.append(answer(to: question, strategy: strategy, extraPayment: extraPayment, now: now))
        }

        lines.append(contentsOf: accountHistory(years: years))

        for debt in currentDebts {
            if let saved = terms(for: debt), saved.annualRate > 0 || saved.minimumPayment > 0 {
                let rate = saved.annualRate.formatted(.number.precision(.fractionLength(0...2)))
                lines.append("\(debt.name) has a \(rate)% interest rate and a \(money(saved.minimumPayment)) minimum payment.")
            }
        }

        if let latest = years.last {
            for type in [ItemType.asset, .liability] {
                let categories = getCategoryData(for: type, year: latest)
                guard !categories.isEmpty else { continue }
                let label = type == .asset ? "Assets" : "Debts"
                lines.append("\(label) by category in \(latest): " + categories.map { "\($0.0) \(money($0.1))" }.joined(separator: "; ") + ".")
            }
        }

        if let projection = netWorthProjection {
            let horizons = NetWorthProjection.horizons.map { horizon in
                "\(money(projection.netWorth(inYears: horizon))) in \(horizon) years (\(projection.baseYear + horizon))"
            }
            let change = InsightsEngine.signed(projection.averageYearlyChange) { money($0) }
            lines.append("At the average yearly change since \(projection.firstYear) (\(change) a year), net worth would be " + horizons.joined(separator: ", ") + ".")
        }

        return lines.joined(separator: "\n")
    }

    /// One line per account with its amount in each year, largest accounts first.
    private func accountHistory(years: [Int]) -> [String] {
        struct Account: Hashable {
            let name: String
            let category: String
            let isAsset: Bool
        }
        var amounts: [Account: [Int: Int]] = [:]
        for year in years {
            for item in latestEntries(in: year) {
                let account = Account(name: item.name, category: item.category, isAsset: item.itemType == "asset")
                amounts[account, default: [:]][year, default: 0] += item.amount
            }
        }
        let latestYear = years.last ?? 0
        return amounts
            .sorted { ($0.value[latestYear] ?? 0, $1.key.name) > ($1.value[latestYear] ?? 0, $0.key.name) }
            .prefix(30)
            .map { account, byYear in
                let history = years.compactMap { year in byYear[year].map { "\(year) \(money($0))" } }
                return "\(account.name) (\(account.category), \(account.isAsset ? "asset" : "debt")): " + history.joined(separator: "; ") + "."
            }
    }
}

// MARK: - On-Device Assistant

/// Answers free-form questions with Apple Intelligence's on-device model, from the facts the
/// app writes out. Nothing leaves the device.
enum MoneyAssistant {

    enum Reply: Equatable {
        case answer(String)
        /// The answer used a number that isn't in the facts or the question, so it isn't shown.
        case unreliable
        /// Apple Intelligence isn't available, or answering failed.
        case failed
    }

    static var isAvailable: Bool {
        #if canImport(FoundationModels)
        if case .available = SystemLanguageModel.default.availability {
            return true
        }
        #endif
        return false
    }

    static func answer(_ question: String, facts: String) async -> Reply {
        #if canImport(FoundationModels)
        guard case .available = SystemLanguageModel.default.availability else { return .failed }

        let session = LanguageModelSession(instructions: """
            You answer questions about the user's own finances in a personal finance app, using \
            only the facts provided with each question. Reply in at most four short, plain \
            sentences, speaking to the user as "you". Copy every amount, percentage, year and \
            date exactly as written in the facts, and don't calculate new numbers. If the facts \
            don't answer the question, say you can't tell from their numbers. Don't give \
            investment, tax or legal advice.
            """)
        let prompt = "Facts:\n\(facts)\n\nQuestion: \(question)"

        guard let response = try? await session.respond(to: prompt, options: GenerationOptions(temperature: 0.2)) else {
            return .failed
        }
        let text = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, text.count <= 800 else { return .failed }
        // Numbers the user typed may be repeated; anything else must come from the facts.
        guard InsightsEngine.usesOnlyKnownNumbers(text, facts: facts + "\n" + question) else {
            return .unreliable
        }
        return .answer(text)
        #else
        return .failed
        #endif
    }
}
