//
//  CSVImportView.swift
//  myNetworth
//

import SwiftUI

/// Shows what a CSV file has and what importing it will do, before anything is added.
struct CSVImportView: View {
    var viewModel: NetWorthViewModel
    let file: CSVImport
    /// Called with what was imported, after the sheet closes.
    var onImported: (ImportSummary) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var year = Calendar.current.component(.year, from: .now)

    /// How many entries are listed; the rest are counted.
    private static let listedEntries = 50

    private var summary: ImportSummary {
        viewModel.importSummary(of: file.entries, year: year)
    }

    private var currency: IntegerFormatStyle<Int>.Currency {
        .currency(code: viewModel.currencyCode).precision(.fractionLength(0))
    }

    /// Years to pick from for a file without a Year column, newest first.
    private var yearChoices: [Int] {
        let thisYear = Calendar.current.component(.year, from: .now)
        let earliest = min(viewModel.years.min() ?? thisYear, thisYear) - 10
        return Array((earliest...(thisYear + 5)).reversed())
    }

    var body: some View {
        NavigationStack {
            Form {
                if !file.hasYearColumn {
                    Section {
                        Picker("Year", selection: $year) {
                            ForEach(yearChoices, id: \.self) { choice in
                                Text(String(choice)).tag(choice)
                            }
                        }
                    } footer: {
                        Text("This file has no Year column, so everything goes into the year you pick.")
                    }
                }

                Section("What Will Change") {
                    LabeledContent("New entries", value: String(summary.added))
                    if summary.updated > 0 {
                        LabeledContent("Updated amounts", value: String(summary.updated))
                    }
                    if !summary.newYears.isEmpty {
                        LabeledContent("New years", value: summary.newYears.map { String($0) }.joined(separator: ", "))
                    }
                    if !summary.newCategories.isEmpty {
                        LabeledContent("New categories", value: summary.newCategories.map(\.name).joined(separator: ", "))
                    }
                }

                if !file.entries.isEmpty {
                    Section("Entries") {
                        ForEach(Array(file.entries.prefix(Self.listedEntries).enumerated()), id: \.offset) { _, entry in
                            entryRow(entry)
                        }
                        if file.entries.count > Self.listedEntries {
                            Text("And \(file.entries.count - Self.listedEntries) more")
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                if !file.skipped.isEmpty {
                    Section {
                        ForEach(file.skipped, id: \.row) { skipped in
                            Text("Row \(skipped.row): \(skipped.reason)")
                        }
                    } header: {
                        Text("Skipped")
                    } footer: {
                        Text("These rows couldn't be read and won't be imported.")
                    }
                }
            }
            .navigationTitle("Import CSV")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Import") {
                        let result = viewModel.importEntries(file.entries, year: year)
                        dismiss()
                        onImported(result)
                    }
                    .disabled(file.entries.isEmpty)
                }
            }
        }
    }

    private func entryRow(_ entry: ImportedEntry) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.name)
                Text(details(of: entry))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(entry.amount, format: currency)
                .foregroundStyle(entry.isAsset ? Theme.positiveAmount : .red)
                .privacySensitive()
        }
    }

    /// "2025 · March · Cash · Asset"
    private func details(of entry: ImportedEntry) -> String {
        var parts = [String(entry.year ?? year)]
        if entry.month > 0 {
            parts.append(Calendar.current.monthSymbols[entry.month - 1])
        }
        parts.append(entry.category.isEmpty ? "Other" : entry.category)
        parts.append(entry.isAsset ? "Asset" : "Liability")
        return parts.joined(separator: " · ")
    }

    /// "Added 24 entries and updated 3. New years: 2023, 2024."
    static func resultMessage(for summary: ImportSummary) -> String {
        var message = "Added \(summary.added) \(summary.added == 1 ? "entry" : "entries")"
        if summary.updated > 0 {
            message += " and updated \(summary.updated)"
        }
        message += "."
        if !summary.newYears.isEmpty {
            message += " New years: \(summary.newYears.map { String($0) }.joined(separator: ", "))."
        }
        return message
    }
}
