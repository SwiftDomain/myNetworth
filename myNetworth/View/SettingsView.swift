//
//  SettingsView.swift
//  myNetworth
//

import SwiftUI
import SwiftData

// MARK: - Settings View

struct SettingsView: View {
    var viewModel: NetWorthViewModel
    @Environment(\.dismiss) private var dismiss

    private let currencies = [
        "USD", "EUR", "GBP", "JPY", "CAD", "AUD", "CHF", "CNY", "INR", "MXN",
        "BRL", "KRW", "SEK", "NOK", "DKK", "NZD", "SGD", "HKD", "ZAR", "TRY",
    ]

    private var assetColorBinding: Binding<Color> {
        Binding(
            get: { Color(hex: viewModel.settings.assetColorHex) ?? .green },
            set: { viewModel.settings.assetColorHex = $0.toHex() ?? "" }
        )
    }

    private var liabilityColorBinding: Binding<Color> {
        Binding(
            get: { Color(hex: viewModel.settings.liabilityColorHex) ?? .black },
            set: { viewModel.settings.liabilityColorHex = $0.toHex() ?? "" }
        )
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

                Section("Item Colors") {
                    ColorPicker("Assets", selection: assetColorBinding, supportsOpacity: false)
                    ColorPicker("Liabilities", selection: liabilityColorBinding, supportsOpacity: false)
                }

                Section("Security") {
                    Toggle("Require Face ID", isOn: Bindable(viewModel.settings).requireBiometricLock)
                }

                Section("Data Management") {
                    NavigationLink("Recurring Items") {
                        RecurringItemsListView(viewModel: viewModel)
                    }

                    NavigationLink("Custom Categories") {
                        ManageCategoriesView(viewModel: viewModel)
                    }

                    NavigationLink("Milestones") {
                        MilestonesListView(viewModel: viewModel)
                    }
                }

                Section("Export") {
                    ForEach(viewModel.years, id: \.self) { year in
                        let csvData = viewModel.generateCSV(for: year)
                        ShareLink(
                            "Export \(year) CSV",
                            item: csvData,
                            preview: SharePreview("Net Worth \(year).csv")
                        )
                    }

                    ForEach(viewModel.years, id: \.self) { year in
                        if let pdfURL = viewModel.generatePDFURL(for: year) {
                            ShareLink(
                                "Export \(year) PDF Report",
                                item: pdfURL,
                                preview: SharePreview("Net Worth \(year).pdf")
                            )
                        }
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Recurring Items List

struct RecurringItemsListView: View {
    var viewModel: NetWorthViewModel
    @State private var showingAddSheet = false
    @Environment(\.assetColor) private var assetColor
    @Environment(\.liabilityColor) private var liabilityColor

    var body: some View {
        List {
            ForEach(viewModel.recurringItems) { item in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(item.name)
                            .font(.headline)
                        Spacer()
                        Text(item.amount, format: .currency(code: viewModel.currencyCode).precision(.fractionLength(0)))
                            .bold()
                            .foregroundStyle(item.itemType == "asset" ? assetColor : liabilityColor)
                    }

                    HStack {
                        Text(item.category)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("•")
                            .foregroundStyle(.secondary)
                        Text(item.frequency.capitalized)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("•")
                            .foregroundStyle(.secondary)
                        Text(item.itemType.capitalized)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .onDelete { indexSet in
                for index in indexSet {
                    viewModel.deleteRecurringItem(viewModel.recurringItems[index])
                }
            }
        }
        .navigationTitle("Recurring Items")
        .toolbar {
            Button("Add", systemImage: "plus") {
                showingAddSheet = true
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            AddRecurringItemView(viewModel: viewModel)
        }
        .overlay {
            if viewModel.recurringItems.isEmpty {
                ContentUnavailableView(
                    "No Recurring Items",
                    systemImage: "arrow.triangle.2.circlepath",
                    description: Text("Add recurring items to auto-populate monthly entries")
                )
            }
        }
    }
}

// MARK: - Add Recurring Item

struct AddRecurringItemView: View {
    var viewModel: NetWorthViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var amount = 0
    @State private var category = ""
    @State private var itemType: ItemType = .asset
    @State private var frequency = "monthly"

    private var categories: [String] {
        viewModel.allCategoryNames(for: itemType)
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Name", text: $name)

                TextField("Amount", value: $amount, format: .number)
                    .keyboardType(.numberPad)

                Picker("Type", selection: $itemType) {
                    Text("Asset").tag(ItemType.asset)
                    Text("Liability").tag(ItemType.liability)
                }

                Picker("Category", selection: $category) {
                    Text("Select").tag("")
                    ForEach(categories, id: \.self) { cat in
                        Text(cat).tag(cat)
                    }
                }

                Picker("Frequency", selection: $frequency) {
                    Text("Monthly").tag("monthly")
                    Text("Quarterly").tag("quarterly")
                    Text("Annually").tag("annually")
                }
            }
            .navigationTitle("Add Recurring Item")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let item = RecurringItem(
                            name: name,
                            amount: amount,
                            category: category,
                            itemType: itemType.rawValue,
                            frequency: frequency
                        )
                        viewModel.addRecurringItem(item)
                        dismiss()
                    }
                    .disabled(name.isEmpty || amount == 0 || category.isEmpty)
                }
            }
        }
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
    var assetColor: Color = .green
    var liabilityColor: Color = .black

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
                        .foregroundStyle(assetColor)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("Total Liabilities")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(yearData.liabilities, format: .currency(code: currencyCode).precision(.fractionLength(0)))
                        .font(.title2)
                        .foregroundStyle(liabilityColor)
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
