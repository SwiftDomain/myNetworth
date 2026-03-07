//
//  NetWorthWidget.swift
//  NetWorthWidget
//
//  Created by BeastMode.
//

import WidgetKit
import SwiftUI
import SwiftData

// MARK: - Widget Entry

struct NetWorthEntry: TimelineEntry {
    let date: Date
    let netWorth: Int
    let assets: Int
    let liabilities: Int
    let percentageChange: Double?
    let currencyCode: String
    let year: Int
}

// MARK: - Timeline Provider

struct NetWorthProvider: TimelineProvider {

    func placeholder(in context: Context) -> NetWorthEntry {
        NetWorthEntry(
            date: .now,
            netWorth: 250_000,
            assets: 350_000,
            liabilities: 100_000,
            percentageChange: 5.2,
            currencyCode: "USD",
            year: Calendar.current.component(.year, from: .now)
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (NetWorthEntry) -> Void) {
        completion(fetchCurrentEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<NetWorthEntry>) -> Void) {
        let entry = fetchCurrentEntry()
        let nextUpdate = Calendar.current.date(byAdding: .hour, value: 1, to: .now) ?? .now
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }

    private func fetchCurrentEntry() -> NetWorthEntry {
        let schema = Schema([
            FinancialItem.self,
            TrackedYear.self,
            UserSettings.self,
            Goal.self,
            RecurringItem.self,
            Milestone.self,
            CustomCategory.self,
        ])

        let config = ModelConfiguration(
            schema: schema,
            groupContainer: .identifier("group.com.beastmode.myNetworth")
        )

        guard let container = try? ModelContainer(for: schema, configurations: [config]) else {
            return NetWorthEntry(
                date: .now,
                netWorth: 0,
                assets: 0,
                liabilities: 0,
                percentageChange: nil,
                currencyCode: "USD",
                year: Calendar.current.component(.year, from: .now)
            )
        }

        let context = ModelContext(container)
        let currentYear = Calendar.current.component(.year, from: .now)

        // Fetch currency
        let settingsDescriptor = FetchDescriptor<UserSettings>()
        let currencyCode = (try? context.fetch(settingsDescriptor))?.first?.currencyCode ?? "USD"

        // Fetch all items and filter in memory (simpler for widget context)
        let itemDescriptor = FetchDescriptor<FinancialItem>()
        let allItems = (try? context.fetch(itemDescriptor)) ?? []

        let yearItems = allItems.filter { $0.year == currentYear }
        let totalAssets = yearItems.filter { $0.itemType == "asset" }.reduce(0) { $0 + $1.amount }
        let totalLiabilities = yearItems.filter { $0.itemType == "liability" }.reduce(0) { $0 + $1.amount }
        let netWorth = totalAssets - totalLiabilities

        // Previous year for percentage change
        let previousYear = currentYear - 1
        let prevItems = allItems.filter { $0.year == previousYear }
        let prevAssets = prevItems.filter { $0.itemType == "asset" }.reduce(0) { $0 + $1.amount }
        let prevLiabilities = prevItems.filter { $0.itemType == "liability" }.reduce(0) { $0 + $1.amount }
        let prevNetWorth = prevAssets - prevLiabilities

        let percentageChange: Double? = prevNetWorth != 0
            ? Double(netWorth - prevNetWorth) / Double(abs(prevNetWorth)) * 100
            : nil

        return NetWorthEntry(
            date: .now,
            netWorth: netWorth,
            assets: totalAssets,
            liabilities: totalLiabilities,
            percentageChange: percentageChange,
            currencyCode: currencyCode,
            year: currentYear
        )
    }
}

// MARK: - Widget Entry View

struct NetWorthWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    let entry: NetWorthEntry

    var body: some View {
        switch family {
        case .systemMedium:
            MediumNetWorthView(entry: entry)
        default:
            SmallNetWorthView(entry: entry)
        }
    }
}

// MARK: - Small Widget View

struct SmallNetWorthView: View {
    let entry: NetWorthEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .foregroundStyle(.blue)
                Spacer()
                Text(String(entry.year))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text("Net Worth")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(entry.netWorth, format: .currency(code: entry.currencyCode).precision(.fractionLength(0)))
                .font(.title3)
                .bold()
                .foregroundStyle(entry.netWorth >= 0 ? .green : .red)
                .minimumScaleFactor(0.5)

            if let change = entry.percentageChange {
                HStack(spacing: 2) {
                    Image(systemName: change >= 0 ? "arrow.up.right" : "arrow.down.right")
                    Text(abs(change), format: .number.precision(.fractionLength(1)))
                    Text("%")
                }
                .font(.caption2)
                .foregroundStyle(change >= 0 ? .green : .red)
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

// MARK: - Medium Widget View

struct MediumNetWorthView: View {
    let entry: NetWorthEntry

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .foregroundStyle(.blue)
                    Text("myNetworth")
                        .font(.headline)
                }

                Spacer()

                Text("Net Worth")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(entry.netWorth, format: .currency(code: entry.currencyCode).precision(.fractionLength(0)))
                    .font(.title2)
                    .bold()
                    .foregroundStyle(entry.netWorth >= 0 ? .green : .red)
                    .minimumScaleFactor(0.5)

                if let change = entry.percentageChange {
                    HStack(spacing: 4) {
                        Image(systemName: change >= 0 ? "arrow.up.right" : "arrow.down.right")
                        Text(abs(change), format: .number.precision(.fractionLength(1)))
                        Text("% vs last year")
                    }
                    .font(.caption)
                    .foregroundStyle(change >= 0 ? .green : .red)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 16) {
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Assets")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(entry.assets, format: .currency(code: entry.currencyCode).precision(.fractionLength(0)))
                        .font(.subheadline)
                        .bold()
                        .foregroundStyle(.green)
                        .minimumScaleFactor(0.7)
                }

                VStack(alignment: .trailing, spacing: 4) {
                    Text("Liabilities")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(entry.liabilities, format: .currency(code: entry.currencyCode).precision(.fractionLength(0)))
                        .font(.subheadline)
                        .bold()
                        .foregroundStyle(.red)
                        .minimumScaleFactor(0.7)
                }
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

// MARK: - Widget

struct NetWorthWidget: Widget {
    let kind = "NetWorthWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: NetWorthProvider()) { entry in
            NetWorthWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Net Worth")
        .description("Track your current net worth at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Widget Bundle

@main
struct NetWorthWidgetBundle: WidgetBundle {
    var body: some Widget {
        NetWorthWidget()
    }
}

// MARK: - Previews

#Preview("Small Widget", as: .systemSmall) {
    NetWorthWidget()
} timeline: {
    NetWorthEntry(
        date: .now,
        netWorth: 250_000,
        assets: 350_000,
        liabilities: 100_000,
        percentageChange: 5.2,
        currencyCode: "USD",
        year: 2026
    )
}

#Preview("Medium Widget", as: .systemMedium) {
    NetWorthWidget()
} timeline: {
    NetWorthEntry(
        date: .now,
        netWorth: 250_000,
        assets: 350_000,
        liabilities: 100_000,
        percentageChange: 5.2,
        currencyCode: "USD",
        year: 2026
    )
}
