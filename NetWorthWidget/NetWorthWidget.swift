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
    /// Nil until the app has numbers to show.
    let snapshot: WidgetSnapshot?
    let currencyCode: String
}

// MARK: - Timeline Provider

struct NetWorthProvider: TimelineProvider {

    func placeholder(in context: Context) -> NetWorthEntry {
        NetWorthEntry(date: .now, snapshot: .sample, currencyCode: "USD")
    }

    func getSnapshot(in context: Context, completion: @escaping (NetWorthEntry) -> Void) {
        // The widget gallery shows sample numbers rather than the user's own.
        completion(context.isPreview ? placeholder(in: context) : fetchCurrentEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<NetWorthEntry>) -> Void) {
        // The app reloads the widget whenever its data changes; this is a fallback.
        let entry = fetchCurrentEntry()
        let nextUpdate = Calendar.current.date(byAdding: .hour, value: 1, to: .now) ?? .now
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }

    private func fetchCurrentEntry() -> NetWorthEntry {
        // Only open a store the app has already created. Opening a missing one would create
        // an empty store, and the app would then skip copying the user's existing data into it.
        guard let storeURL = SharedStore.groupStoreURL,
              FileManager.default.fileExists(atPath: storeURL.path(percentEncoded: false)) else {
            return NetWorthEntry(date: .now, snapshot: nil, currencyCode: "USD")
        }

        let schema = SharedStore.schema
        let config = ModelConfiguration(schema: schema, url: storeURL, cloudKitDatabase: .none)
        guard let container = try? ModelContainer(for: schema, configurations: [config]) else {
            return NetWorthEntry(date: .now, snapshot: nil, currencyCode: "USD")
        }

        let context = ModelContext(container)
        let currencyCode = (try? context.fetch(FetchDescriptor<UserSettings>()))?.first?.currencyCode ?? "USD"
        let items = (try? context.fetch(FetchDescriptor<FinancialItem>())) ?? []

        return NetWorthEntry(
            date: .now,
            snapshot: WidgetSnapshot.make(from: items),
            currencyCode: currencyCode
        )
    }
}

extension WidgetSnapshot {
    static let sample = WidgetSnapshot(
        year: Calendar.current.component(.year, from: .now),
        assets: 350_000,
        liabilities: 100_000,
        previousYear: Calendar.current.component(.year, from: .now) - 1,
        percentageChange: 5.2
    )
}

// MARK: - Widget Entry View

struct NetWorthWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    let entry: NetWorthEntry

    var body: some View {
        if let snapshot = entry.snapshot {
            switch family {
            case .systemMedium:
                MediumNetWorthView(snapshot: snapshot, currencyCode: entry.currencyCode)
            default:
                SmallNetWorthView(snapshot: snapshot, currencyCode: entry.currencyCode)
            }
        } else {
            EmptyNetWorthView()
        }
    }
}

// MARK: - Empty Widget View

struct EmptyNetWorthView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .foregroundStyle(.blue)

            Spacer()

            Text("Add your accounts in myNetworth to see your net worth here.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

// MARK: - Small Widget View

struct SmallNetWorthView: View {
    let snapshot: WidgetSnapshot
    let currencyCode: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .foregroundStyle(.blue)
                Spacer()
                Text(String(snapshot.year))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text("Net Worth")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(snapshot.netWorth, format: .currency(code: currencyCode).precision(.fractionLength(0)))
                .font(.title3)
                .bold()
                .foregroundStyle(snapshot.netWorth >= 0 ? .green : .red)
                .minimumScaleFactor(0.5)
                .privacySensitive()

            if let change = snapshot.percentageChange {
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
    let snapshot: WidgetSnapshot
    let currencyCode: String

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

                Text(snapshot.netWorth, format: .currency(code: currencyCode).precision(.fractionLength(0)))
                    .font(.title2)
                    .bold()
                    .foregroundStyle(snapshot.netWorth >= 0 ? .green : .red)
                    .minimumScaleFactor(0.5)
                    .privacySensitive()

                if let change = snapshot.percentageChange, let previousYear = snapshot.previousYear {
                    HStack(spacing: 4) {
                        Image(systemName: change >= 0 ? "arrow.up.right" : "arrow.down.right")
                        Text(abs(change), format: .number.precision(.fractionLength(1)))
                        Text("% since \(String(previousYear))")
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
                    Text(snapshot.assets, format: .currency(code: currencyCode).precision(.fractionLength(0)))
                        .font(.subheadline)
                        .bold()
                        .foregroundStyle(.green)
                        .minimumScaleFactor(0.7)
                        .privacySensitive()
                }

                VStack(alignment: .trailing, spacing: 4) {
                    Text("Liabilities")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(snapshot.liabilities, format: .currency(code: currencyCode).precision(.fractionLength(0)))
                        .font(.subheadline)
                        .bold()
                        .foregroundStyle(.red)
                        .minimumScaleFactor(0.7)
                        .privacySensitive()
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
    NetWorthEntry(date: .now, snapshot: .sample, currencyCode: "USD")
    NetWorthEntry(date: .now, snapshot: nil, currencyCode: "USD")
}

#Preview("Medium Widget", as: .systemMedium) {
    NetWorthWidget()
} timeline: {
    NetWorthEntry(date: .now, snapshot: .sample, currencyCode: "USD")
}
