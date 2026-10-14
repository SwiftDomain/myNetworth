//
//  Insights.swift
//  myNetworth
//

import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

// MARK: - Insight Input

/// One item as plain values, so insights can be calculated (and tested) without SwiftData.
struct InsightItem {
    let name: String
    let category: String
    let isAsset: Bool
    let amount: Int
    let year: Int
}

// MARK: - Insight Results

/// How one item changed between two years.
struct ItemChange: Identifiable {
    let name: String
    let category: String
    let isAsset: Bool
    let previous: Int
    let current: Int

    var id: String { "\(isAsset)|\(category)|\(name)" }

    /// The effect on net worth: positive when an asset grows or a debt shrinks.
    var netWorthEffect: Int { isAsset ? current - previous : previous - current }
}

/// How one category changed between two years.
struct CategoryChange: Identifiable {
    let name: String
    let isAsset: Bool
    let previous: Int
    let current: Int

    var id: String { "\(isAsset)|\(name)" }

    /// The effect on net worth: positive when an asset grows or a debt shrinks.
    var netWorthEffect: Int { isAsset ? current - previous : previous - current }
}

/// What changed between a year and the previous year that has data.
struct YearChange {
    let year: Int
    let previousYear: Int
    let netWorth: Int
    let previousNetWorth: Int
    let assetsChange: Int
    let liabilitiesChange: Int
    /// Items in both years that raised net worth, largest first.
    let gains: [ItemChange]
    /// Items in both years that lowered net worth, largest first.
    let drops: [ItemChange]
    /// Items only in this year, largest first.
    let added: [ItemChange]
    /// Items only in the previous year, largest first.
    let removed: [ItemChange]
    /// The category with the biggest effect on net worth.
    let topCategory: CategoryChange?

    var change: Int { netWorth - previousNetWorth }

    var percentChange: Double? {
        previousNetWorth == 0 ? nil : Double(change) / Double(abs(previousNetWorth)) * 100
    }
}

/// The change in net worth from one year with data to the next.
struct YearStep {
    let year: Int
    let previousYear: Int
    let change: Int
}

/// Progress across all years with data.
struct OverallInsights {
    let firstYear: Int
    let lastYear: Int
    let firstNetWorth: Int
    let lastNetWorth: Int
    let bestStep: YearStep
    let worstStep: YearStep
    /// Categories that moved net worth most from the first year to the last, largest first.
    let categoryDrivers: [CategoryChange]

    var totalChange: Int { lastNetWorth - firstNetWorth }

    var averageYearlyChange: Int { totalChange / max(lastYear - firstYear, 1) }
}

// MARK: - Insights Engine

enum InsightsEngine {

    /// How many items to list as the biggest gains and drops.
    static let moverCount = 3

    private struct ItemKey: Hashable {
        let name: String
        let category: String
        let isAsset: Bool
    }

    private struct CategoryKey: Hashable {
        let name: String
        let isAsset: Bool
    }

    static func yearsWithData(_ items: [InsightItem]) -> [Int] {
        Set(items.map(\.year)).sorted()
    }

    static func netWorth(of items: [InsightItem], in year: Int) -> Int {
        items
            .filter { $0.year == year }
            .reduce(0) { $0 + ($1.isAsset ? $1.amount : -$1.amount) }
    }

    /// Compares `year` with the closest earlier year that has data, or returns nil if there
    /// is no such year.
    static func yearChange(for year: Int, items: [InsightItem]) -> YearChange? {
        let years = yearsWithData(items)
        guard years.contains(year), let previousYear = years.last(where: { $0 < year }) else {
            return nil
        }

        let current = itemTotals(items, year: year)
        let previous = itemTotals(items, year: previousYear)
        let changes = Set(current.keys).union(previous.keys).map { key in
            ItemChange(
                name: key.name,
                category: key.category,
                isAsset: key.isAsset,
                previous: previous[key] ?? 0,
                current: current[key] ?? 0
            )
        }

        let inBoth = changes.filter { $0.previous > 0 && $0.current > 0 && $0.netWorthEffect != 0 }
        let gains = inBoth
            .filter { $0.netWorthEffect > 0 }
            .sorted { ($0.netWorthEffect, $1.name) > ($1.netWorthEffect, $0.name) }
        let drops = inBoth
            .filter { $0.netWorthEffect < 0 }
            .sorted { ($0.netWorthEffect, $0.name) < ($1.netWorthEffect, $1.name) }
        let added = changes
            .filter { $0.previous == 0 && $0.current > 0 }
            .sorted { ($0.current, $1.name) > ($1.current, $0.name) }
        let removed = changes
            .filter { $0.previous > 0 && $0.current == 0 }
            .sorted { ($0.previous, $1.name) > ($1.previous, $0.name) }

        let sideTotal = { (totals: [ItemKey: Int], isAsset: Bool) in
            totals.filter { $0.key.isAsset == isAsset }.values.reduce(0, +)
        }

        return YearChange(
            year: year,
            previousYear: previousYear,
            netWorth: netWorth(of: items, in: year),
            previousNetWorth: netWorth(of: items, in: previousYear),
            assetsChange: sideTotal(current, true) - sideTotal(previous, true),
            liabilitiesChange: sideTotal(current, false) - sideTotal(previous, false),
            gains: Array(gains.prefix(moverCount)),
            drops: Array(drops.prefix(moverCount)),
            added: added,
            removed: removed,
            topCategory: categoryChanges(items, from: previousYear, to: year).first
        )
    }

    /// Progress across every year with data up to `throughYear`, so future planning years
    /// are left out. Needs at least two years.
    static func overall(items: [InsightItem], throughYear: Int) -> OverallInsights? {
        let years = yearsWithData(items).filter { $0 <= throughYear }
        guard years.count >= 2, let first = years.first, let last = years.last else { return nil }

        let steps = zip(years, years.dropFirst()).map { previousYear, year in
            YearStep(
                year: year,
                previousYear: previousYear,
                change: netWorth(of: items, in: year) - netWorth(of: items, in: previousYear)
            )
        }
        guard let best = steps.max(by: { $0.change < $1.change }),
              let worst = steps.min(by: { $0.change < $1.change }) else { return nil }

        return OverallInsights(
            firstYear: first,
            lastYear: last,
            firstNetWorth: netWorth(of: items, in: first),
            lastNetWorth: netWorth(of: items, in: last),
            bestStep: best,
            worstStep: worst,
            categoryDrivers: Array(categoryChanges(items, from: first, to: last).prefix(4))
        )
    }

    // MARK: Text

    /// "+$1,200", "−$300" or "$0".
    static func signed(_ amount: Int, money: (Int) -> String) -> String {
        if amount > 0 { return "+" + money(amount) }
        if amount < 0 { return "−" + money(-amount) }
        return money(0)
    }

    /// A plain summary built from the numbers alone, used when Apple Intelligence isn't available.
    static func templateSummary(for change: YearChange, money: (Int) -> String) -> String {
        var sentences: [String] = []

        if change.change == 0 {
            sentences.append("Your net worth held steady at \(money(change.netWorth)) since \(change.previousYear).")
        } else {
            var sentence = "Your net worth \(change.change > 0 ? "rose" : "fell") \(money(abs(change.change)))"
            if let percent = change.percentChange {
                sentence += " (\(abs(percent).formatted(.number.precision(.fractionLength(1))))%)"
            }
            sentence += " since \(change.previousYear), to \(money(change.netWorth))."
            sentences.append(sentence)
        }

        if let top = change.topCategory {
            sentences.append("\(top.name) made the biggest difference (\(signed(top.netWorthEffect, money: money))).")
        }

        let paidOff = change.removed.filter { !$0.isAsset }.map(\.name)
        if !paidOff.isEmpty {
            sentences.append("You paid off \(paidOff.formatted(.list(type: .and))).")
        }

        return sentences.joined(separator: " ")
    }

    /// The facts handed to the on-device model. Every number it may use is written here.
    static func facts(for change: YearChange, money: @escaping (Int) -> String) -> String {
        func movement(_ amount: Int) -> String {
            amount == 0 ? "stayed the same" : "went \(amount > 0 ? "up" : "down") by \(money(abs(amount)))"
        }
        func describe(_ items: [ItemChange]) -> String {
            items.map { "\($0.name) (\(signed($0.netWorthEffect, money: money)))" }.joined(separator: "; ")
        }

        var lines = [
            "Comparing \(change.year) with \(change.previousYear).",
            "Net worth was \(money(change.previousNetWorth)) in \(change.previousYear) and \(money(change.netWorth)) in \(change.year), so it \(movement(change.change)).",
        ]
        if let percent = change.percentChange {
            lines.append("That is a \(abs(percent).formatted(.number.precision(.fractionLength(1))))% \(percent >= 0 ? "increase" : "decrease").")
        }
        lines.append("Total assets \(movement(change.assetsChange)). Total debts \(movement(change.liabilitiesChange)).")
        if !change.gains.isEmpty {
            lines.append("Biggest increases to net worth: \(describe(change.gains)).")
        }
        if !change.drops.isEmpty {
            lines.append("Biggest decreases to net worth: \(describe(change.drops)).")
        }
        let paidOff = change.removed.filter { !$0.isAsset }
        if !paidOff.isEmpty {
            lines.append("Debts paid off: \(paidOff.map(\.name).joined(separator: "; ")).")
        }
        let newAssets = change.added.filter(\.isAsset)
        if !newAssets.isEmpty {
            lines.append("New assets: \(newAssets.map { "\($0.name) (\(money($0.current)))" }.joined(separator: "; ")).")
        }
        let newDebts = change.added.filter { !$0.isAsset }
        if !newDebts.isEmpty {
            lines.append("New debts: \(newDebts.map { "\($0.name) (\(money($0.current)))" }.joined(separator: "; ")).")
        }
        if let top = change.topCategory {
            lines.append("Category with the biggest effect on net worth: \(top.name) (\(signed(top.netWorthEffect, money: money))).")
        }
        return lines.joined(separator: "\n")
    }

    /// Every number written in `text`, like "12,400" or "6.2".
    static func numbers(in text: String) -> [String] {
        var numbers: [String] = []
        var current = ""
        for character in text {
            if character.isASCII && character.isNumber {
                current.append(character)
            } else if (character == "," || character == ".") && !current.isEmpty {
                current.append(character)
            } else if !current.isEmpty {
                numbers.append(current)
                current = ""
            }
        }
        if !current.isEmpty {
            numbers.append(current)
        }
        return numbers.map { $0.trimmingCharacters(in: CharacterSet(charactersIn: ",.")) }
    }

    /// True when every number in `text` appears exactly in `facts`, so a generated summary
    /// can't show an amount the app didn't calculate.
    static func usesOnlyKnownNumbers(_ text: String, facts: String) -> Bool {
        let known = Set(numbers(in: facts))
        return numbers(in: text).allSatisfy { known.contains($0) }
    }

    // MARK: Helpers

    private static func itemTotals(_ items: [InsightItem], year: Int) -> [ItemKey: Int] {
        var totals: [ItemKey: Int] = [:]
        for item in items where item.year == year {
            totals[ItemKey(name: item.name, category: item.category, isAsset: item.isAsset), default: 0] += item.amount
        }
        return totals
    }

    /// Category changes between two years, largest effect on net worth first.
    private static func categoryChanges(_ items: [InsightItem], from previousYear: Int, to year: Int) -> [CategoryChange] {
        var previous: [CategoryKey: Int] = [:]
        var current: [CategoryKey: Int] = [:]
        for item in items {
            let key = CategoryKey(name: item.category, isAsset: item.isAsset)
            if item.year == previousYear { previous[key, default: 0] += item.amount }
            if item.year == year { current[key, default: 0] += item.amount }
        }
        return Set(previous.keys).union(current.keys)
            .map { key in
                CategoryChange(name: key.name, isAsset: key.isAsset, previous: previous[key] ?? 0, current: current[key] ?? 0)
            }
            .filter { $0.netWorthEffect != 0 }
            .sorted { (abs($0.netWorthEffect), $1.name) > (abs($1.netWorthEffect), $0.name) }
    }
}

// MARK: - Insight Narrator

/// Turns insight facts into a short summary with Apple Intelligence's on-device model.
/// Everything stays on the device. Returns nil whenever a summary can't be trusted, so the
/// caller falls back to `InsightsEngine.templateSummary`.
enum InsightNarrator {

    private static var cache: [String: String] = [:]

    static func summary(for facts: String) async -> String? {
        if let cached = cache[facts] {
            return cached
        }
        #if canImport(FoundationModels)
        guard case .available = SystemLanguageModel.default.availability else { return nil }

        let session = LanguageModelSession(instructions: """
            You write a short summary of how someone's net worth changed between two years, \
            for a personal finance app. Use two or three short, friendly sentences in plain \
            English, speaking to the user as "you". Mention only the facts given, and copy every \
            amount and percentage exactly as written. Don't give advice, predictions or reasons \
            for the changes.
            """)

        guard let response = try? await session.respond(to: facts, options: GenerationOptions(temperature: 0.2)) else {
            return nil
        }
        let text = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, text.count <= 600, InsightsEngine.usesOnlyKnownNumbers(text, facts: facts) else {
            return nil
        }
        cache[facts] = text
        return text
        #else
        return nil
        #endif
    }
}
