//
//  SettingsView.swift
//  myNetworth
//

import SwiftUI
import SwiftData
import UIKit

// MARK: - Settings View

struct SettingsView: View {
    var viewModel: NetWorthViewModel
    @AppStorage(SharedStore.hideAmountsKey, store: SharedStore.defaults) private var hideAmounts = false
    @AppStorage(BalanceReminder.enabledKey) private var reminderEnabled = false
    @AppStorage(BalanceReminder.dayKey) private var reminderDay = BalanceReminder.defaultDay
    @AppStorage(BalanceReminder.minuteKey) private var reminderMinute = BalanceReminder.defaultMinute
    @State private var notificationsDenied = false
    @Environment(\.openURL) private var openURL
    @State private var exportYear: Int
    @State private var pdfURL: URL?

    private let currencies = [
        "USD", "EUR", "GBP", "JPY", "CAD", "AUD", "CHF", "CNY", "INR", "MXN",
        "BRL", "KRW", "SEK", "NOK", "DKK", "NZD", "SGD", "HKD", "ZAR", "TRY",
    ]

    init(viewModel: NetWorthViewModel) {
        self.viewModel = viewModel
        _exportYear = State(initialValue: viewModel.years.first ?? 0)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Currency") {
                    Picker("Currency", selection: Bindable(viewModel.settings).currencyCode) {
                        ForEach(currencies, id: \.self) { code in
                            Text("\(code) — \(Locale.current.localizedString(forCurrencyCode: code) ?? code)")
                                .tag(code)
                        }
                    }
                }

                Section("Appearance") {
                    Picker("Color Scheme", selection: Bindable(viewModel.settings).colorScheme) {
                        Text("System").tag("system")
                        Text("Dark").tag("dark")
                        Text("Light").tag("light")
                    }
                }

                Section {
                    Toggle("Require Face ID", isOn: Bindable(viewModel.settings).requireBiometricLock)
                    Toggle("Hide Amounts", isOn: $hideAmounts)
                } header: {
                    Text("Privacy")
                } footer: {
                    Text("Hide Amounts masks every amount, in the app and its widgets, until you turn it off. The eye button at the top of each tab does the same.")
                }

                Section {
                    Toggle("Monthly Reminder", isOn: $reminderEnabled)

                    if reminderEnabled {
                        Picker("Day", selection: $reminderDay) {
                            ForEach(Array(BalanceReminder.days), id: \.self) { day in
                                Text(ordinal(day)).tag(day)
                            }
                        }

                        DatePicker("Time", selection: reminderTime, displayedComponents: .hourAndMinute)
                    }
                } header: {
                    Text("Reminders")
                } footer: {
                    if notificationsDenied {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Notifications are turned off for myNetworth.")
                            Button("Turn On in iOS Settings") {
                                if let url = URL(string: UIApplication.openNotificationSettingsURLString) {
                                    openURL(url)
                                }
                            }
                        }
                    } else {
                        Text("A notification on this day each month to update your balances. It never shows amounts.")
                    }
                }

                Section("Data Management") {
                    NavigationLink("Custom Categories") {
                        ManageCategoriesView(viewModel: viewModel)
                    }

                    NavigationLink("Milestones") {
                        MilestonesListView(viewModel: viewModel)
                    }
                }

                Section("Export") {
                    if viewModel.years.isEmpty {
                        Text("Add a year to export your data.")
                            .foregroundStyle(.secondary)
                    } else {
                        Picker("Year", selection: $exportYear) {
                            ForEach(viewModel.years, id: \.self) { year in
                                Text(String(year)).tag(year)
                            }
                        }

                        ShareLink(
                            "Export CSV",
                            item: viewModel.generateCSV(for: exportYear),
                            preview: SharePreview("Net Worth \(String(exportYear)).csv")
                        )

                        if let pdfURL {
                            ShareLink(
                                "Export PDF Report",
                                item: pdfURL,
                                preview: SharePreview("Net Worth \(String(exportYear)).pdf")
                            )
                        }
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .onChange(of: viewModel.years, initial: true) { _, years in
                // Settings stays open as a tab, so years can be added or deleted meanwhile.
                if !years.contains(exportYear) {
                    exportYear = years.first ?? 0
                }
            }
            .onChange(of: reminderEnabled) {
                Task { await updateReminder() }
            }
            .onChange(of: reminderDay) {
                Task { await updateReminder() }
            }
            .onChange(of: reminderMinute) {
                Task { await updateReminder() }
            }
            .task {
                notificationsDenied = await BalanceReminder.isDenied()
            }
            .task(id: "\(exportYear)-\(viewModel.currencyCode)") {
                // Render only the selected year's report, and only when the year or
                // currency changes, instead of every year's PDF on every redraw.
                pdfURL = viewModel.years.contains(exportYear)
                    ? viewModel.generatePDFURL(for: exportYear)
                    : nil
            }
        }
    }

    // MARK: Reminder

    /// The reminder time as a date today, for the time picker.
    private var reminderTime: Binding<Date> {
        Binding {
            Calendar.current.date(
                bySettingHour: reminderMinute / 60,
                minute: reminderMinute % 60,
                second: 0,
                of: .now
            ) ?? .now
        } set: { date in
            let time = Calendar.current.dateComponents([.hour, .minute], from: date)
            reminderMinute = (time.hour ?? 9) * 60 + (time.minute ?? 0)
        }
    }

    /// Schedules, moves or cancels the reminder to match the settings. Turning it on asks
    /// for permission; if that's refused the switch goes back off.
    private func updateReminder() async {
        guard reminderEnabled else {
            BalanceReminder.cancel()
            return
        }
        guard await BalanceReminder.requestPermission() else {
            notificationsDenied = true
            reminderEnabled = false
            return
        }
        notificationsDenied = false
        await BalanceReminder.schedule(day: reminderDay, minute: reminderMinute)
    }

    /// "1st", "2nd", "3rd" in the user's language.
    private func ordinal(_ day: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .ordinal
        return formatter.string(from: NSNumber(value: day)) ?? String(day)
    }
}

// MARK: - Manage Categories

struct ManageCategoriesView: View {
    var viewModel: NetWorthViewModel
    @State private var showingAddSheet = false

    var body: some View {
        List {
            Section("Built-in Asset Categories") {
                ForEach(AssetCategories.allCases, id: \.rawValue) { cat in
                    HStack {
                        Circle().fill(cat.assetColor).frame(width: 10, height: 10)
                        Text(cat.rawValue)
                    }
                }
            }

            Section("Built-in Liability Categories") {
                ForEach(LiabilityCategories.allCases, id: \.rawValue) { cat in
                    HStack {
                        Circle().fill(cat.liabilityColor).frame(width: 10, height: 10)
                        Text(cat.rawValue)
                    }
                }
            }

            if !viewModel.customCategories.isEmpty {
                Section("Custom Categories") {
                    ForEach(viewModel.customCategories) { cat in
                        HStack {
                            Circle()
                                .fill(Color(hex: cat.colorHex) ?? .gray)
                                .frame(width: 10, height: 10)
                            Text(cat.name)
                            Spacer()
                            Text(cat.itemType.capitalized)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            viewModel.deleteCustomCategory(viewModel.customCategories[index])
                        }
                    }
                }
            }
        }
        .navigationTitle("Categories")
        .toolbar {
            Button("Add Custom", systemImage: "plus") {
                showingAddSheet = true
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            AddCustomCategoryView(viewModel: viewModel)
        }
    }
}

// MARK: - Add Custom Category

struct AddCustomCategoryView: View {
    var viewModel: NetWorthViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var itemType: ItemType = .asset
    @State private var selectedColor = Color.gray

    var body: some View {
        NavigationStack {
            Form {
                TextField("Category Name", text: $name)

                Picker("Type", selection: $itemType) {
                    Text("Asset").tag(ItemType.asset)
                    Text("Liability").tag(ItemType.liability)
                }

                ColorPicker("Color", selection: $selectedColor)
            }
            .navigationTitle("New Category")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let cat = CustomCategory(
                            name: name,
                            itemType: itemType.rawValue,
                            colorHex: selectedColor.toHex() ?? "#808080"
                        )
                        viewModel.addCustomCategory(cat)
                        dismiss()
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
    }
}

// MARK: - Milestones List

struct MilestonesListView: View {
    var viewModel: NetWorthViewModel
    @State private var showingAddSheet = false

    var body: some View {
        List {
            ForEach(viewModel.milestones) { milestone in
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(milestone.title)
                            .font(.headline)
                        Text(milestone.targetNetWorth, format: .currency(code: viewModel.currencyCode).precision(.fractionLength(0)))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .privacySensitive()
                    }

                    Spacer()

                    if milestone.isAchieved {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }
                }
            }
            .onDelete { indexSet in
                for index in indexSet {
                    viewModel.deleteMilestone(viewModel.milestones[index])
                }
            }
        }
        .navigationTitle("Milestones")
        .toolbar {
            Button("Add", systemImage: "plus") {
                showingAddSheet = true
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            AddMilestoneView(viewModel: viewModel)
        }
        .overlay {
            if viewModel.milestones.isEmpty {
                ContentUnavailableView(
                    "No Milestones",
                    systemImage: "flag",
                    description: Text("Set net worth milestones to celebrate your progress")
                )
            }
        }
    }
}

// MARK: - Add Milestone

struct AddMilestoneView: View {
    var viewModel: NetWorthViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var targetAmount = 0

    var body: some View {
        NavigationStack {
            Form {
                TextField("Title (e.g. 'First $100K')", text: $title)
                TextField("Target Net Worth", value: $targetAmount, format: .number)
                    .keyboardType(.numberPad)
            }
            .navigationTitle("New Milestone")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        viewModel.addMilestone(Milestone(title: title, targetNetWorth: targetAmount))
                        dismiss()
                    }
                    .disabled(title.isEmpty || targetAmount == 0)
                }
            }
        }
    }
}

// MARK: - PDF Report View (rendered via ImageRenderer)

struct PDFReportView: View {
    let yearData: YearlyData
    var currencyCode: String = "USD"

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Net Worth Report — \(yearData.year)")
                .font(.title)
                .bold()

            Divider()

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Total Assets")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(yearData.assets, format: .currency(code: currencyCode).precision(.fractionLength(0)))
                        .font(.title2)
                        .foregroundStyle(.green)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("Total Liabilities")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(yearData.liabilities, format: .currency(code: currencyCode).precision(.fractionLength(0)))
                        .font(.title2)
                        .foregroundStyle(.red)
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 4) {
                Text("Net Worth")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(yearData.netWorth, format: .currency(code: currencyCode).precision(.fractionLength(0)))
                    .font(.largeTitle)
                    .bold()
                    .foregroundStyle(.blue)
            }

            Divider()

            if !yearData.assetCategoryTotal.isEmpty {
                Text("Asset Breakdown")
                    .font(.headline)
                ForEach(yearData.assetCategoryTotal.sorted(by: { $0.value > $1.value }), id: \.key) { category, amount in
                    HStack {
                        Text(category.rawValue)
                            .font(.subheadline)
                        Spacer()
                        Text(amount, format: .currency(code: currencyCode).precision(.fractionLength(0)))
                            .font(.subheadline)
                    }
                }
            }

            if !yearData.liabilityCategoryTotal.isEmpty {
                Text("Liability Breakdown")
                    .font(.headline)
                ForEach(yearData.liabilityCategoryTotal.sorted(by: { $0.value > $1.value }), id: \.key) { category, amount in
                    HStack {
                        Text(category.rawValue)
                            .font(.subheadline)
                        Spacer()
                        Text(amount, format: .currency(code: currencyCode).precision(.fractionLength(0)))
                            .font(.subheadline)
                    }
                }
            }

            Spacer()

            Text("Generated by myNetworth")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(32)
        .frame(width: 612, height: 792) // US Letter size at 72 DPI
        .background(.white)
    }
}

// MARK: - Color Extensions

extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacing("#", with: "")

        guard hexSanitized.count == 6,
              let rgb = UInt64(hexSanitized, radix: 16) else {
            return nil
        }

        self.init(
            red: Double((rgb >> 16) & 0xFF) / 255.0,
            green: Double((rgb >> 8) & 0xFF) / 255.0,
            blue: Double(rgb & 0xFF) / 255.0
        )
    }

    func toHex() -> String? {
        let resolved = UIColor(self)
        guard let components = resolved.cgColor.components, components.count >= 3 else {
            return nil
        }
        let r = Int(components[0] * 255)
        let g = Int(components[1] * 255)
        let b = Int(components[2] * 255)
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}
