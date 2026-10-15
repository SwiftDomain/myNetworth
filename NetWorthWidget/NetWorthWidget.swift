//
//  NetWorthWidget.swift
//  NetWorthWidget
//
//  Created by BeastMode.
//

import WidgetKit
import SwiftUI
import SwiftData
import Charts

// MARK: - Widget Entry

struct NetWorthEntry: TimelineEntry {
    let date: Date
    /// Nil until the app has numbers to show.
    let snapshot: WidgetSnapshot?
    let currencyCode: String
    /// The app's Hide Amounts setting: amounts are masked while it's on.
    var hidesAmounts = false
    /// The goal the Top Goal widget shows. Nil until a goal is set.
    var goal: GoalSnapshot? = nil
}

// MARK: - Timeline Provider

struct NetWorthProvider: TimelineProvider {

    func placeholder(in context: Context) -> NetWorthEntry {
        NetWorthEntry(date: .now, snapshot: .sample, currencyCode: "USD", goal: .sample)
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
        let goals = (try? context.fetch(FetchDescriptor<Goal>())) ?? []

        return NetWorthEntry(
            date: .now,
            snapshot: WidgetSnapshot.make(from: items),
            currencyCode: currencyCode,
            hidesAmounts: SharedStore.defaults.bool(forKey: SharedStore.hideAmountsKey),
            goal: GoalSnapshot.make(goals: goals, items: items)
        )
    }
}

extension WidgetSnapshot {
    static let sample: WidgetSnapshot = {
        let thisYear = Calendar.current.component(.year, from: .now)
        let netWorths = [150_000, 172_000, 165_000, 210_000, 237_600, 250_000]
        return WidgetSnapshot(
            year: thisYear,
            assets: 350_000,
            liabilities: 100_000,
            previousYear: thisYear - 1,
            percentageChange: 5.2,
            trend: netWorths.enumerated().map { offset, netWorth in
                YearPoint(year: thisYear - netWorths.count + 1 + offset, netWorth: netWorth)
            }
        )
    }()
}

extension GoalSnapshot {
    static let sample = GoalSnapshot(
        title: "Emergency fund",
        isDebtGoal: false,
        targetAmount: 20_000,
        currentAmount: 13_000,
        progress: 0.65,
        pace: .onTrack(projected: Calendar.current.date(byAdding: .month, value: 7, to: .now) ?? .now),
        targetDate: Calendar.current.date(byAdding: .month, value: 10, to: .now)
    )
}

// MARK: - Widget Entry View

struct NetWorthWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    let entry: NetWorthEntry

    var body: some View {
        content
            // Amounts are privacy-sensitive, so they're masked while Hide Amounts is on.
            .redacted(reason: entry.hidesAmounts ? .privacy : [])
    }

    @ViewBuilder
    private var content: some View {
        switch family {
        case .accessoryInline:
            InlineNetWorthView(snapshot: entry.snapshot, currencyCode: entry.currencyCode)
        case .accessoryCircular:
            CircularNetWorthView(snapshot: entry.snapshot, currencyCode: entry.currencyCode)
        case .accessoryRectangular:
            RectangularNetWorthView(snapshot: entry.snapshot, currencyCode: entry.currencyCode)
        case .systemMedium:
            if let snapshot = entry.snapshot {
                MediumNetWorthView(snapshot: snapshot, currencyCode: entry.currencyCode)
            } else {
                EmptyNetWorthView()
            }
        default:
            if let snapshot = entry.snapshot {
                SmallNetWorthView(snapshot: snapshot, currencyCode: entry.currencyCode)
            } else {
                EmptyNetWorthView()
            }
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

// MARK: - Lock Screen Views

// The Lock Screen draws these in a single tint, so they rely on layout rather than color.
// Amounts are privacy-sensitive, so they stay hidden until Face ID unlocks the phone.

/// One line above the clock: "Net worth $250K".
struct InlineNetWorthView: View {
    let snapshot: WidgetSnapshot?
    let currencyCode: String

    var body: some View {
        Group {
            if let snapshot {
                Label {
                    Text("Net worth \(snapshot.netWorth, format: .currency(code: currencyCode).notation(.compactName))")
                        .privacySensitive()
                } icon: {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                }
            } else {
                Label("myNetworth", systemImage: "chart.line.uptrend.xyaxis")
            }
        }
        .containerBackground(.clear, for: .widget)
    }
}

/// A round slot under the clock: the direction of the change and the net worth, shortened.
struct CircularNetWorthView: View {
    let snapshot: WidgetSnapshot?
    let currencyCode: String

    private var icon: String {
        guard let change = snapshot?.percentageChange else { return "chart.line.uptrend.xyaxis" }
        return change >= 0 ? "arrow.up.right" : "arrow.down.right"
    }

    var body: some View {
        ZStack {
            AccessoryWidgetBackground()

            VStack(spacing: 1) {
                Image(systemName: icon)
                    .font(.caption)

                if let snapshot {
                    Text(snapshot.netWorth, format: .currency(code: currencyCode).notation(.compactName))
                        .font(.system(.caption, design: .rounded))
                        .bold()
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .privacySensitive()
                }
            }
            .padding(4)
        }
        .containerBackground(.clear, for: .widget)
    }
}

/// A wider slot under the clock: net worth and the change since the previous year.
struct RectangularNetWorthView: View {
    let snapshot: WidgetSnapshot?
    let currencyCode: String

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Label("Net Worth", systemImage: "chart.line.uptrend.xyaxis")
                .font(.caption)
                .widgetAccentable()

            if let snapshot {
                Text(snapshot.netWorth, format: .currency(code: currencyCode).precision(.fractionLength(0)))
                    .font(.headline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .privacySensitive()

                if let change = snapshot.percentageChange, let previousYear = snapshot.previousYear {
                    Text("\(change >= 0 ? "Up" : "Down") \(abs(change), format: .number.precision(.fractionLength(1)))% since \(String(previousYear))")
                        .font(.caption)
                        .lineLimit(1)
                } else {
                    Text(String(snapshot.year))
                        .font(.caption)
                }
            } else {
                Text("Add your accounts in myNetworth")
                    .font(.caption)
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .containerBackground(.clear, for: .widget)
    }
}

// MARK: - Trend Views

/// Net worth over the years, like the Net Worth Over Time chart in Analysis.
struct TrendChart: View {
    let points: [WidgetSnapshot.YearPoint]
    var showsYears = false

    var body: some View {
        Chart(points) { point in
            LineMark(
                x: .value("Year", String(point.year)),
                y: .value("Net Worth", point.netWorth)
            )
            .interpolationMethod(.monotone)
            .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round))

            if point.id == points.last?.id {
                PointMark(
                    x: .value("Year", String(point.year)),
                    y: .value("Net Worth", point.netWorth)
                )
                .symbolSize(30)
            }
        }
        // Start the scale at the lowest value rather than zero, so changes are visible.
        .chartYScale(domain: .automatic(includesZero: false))
        .chartYAxis(.hidden)
        .chartXAxis {
            AxisMarks(values: axisYears) { _ in
                AxisValueLabel()
            }
        }
    }

    /// The first and last years, when years are shown.
    private var axisYears: [String] {
        guard showsYears, let first = points.first, let last = points.last else { return [] }
        return [String(first.year), String(last.year)]
    }
}

/// The Lock Screen's widest size: net worth and its trend.
struct RectangularTrendView: View {
    let snapshot: WidgetSnapshot?
    let currencyCode: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline) {
                Label("Net Worth", systemImage: "chart.line.uptrend.xyaxis")
                    .font(.caption2)
                    .widgetAccentable()

                Spacer(minLength: 4)

                if let snapshot {
                    Text(snapshot.netWorth, format: .currency(code: currencyCode).notation(.compactName))
                        .font(.caption)
                        .bold()
                        .privacySensitive()
                }
            }

            if let snapshot, snapshot.trend.count >= 2 {
                TrendChart(points: snapshot.trend)
            } else {
                Text(snapshot == nil ? "Add your accounts in myNetworth" : "Your trend appears once two years have data")
                    .font(.caption2)
                    .lineLimit(2)
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .containerBackground(.clear, for: .widget)
    }
}

/// The full-width Home Screen size: net worth, the change since the first year, and the trend.
struct MediumTrendView: View {
    let snapshot: WidgetSnapshot?
    let currencyCode: String

    private var currency: IntegerFormatStyle<Int>.Currency {
        .currency(code: currencyCode).precision(.fractionLength(0))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label("Net Worth Over Time", systemImage: "chart.line.uptrend.xyaxis")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                if let snapshot {
                    Text(snapshot.netWorth, format: currency)
                        .font(.headline)
                        .foregroundStyle(snapshot.netWorth >= 0 ? .green : .red)
                        .privacySensitive()
                }
            }

            if let snapshot, let first = snapshot.trend.first, snapshot.trend.count >= 2 {
                let change = snapshot.netWorth - first.netWorth
                Text("\(change >= 0 ? "+" : "−")\(abs(change), format: currency) since \(String(first.year))")
                    .font(.caption)
                    .foregroundStyle(change >= 0 ? .green : .red)
                    .privacySensitive()

                TrendChart(points: snapshot.trend, showsYears: true)
                    .foregroundStyle(.blue)
            } else {
                Spacer()
                Text(snapshot == nil
                    ? "Add your accounts in myNetworth to see your net worth over time."
                    : "Your trend appears once two years have data.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

struct NetWorthTrendEntryView: View {
    @Environment(\.widgetFamily) var family
    let entry: NetWorthEntry

    var body: some View {
        content
            // Amounts are privacy-sensitive, so they're masked while Hide Amounts is on.
            .redacted(reason: entry.hidesAmounts ? .privacy : [])
    }

    @ViewBuilder
    private var content: some View {
        switch family {
        case .accessoryRectangular:
            RectangularTrendView(snapshot: entry.snapshot, currencyCode: entry.currencyCode)
        default:
            MediumTrendView(snapshot: entry.snapshot, currencyCode: entry.currencyCode)
        }
    }
}

// MARK: - Goal Views

/// How the goal is pacing, in one short line.
struct GoalPaceText: View {
    let goal: GoalSnapshot
    let currencyCode: String

    private var currency: IntegerFormatStyle<Int>.Currency {
        .currency(code: currencyCode).precision(.fractionLength(0))
    }

    private var monthYear: Date.FormatStyle {
        .dateTime.month(.abbreviated).year()
    }

    var body: some View {
        switch goal.pace {
        case .reached:
            Text("Goal reached")
        case .onTrack(let projected):
            Text("On track · around \(projected, format: monthYear)")
        case .behind(let perMonth):
            Text("Behind · \(goal.isDebtGoal ? "pay down" : "save") \(perMonth, format: currency)/mo")
                .privacySensitive()
        case .needs(let perMonth):
            Text("\(goal.isDebtGoal ? "Pay down" : "Save") \(perMonth, format: currency)/mo to make it")
                .privacySensitive()
        case .overdue(let remaining):
            Text("Date passed · \(remaining, format: currency) to go")
                .privacySensitive()
        case .noDate(let projected?):
            Text("Around \(projected, format: monthYear) at your pace")
        case .noDate(nil):
            Text("No target date")
        case nil:
            Text("Add your numbers in myNetworth")
        }
    }
}

/// Where the goal stands: "$13,000 of $20,000", or what's still owed for a debt goal.
struct GoalAmountText: View {
    let goal: GoalSnapshot
    let currencyCode: String

    private var currency: IntegerFormatStyle<Int>.Currency {
        .currency(code: currencyCode).precision(.fractionLength(0))
    }

    var body: some View {
        Group {
            if let current = goal.currentAmount {
                if goal.isDebtGoal {
                    Text("\(current, format: currency) owed · goal \(goal.targetAmount, format: currency)")
                } else {
                    Text("\(current, format: currency) of \(goal.targetAmount, format: currency)")
                }
            } else {
                Text("Goal \(goal.targetAmount, format: currency)")
            }
        }
        .privacySensitive()
    }
}

struct EmptyGoalView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: "target")
                .foregroundStyle(.blue)

            Spacer()

            Text("Set a goal in myNetworth to see your progress here.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

struct SmallGoalView: View {
    let goal: GoalSnapshot
    let currencyCode: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: goal.isReached ? "checkmark.seal.fill" : "target")
                    .foregroundStyle(goal.isReached ? .green : .blue)
                Spacer()
                Text(goal.progress, format: .percent.precision(.fractionLength(0)))
                    .font(.caption)
                    .bold()
            }

            Text(goal.title)
                .font(.headline)
                .lineLimit(2)

            Spacer(minLength: 0)

            ProgressView(value: goal.progress)
                .tint(goal.progress >= 1 ? .green : .blue)

            GoalPaceText(goal: goal, currencyCode: currencyCode)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

struct MediumGoalView: View {
    let goal: GoalSnapshot
    let currencyCode: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label("Top Goal", systemImage: goal.isReached ? "checkmark.seal.fill" : "target")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                if let targetDate = goal.targetDate {
                    Text("By \(targetDate, format: .dateTime.month(.abbreviated).year())")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Text(goal.title)
                .font(.headline)
                .lineLimit(1)

            GoalAmountText(goal: goal, currencyCode: currencyCode)
                .font(.subheadline)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Spacer(minLength: 0)

            HStack {
                ProgressView(value: goal.progress)
                    .tint(goal.progress >= 1 ? .green : .blue)
                Text(goal.progress, format: .percent.precision(.fractionLength(0)))
                    .font(.caption)
                    .bold()
            }

            GoalPaceText(goal: goal, currencyCode: currencyCode)
                .font(.caption)
                .foregroundStyle(goal.isReached ? .green : .secondary)
                .lineLimit(1)
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

/// A round slot under the clock: a ring filling up toward the goal.
struct CircularGoalView: View {
    let goal: GoalSnapshot?

    var body: some View {
        Group {
            if let goal {
                Gauge(value: goal.progress) {
                    Image(systemName: "target")
                } currentValueLabel: {
                    Text(goal.progress * 100, format: .number.precision(.fractionLength(0)))
                }
                .gaugeStyle(.accessoryCircularCapacity)
            } else {
                ZStack {
                    AccessoryWidgetBackground()
                    Image(systemName: "target")
                        .font(.title3)
                }
            }
        }
        .containerBackground(.clear, for: .widget)
    }
}

/// A wider slot under the clock: the goal, its progress and its pace.
struct RectangularGoalView: View {
    let goal: GoalSnapshot?
    let currencyCode: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            if let goal {
                HStack {
                    Label(goal.title, systemImage: "target")
                        .font(.caption)
                        .lineLimit(1)
                        .widgetAccentable()
                    Spacer(minLength: 4)
                    Text(goal.progress, format: .percent.precision(.fractionLength(0)))
                        .font(.caption)
                        .bold()
                }

                ProgressView(value: goal.progress)

                GoalPaceText(goal: goal, currencyCode: currencyCode)
                    .font(.caption)
                    .lineLimit(1)
            } else {
                Label("Goals", systemImage: "target")
                    .font(.caption)
                    .widgetAccentable()
                Text("Set a goal in myNetworth")
                    .font(.caption)
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .containerBackground(.clear, for: .widget)
    }
}

struct GoalEntryView: View {
    @Environment(\.widgetFamily) var family
    let entry: NetWorthEntry

    var body: some View {
        content
            // Amounts are privacy-sensitive, so they're masked while Hide Amounts is on.
            .redacted(reason: entry.hidesAmounts ? .privacy : [])
    }

    @ViewBuilder
    private var content: some View {
        switch family {
        case .accessoryCircular:
            CircularGoalView(goal: entry.goal)
        case .accessoryRectangular:
            RectangularGoalView(goal: entry.goal, currencyCode: entry.currencyCode)
        case .systemMedium:
            if let goal = entry.goal {
                MediumGoalView(goal: goal, currencyCode: entry.currencyCode)
            } else {
                EmptyGoalView()
            }
        default:
            if let goal = entry.goal {
                SmallGoalView(goal: goal, currencyCode: entry.currencyCode)
            } else {
                EmptyGoalView()
            }
        }
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
        .supportedFamilies([
            .systemSmall, .systemMedium,
            .accessoryInline, .accessoryCircular, .accessoryRectangular,
        ])
    }
}

/// Net worth over the years: the Lock Screen's widest size and full width on the Home Screen.
struct NetWorthTrendWidget: Widget {
    let kind = "NetWorthTrendWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: NetWorthProvider()) { entry in
            NetWorthTrendEntryView(entry: entry)
        }
        .configurationDisplayName("Net Worth Trend")
        .description("Your net worth over the years, from Analysis.")
        .supportedFamilies([.accessoryRectangular, .systemMedium])
    }
}

/// Progress toward the goal Home features, and whether it's on pace.
struct GoalWidget: Widget {
    let kind = "GoalWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: NetWorthProvider()) { entry in
            GoalEntryView(entry: entry)
        }
        .configurationDisplayName("Top Goal")
        .description("Progress toward your next goal, and whether you're on pace.")
        .supportedFamilies([
            .systemSmall, .systemMedium,
            .accessoryCircular, .accessoryRectangular,
        ])
    }
}

// MARK: - Widget Bundle

@main
struct NetWorthWidgetBundle: WidgetBundle {
    var body: some Widget {
        NetWorthWidget()
        NetWorthTrendWidget()
        GoalWidget()
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

#Preview("Lock Screen", as: .accessoryRectangular) {
    NetWorthWidget()
} timeline: {
    NetWorthEntry(date: .now, snapshot: .sample, currencyCode: "USD")
    NetWorthEntry(date: .now, snapshot: nil, currencyCode: "USD")
}

#Preview("Lock Screen Circular", as: .accessoryCircular) {
    NetWorthWidget()
} timeline: {
    NetWorthEntry(date: .now, snapshot: .sample, currencyCode: "USD")
}

#Preview("Lock Screen Inline", as: .accessoryInline) {
    NetWorthWidget()
} timeline: {
    NetWorthEntry(date: .now, snapshot: .sample, currencyCode: "USD")
}

#Preview("Trend, Lock Screen", as: .accessoryRectangular) {
    NetWorthTrendWidget()
} timeline: {
    NetWorthEntry(date: .now, snapshot: .sample, currencyCode: "USD")
    NetWorthEntry(date: .now, snapshot: nil, currencyCode: "USD")
}

#Preview("Trend, Home Screen", as: .systemMedium) {
    NetWorthTrendWidget()
} timeline: {
    NetWorthEntry(date: .now, snapshot: .sample, currencyCode: "USD")
}

#Preview("Goal, Small", as: .systemSmall) {
    GoalWidget()
} timeline: {
    NetWorthEntry(date: .now, snapshot: .sample, currencyCode: "USD", goal: .sample)
    NetWorthEntry(date: .now, snapshot: .sample, currencyCode: "USD")
}

#Preview("Goal, Medium", as: .systemMedium) {
    GoalWidget()
} timeline: {
    NetWorthEntry(date: .now, snapshot: .sample, currencyCode: "USD", goal: .sample)
}

#Preview("Goal, Lock Screen", as: .accessoryRectangular) {
    GoalWidget()
} timeline: {
    NetWorthEntry(date: .now, snapshot: .sample, currencyCode: "USD", goal: .sample)
}

#Preview("Goal, Lock Screen Circular", as: .accessoryCircular) {
    GoalWidget()
} timeline: {
    NetWorthEntry(date: .now, snapshot: .sample, currencyCode: "USD", goal: .sample)
}
