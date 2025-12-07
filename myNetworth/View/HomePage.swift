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
                
                Background(bgColor1: .bgMain1, bgColor2: .bgMain2)
                
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
                                        
                                        YearCard(viewModel: viewModel, year: year, data: viewModel.getYearData(for: year))
                                        
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
        type == .asset ? AssetCategories.allCases.map(\.rawValue) : LiabilitieCategories.allCases.map(\.rawValue)
    }
    
    var body: some View {
        
        ZStack {
            
            Background(bgColor1: type == .asset ? .bgAsset1 : .bgLiability1, bgColor2: type == .asset ? .bgAsset2 : .bgAsset2)
            
            NavigationView {
                
                VStack{
                    
                    // Header
                    VStack(spacing: 8) {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.system(size: 60))
                            .foregroundColor(.blue.opacity(0.8))
                        
                        Text(type == .asset ? "Add Asset" : "Add Liability")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(.white)
                        
                        Text("Track your financial journey")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.7))
                        
                        Text(type == .asset ? "New Asset" : "New Liability")
                            .font(.caption)
                            .foregroundColor(.blue.opacity(0.8))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.blue.opacity(0.2))
                            .cornerRadius(8)
                    }
                    .padding(.bottom, 20)
                    
                    /* New Asset Card */
                    VStack(spacing: 20) {
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Name")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                            
                            TextField("Name", text: $name)
                                .textFieldStyle(.plain)
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.white)
                                .cornerRadius(10)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(Color(red: 0.4, green: 0.6, blue: 0.85), lineWidth: 1)
                                )
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Amount")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.white)

                            TextField("Amount", value: $amount, formatter: Formatter.zeroSymbol)
                                .keyboardType(.numberPad)
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.white)
                                .cornerRadius(10)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(Color(red: 0.4, green: 0.6, blue: 0.85), lineWidth: 1)
                                )
                            
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Department")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.white)

                            Picker("Category", selection: $selectedCategory) {
                                Text("Select category").tag("")
                                ForEach(categories, id: \.self) { category in
                                    Text(category).tag(category)
                                }
                            }
                            .pickerStyle(.menu)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.white)
                            .cornerRadius(10)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color(red: 0.4, green: 0.6, blue: 0.85), lineWidth: 1)
                            )
                        }
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.white.opacity(0.1))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                            )
                    )
                    Spacer()
                }
                .padding()
                .toolbarTitleDisplayMode(.inlineLarge)
                .navigationTitle("")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "arrowshape.turn.up.backward.circle")
                                .font(.title3)
                                .foregroundColor(.blue)
                        }
                        
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        
                        Button {
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
                        } label: {
                            Image(systemName: "square.and.arrow.down.fill")
                                .font(.title3)
                                .foregroundColor(.blue)
                        }
                        .disabled(name.isEmpty || amount == 0 || selectedCategory.isEmpty)
                        
                    }
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
                .foregroundColor(.black)
                .padding()
            
            if !data.isEmpty {
                
                Chart(data, id: \.0) { item in
                    SectorMark(
                        angle: .value("Amount", item.1),
                        innerRadius: .ratio(0.5),
                        angularInset: 2
                    )
                    .foregroundStyle(by: .value("Category", item.0))
                    
                }
                .scaledToFit()
//                .chartForegroundStyleScale([ // Define the specific colors for categories
//                    "Car": .green,
//                    "House": .red
//                ])
                
                
            }
        }
        .padding()
        .background(Color.white.opacity(0.1))
        .cornerRadius(16)
    }
}

struct Background: View {
    
    let bgColor1: Color //= Color(red: 0.05, green: 0.1, blue: 0.2)
    let bgColor2: Color //= Color(red: 0.1, green: 0.15, blue: 0.3)
    
    var body: some View {
        
        LinearGradient(
            colors: [bgColor1, bgColor2],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}


// This is a reusable number formatter
extension Formatter {
    static let zeroSymbol: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.zeroSymbol  = ""     // Show empty string instead of zero
        return formatter
    }()
}



// MARK: - Preview
struct HomePage2_Previews: PreviewProvider {
    
    static var previews: some View {
        
        HomePage()
        
    }
}

struct CategoryChartView_Previews: PreviewProvider {
    
    static var previews: some View {
        
        CategoryChartView(data: [("Car", 50), ("House", 30), ("Credit Cared", 50), ("Jewerly", 30)], title: "Test Title", color: .black)
        
    }
}


struct AddItemView_Previews: PreviewProvider {
    
    static var previews: some View {
        
        AddItemView(viewModel: NetWorthViewModel(), type: .asset, year: 2025)
        
    }
}
