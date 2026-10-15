//
//  CSVTests.swift
//  myNetworthTests
//
//  Exporting every year to one CSV file and importing CSV files.
//

import Foundation
import SwiftData
import Testing
@testable import myNetworth

@MainActor
@Suite("CSV import and export")
struct CSVTests {

    private func readFile(_ text: String) -> CSVImport? {
        if case .read(let file) = CSVImport.read(text) {
            return file
        }
        return nil
    }

    // MARK: Parsing

    @Test("Quoted fields keep their commas, quotes and line breaks")
    func rows() {
        let text = "Name,Amount\r\n\"Smith, John\",\"1,200\"\n\"The \"\"big\"\" one\",5\n\"Line one\nLine two\",7\n"

        let rows = CSV.rows(from: text)

        #expect(rows == [
            ["Name", "Amount"],
            ["Smith, John", "1,200"],
            ["The \"big\" one", "5"],
            ["Line one\nLine two", "7"],
        ])
    }

    @Test("Amounts and months are read leniently")
    func amountsAndMonths() {
        #expect(CSVImport.parseAmount("$1,200")?.value == 1_200)
        #expect(CSVImport.parseAmount("-500")?.isNegative == true)
        #expect(CSVImport.parseAmount("(75.6)")?.value == 76)
        #expect(CSVImport.parseAmount("(75.6)")?.isNegative == true)
        #expect(CSVImport.parseAmount("n/a")?.value == nil)

        #expect(CSVImport.parseMonth("") == 0)
        #expect(CSVImport.parseMonth("7") == 7)
        #expect(CSVImport.parseMonth("13") == nil)
        let december = Calendar.current.shortMonthSymbols[11]
        #expect(CSVImport.parseMonth(december) == 12)
    }

    @Test("A file needs Name and Amount columns and at least one row")
    func unreadable() {
        #expect(CSVImport.read("") == CSVImport.Reading.failed(.empty))
        #expect(CSVImport.read("\n\n") == CSVImport.Reading.failed(.empty))
        #expect(CSVImport.read("Account,Notes\nSavings,hi\n") == CSVImport.Reading.failed(.missingColumns))
        #expect(CSVImport.read("Name,Amount\n") == CSVImport.Reading.failed(.noRows))
    }

    @Test("Rows that can't be read are skipped, with the reason")
    func skippedRows() throws {
        let march = Calendar.current.monthSymbols[2]
        let text = """
            Name,Amount,Year,Month
            Savings,100,2024,0
            ,50,2024,0
            Car,abc,2024,0
            House,5,20x4,0
            Boat,7,2024,13
            Bike,9,2024,\(march)

            """

        let file = try #require(readFile(text))

        #expect(file.entries.map(\.name) == ["Savings", "Bike"])
        #expect(file.entries.last?.month == 3)
        #expect(file.skipped == [
            CSVImport.SkippedRow(row: 3, reason: "No name"),
            CSVImport.SkippedRow(row: 4, reason: "\"abc\" isn't an amount"),
            CSVImport.SkippedRow(row: 5, reason: "\"20x4\" isn't a year"),
            CSVImport.SkippedRow(row: 6, reason: "\"13\" isn't a month"),
        ])
    }

    @Test("Columns are found by name in any order, and the type can be worked out")
    func spreadsheetFile() throws {
        // A spreadsheet saved in a language that uses semicolons, with Excel's byte order mark.
        let text = "\u{FEFF}Balance;Account;Category\n$1,200.40;Brokerage;Investments\n(300);Store card;\n250;Visa;credit card\n"

        let file = try #require(readFile(text))

        #expect(!file.hasYearColumn)
        #expect(file.entries == [
            ImportedEntry(year: nil, name: "Brokerage", amount: 1_200, category: "Investments", isAsset: true, month: 0),
            // A negative amount is a debt.
            ImportedEntry(year: nil, name: "Store card", amount: 300, category: "", isAsset: false, month: 0),
            // So is a debt category.
            ImportedEntry(year: nil, name: "Visa", amount: 250, category: "credit card", isAsset: false, month: 0),
        ])

        // Without a Year column, everything goes into the year picked.
        let store = try TestStore()
        let summary = store.viewModel.importEntries(file.entries, year: thisYear - 2)

        #expect(summary.newYears == [thisYear - 2])
        let data = store.viewModel.getYearData(for: thisYear - 2)
        #expect(data.assets == 1_200)
        #expect(data.liabilities == 550)
        let debtCategories = store.viewModel.liabilities.map(\.category).sorted()
        #expect(debtCategories == ["Credit Card", "Other"])
    }

    // MARK: Importing

    @Test("The all-years export reads back into the same entries")
    func roundTrip() throws {
        let store = try TestStore()
        store.viewModel.addYear(thisYear - 1)
        store.viewModel.addYear(thisYear)
        store.addItem("Savings", 8_000, year: thisYear - 1, category: "Cash", asset: true)
        store.addItem("Smith, John loan", 5_000, year: thisYear, category: "Other", asset: false)
        store.addItem("Checking", 1_200, year: thisYear, category: "Cash", asset: true, month: 3)

        let csv = store.viewModel.generateAllYearsCSV()

        let lines = csv.split(separator: "\n").map(String.init)
        #expect(lines == [
            "Year,Name,Amount,Category,Type,Month",
            "\(thisYear - 1),Savings,8000,Cash,asset,0",
            "\(thisYear),Checking,1200,Cash,asset,3",
            "\(thisYear),\"Smith, John loan\",5000,Other,liability,0",
        ])

        let file = try #require(readFile(csv))
        #expect(file.hasYearColumn)
        #expect(file.skipped.isEmpty)

        let fresh = try TestStore()
        let summary = fresh.viewModel.importEntries(file.entries, year: thisYear)

        #expect(summary.added == 3)
        #expect(summary.updated == 0)
        #expect(summary.newYears == [thisYear - 1, thisYear])
        #expect(summary.newCategories.isEmpty)
        #expect(fresh.viewModel.years == [thisYear, thisYear - 1])
        #expect(fresh.viewModel.generateAllYearsCSV() == csv)
    }

    @Test("Importing the same file again updates amounts instead of adding copies")
    func reimport() throws {
        let store = try TestStore()
        let viewModel = store.viewModel
        viewModel.addYear(thisYear)
        store.addItem("Savings", 8_000, year: thisYear, category: "Cash", asset: true)
        let file = try #require(readFile("""
            Year,Name,Amount,Category,Type,Month
            \(thisYear),Savings,9500,cash,asset,0
            \(thisYear),Visa,700,Credit Card,liability,0
            """))

        let preview = viewModel.importSummary(of: file.entries, year: thisYear)
        #expect(preview.added == 1)
        #expect(preview.updated == 1)
        #expect(preview.newYears.isEmpty)

        viewModel.importEntries(file.entries, year: thisYear)
        let again = viewModel.importEntries(file.entries, year: thisYear)

        #expect(again.added == 0)
        #expect(again.updated == 2)
        let data = viewModel.getYearData(for: thisYear)
        #expect(data.assets == 9_500)
        #expect(data.liabilities == 700)
        #expect(viewModel.assets.count == 1)
        #expect(viewModel.liabilities.count == 1)
    }

    @Test("A new category is added once, and known ones keep the app's spelling")
    func categories() throws {
        let store = try TestStore()
        let file = try #require(readFile("""
            Name,Amount,Category,Type
            Coinbase,500,Brokerage,asset
            Schwab,900,brokerage,asset
            Savings,100,CASH,asset
            """))

        let summary = store.viewModel.importEntries(file.entries, year: thisYear)

        #expect(summary.newCategories == [ImportSummary.NewCategory(name: "Brokerage", isAsset: true)])
        #expect(store.viewModel.allCategoryNames(for: ItemType.asset).contains("Brokerage"))
        let categories = store.viewModel.assets.map(\.category).sorted()
        #expect(categories == ["Brokerage", "Brokerage", "Cash"])
    }

    // MARK: Exporting

    @Test("CSV files are written for sharing")
    func csvFile() throws {
        let store = try TestStore()

        let url = try #require(store.viewModel.csvFile(named: "Test \(UUID().uuidString).csv", contents: "a,b\n"))

        let text = try String(contentsOf: url, encoding: .utf8)
        #expect(text == "a,b\n")
        #expect(url.pathExtension == "csv")
    }

    @Test("The import result reads naturally")
    func resultMessage() {
        let summary = ImportSummary(added: 1, updated: 2, newYears: [2023, 2024], newCategories: [])
        #expect(CSVImportView.resultMessage(for: summary) == "Added 1 entry and updated 2. New years: 2023, 2024.")
    }
}
