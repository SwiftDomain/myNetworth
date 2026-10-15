//
//  CSVImport.swift
//  myNetworth
//
//  Reading accounts from a CSV file, such as one exported from the app or a spreadsheet.
//

import Foundation

// MARK: - Parsing

enum CSV {

    /// Splits CSV text into rows of fields (RFC 4180): a field may be quoted, a quoted field
    /// may contain the delimiter and line breaks, and a doubled quote inside one is a quote.
    /// A blank line becomes a row with one empty field.
    static func rows(from text: String, delimiter: Character = ",") -> [[String]] {
        var rows: [[String]] = []
        var row: [String] = []
        var field = ""
        var inQuotes = false
        let characters = Array(text)
        var index = 0

        while index < characters.count {
            let character = characters[index]
            if inQuotes {
                if character == "\"" {
                    if index + 1 < characters.count, characters[index + 1] == "\"" {
                        field.append("\"")
                        index += 1
                    } else {
                        inQuotes = false
                    }
                } else {
                    field.append(character)
                }
            } else if character == "\"" && field.isEmpty {
                inQuotes = true
            } else if character == delimiter {
                row.append(field)
                field = ""
            } else if character.isNewline {
                // "\r\n" is a single Character in Swift, so Windows line endings end one row.
                row.append(field)
                rows.append(row)
                row = []
                field = ""
            } else {
                field.append(character)
            }
            index += 1
        }
        if !field.isEmpty || !row.isEmpty {
            row.append(field)
            rows.append(row)
        }
        return rows
    }

    /// The delimiter the first line uses most: a comma, a semicolon (spreadsheets in many
    /// European languages) or a tab.
    static func delimiter(of text: String) -> Character {
        let firstLine = text.prefix { !$0.isNewline }
        let candidates: [Character] = [",", ";", "\t"]
        let counts = candidates.map { candidate in firstLine.filter { $0 == candidate }.count }
        guard let best = counts.max(), best > 0, let index = counts.firstIndex(of: best) else { return "," }
        return candidates[index]
    }
}

// MARK: - Import

/// One entry read from a CSV file.
struct ImportedEntry: Equatable {
    /// Nil when the file has no Year column.
    let year: Int?
    let name: String
    /// Always positive: debts are liabilities with a positive amount.
    let amount: Int
    /// As written in the file, or empty.
    let category: String
    let isAsset: Bool
    /// 0 for the whole year, 1-12 for a month.
    let month: Int
}

/// A CSV file read for importing: the entries it has and the rows that couldn't be read.
struct CSVImport: Equatable {

    struct SkippedRow: Equatable {
        /// 1 is the header row.
        let row: Int
        let reason: String
    }

    /// Why a file can't be imported at all.
    enum Problem: Equatable {
        case empty
        case missingColumns
        case noRows

        var message: String {
            switch self {
            case .empty:
                "The file is empty."
            case .missingColumns:
                "The first row needs column names, including Name and Amount."
            case .noRows:
                "The file has column names but no rows."
            }
        }
    }

    enum Reading: Equatable {
        case read(CSVImport)
        case failed(Problem)
    }

    var entries: [ImportedEntry]
    var skipped: [SkippedRow]
    /// Without a Year column, everything goes into one year picked when importing.
    var hasYearColumn: Bool

    /// Column names each field is recognized by, in lowercase.
    private static let nameColumns = ["name", "account", "item", "description"]
    private static let amountColumns = ["amount", "balance", "value"]
    private static let yearColumns = ["year"]
    private static let categoryColumns = ["category"]
    private static let typeColumns = ["type", "kind"]
    private static let monthColumns = ["month"]

    /// Reads CSV text whose first row names the columns. Name and Amount are needed; Year,
    /// Category, Type and Month are optional, in any order, as in the app's own exports.
    static func read(_ text: String) -> Reading {
        var text = text
        if text.hasPrefix("\u{FEFF}") {
            // Excel starts UTF-8 files with a byte order mark.
            text.removeFirst()
        }
        let rows = CSV.rows(from: text, delimiter: CSV.delimiter(of: text))
        guard let headerRow = rows.first, rows.contains(where: { !isBlank($0) }) else {
            return .failed(.empty)
        }

        let header = headerRow.map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
        let columns = Columns(
            name: header.firstIndex { nameColumns.contains($0) },
            amount: header.firstIndex { amountColumns.contains($0) },
            year: header.firstIndex { yearColumns.contains($0) },
            category: header.firstIndex { categoryColumns.contains($0) },
            type: header.firstIndex { typeColumns.contains($0) },
            month: header.firstIndex { monthColumns.contains($0) }
        )
        guard columns.name != nil, columns.amount != nil else { return .failed(.missingColumns) }

        var entries: [ImportedEntry] = []
        var skipped: [SkippedRow] = []
        for (offset, row) in rows.enumerated().dropFirst() where !isBlank(row) {
            switch entry(from: row, columns: columns) {
            case .entry(let entry):
                entries.append(entry)
            case .skipped(let reason):
                skipped.append(SkippedRow(row: offset + 1, reason: reason))
            }
        }
        guard !entries.isEmpty || !skipped.isEmpty else { return .failed(.noRows) }

        return .read(CSVImport(entries: entries, skipped: skipped, hasYearColumn: columns.year != nil))
    }

    // MARK: Fields

    private struct Columns {
        let name: Int?
        let amount: Int?
        let year: Int?
        let category: Int?
        let type: Int?
        let month: Int?
    }

    private enum RowReading {
        case entry(ImportedEntry)
        case skipped(reason: String)
    }

    private static func isBlank(_ row: [String]) -> Bool {
        row.allSatisfy { $0.trimmingCharacters(in: .whitespaces).isEmpty }
    }

    private static func entry(from row: [String], columns: Columns) -> RowReading {
        func field(_ column: Int?) -> String {
            guard let column, column < row.count else { return "" }
            return row[column].trimmingCharacters(in: .whitespaces)
        }

        let name = field(columns.name)
        guard !name.isEmpty else { return .skipped(reason: "No name") }

        let amountText = field(columns.amount)
        guard let amount = parseAmount(amountText) else {
            return .skipped(reason: amountText.isEmpty ? "No amount" : "\"\(amountText)\" isn't an amount")
        }

        var year: Int?
        if columns.year != nil {
            let yearText = field(columns.year)
            guard let value = Int(yearText), (1900...2200).contains(value) else {
                return .skipped(reason: yearText.isEmpty ? "No year" : "\"\(yearText)\" isn't a year")
            }
            year = value
        }

        let monthText = field(columns.month)
        guard let month = parseMonth(monthText) else {
            return .skipped(reason: "\"\(monthText)\" isn't a month")
        }

        let category = field(columns.category)
        let isAsset: Bool
        switch field(columns.type).lowercased() {
        case "asset", "assets":
            isAsset = true
        case "liability", "liabilities", "debt", "debts", "loan":
            isAsset = false
        default:
            // No type given: a negative amount or a debt category means a liability.
            let isDebtCategory = LiabilityCategories.allCases.contains {
                $0 != .other && $0.rawValue.caseInsensitiveCompare(category) == .orderedSame
            }
            isAsset = !(amount.isNegative || isDebtCategory)
        }

        return .entry(ImportedEntry(
            year: year,
            name: name,
            amount: amount.value,
            category: category,
            isAsset: isAsset,
            month: month
        ))
    }

    /// Reads amounts such as "1200", "$1,200.50", "-500" or "(500)", rounded to whole units.
    static func parseAmount(_ text: String) -> (value: Int, isNegative: Bool)? {
        let isNegative = text.contains("-") || (text.hasPrefix("(") && text.hasSuffix(")"))
        let number = text.filter { ($0.isASCII && $0.isNumber) || $0 == "." }
        guard !number.isEmpty, let value = Double(number) else { return nil }
        return (Int(value.rounded()), isNegative)
    }

    /// Reads a month as 1-12, or a month's name in the user's language. Blank or 0 means
    /// the whole year.
    static func parseMonth(_ text: String) -> Int? {
        if text.isEmpty { return 0 }
        if let month = Int(text) {
            return (0...12).contains(month) ? month : nil
        }
        let calendar = Calendar.current
        let names = (calendar.monthSymbols + calendar.shortMonthSymbols).map { $0.lowercased() }
        guard let index = names.firstIndex(of: text.lowercased()) else { return nil }
        return index % 12 + 1
    }
}

/// What importing entries does, worked out before anything is saved.
struct ImportSummary: Equatable {

    struct NewCategory: Hashable {
        let name: String
        let isAsset: Bool
    }

    /// Entries added as new items.
    var added: Int
    /// Entries for an item that's already there, whose amount is updated instead.
    var updated: Int
    var newYears: [Int]
    var newCategories: [NewCategory]
}
