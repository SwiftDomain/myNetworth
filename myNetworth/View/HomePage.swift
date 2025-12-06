//
//  ContentView.swift
//  myNetworth
//
//  Created by BeastMode on 12/5/25.
//
import SwiftUI
import Charts

// MARK: - Main View (Year Selection)
struct HomePage: View {
    @StateObject private var viewModel = NetWorthViewModel() 
    @State private var showingAddYear = false
    @State private var newYear = Calendar.current.component(.year, from: Date())
    
    var body: some View {
        
        NavigationView {
            ZStack {
                LinearGradient(
                    colors: [Color(red: 0.05, green: 0.1, blue: 0.2), Color(red: 0.1, green: 0.15, blue: 0.3)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Header
                        VStack(spacing: 8) {
                            Image(systemName: "chart.line.uptrend.xyaxis")
                                .font(.system(size: 60))
                                .foregroundColor(.blue.opacity(0.8))
                            
                            Text("Net Worth Tracker")
                                .font(.system(size: 32, weight: .bold))
                                .foregroundColor(.white)
                            
                            Text("Track your financial journey year by year")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.7))
                            
                            Text("Family Friendly")
                                .font(.caption)
                                .foregroundColor(.blue.opacity(0.8))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.blue.opacity(0.2))
                                .cornerRadius(8)
                        }
                        .padding(.top, 40)
                        .padding(.bottom, 20)
                        
                        // Years Grid
                        if viewModel.years.isEmpty {
                            EmptyStateView(
                                icon: "calendar",
                                message: "No years added yet",
                                subMessage: "Add a year to start tracking your net worth"
                            )
                            .padding(.top, 60)
                        } else {
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                                ForEach(viewModel.years, id: \.self) { year in
                                    NavigationLink(destination: YearDetailView(viewModel: viewModel, year: year)) {
                                        YearCard(year: year, data: viewModel.getYearData(for: year))
                                    }
                                    .contextMenu {
                                        Button(role: .destructive) {
                                            viewModel.deleteYear(year)
                                        } label: {
                                            Label("Delete Year", systemImage: "trash")
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingAddYear = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundColor(.blue)
                    }
                }
                
                ToolbarItem(placement: .navigationBarLeading) {
                    HStack(spacing: 12) {
                        if !viewModel.years.isEmpty {
                            NavigationLink(destination: OverallAnalysisView(viewModel: viewModel)) {
                                Image(systemName: "chart.bar.fill")
                                    .font(.title3)
                                    .foregroundColor(.blue)
                            }
                        }
                        
                        Button {
                            viewModel.refreshData()
                        } label: {
                            Image(systemName: "arrow.clockwise")
                                .font(.title3)
                                .foregroundColor(.blue)
                        }
                    }
                }
            }
            .sheet(isPresented: $showingAddYear) {
                AddYearView(viewModel: viewModel, newYear: $newYear)
            }
            .onAppear {
                // Refresh data when view appears to sync with other users
                viewModel.refreshData()
            }
        }
    }
}


struct EmptyStateView: View {
    let icon: String
    let message: String
    let subMessage: String
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 60))
                .foregroundColor(.white.opacity(0.3))
            
            Text(message)
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.white)
            
            Text(subMessage)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
        }
    }
}


// MARK: - Add Item View
struct AddItemView: View {
    
    @ObservedObject var viewModel: NetWorthViewModel
    @Environment(\.dismiss) var dismiss
    
    @State private var name = ""
    @State private var amount = 0
    @State private var selectedCategory = ""
    
    let type: ItemType
    let year: Int
    
    var categories: [String] {
        type == .asset ? viewModel.assetCategories : viewModel.liabilityCategories
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Details") {
                    TextField("Name", text: $name)
                    TextField("Amount", value: $amount, formatter: NumberFormatter())
                        .keyboardType(.numberPad)
                    
                    Picker("Category", selection: $selectedCategory) {
                        Text("Select category").tag("")
                        ForEach(categories, id: \.self) { category in
                            Text(category).tag(category)
                        }
                    }
                }
            }
            .navigationTitle("Add \(type == .asset ? "Asset" : "Liability")")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        guard !name.isEmpty, amount > 0, !selectedCategory.isEmpty else { return }
                        
                        let item = FinancialItem(
                            name: name,
                            amount: amount,
                            year: year,
                            category: selectedCategory
                        )
                        
                        if type == .asset {
                            viewModel.addAsset(item)
                        } else {
                            viewModel.addLiability(item)
                        }
                        
                        dismiss()
                    }
                    .disabled(name.isEmpty || amount == 0 || selectedCategory.isEmpty)
                }
            }
        }
    }
}

struct CategoryChartView: View {
    let data: [(String, Int)]
    let title: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .foregroundColor(.white)
            
            if !data.isEmpty {
                Chart(data, id: \.0) { item in
                    SectorMark(
                        angle: .value("Amount", item.1),
                        innerRadius: .ratio(0.5),
                        angularInset: 2
                    )
                    .foregroundStyle(by: .value("Category", item.0))
                }
                .frame(height: 250)
            }
        }
        .padding()
        .background(Color.white.opacity(0.1))
        .cornerRadius(16)
    }
}

// MARK: - Preview
#Preview {
    HomePage()
}
