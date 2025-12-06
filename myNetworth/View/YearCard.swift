//
//  YearCard.swift
//  myNetworth
//
//  Created by BeastMode on 12/5/25.
//
import SwiftUI
import Charts

// MARK: - Year Card
struct YearCard: View {
    let year: Int
    let data: YearlyData
    
    var body: some View {
        
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "calendar")
                    .font(.title2)
                    .foregroundColor(.blue.opacity(0.8))
                
                Spacer()
                
                Text("\(year, format: .number.grouping(.never))")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.blue)
            }
            
            Divider()
                .background(Color.white.opacity(0.3))
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Net Worth")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                    Spacer()
                }
                
                Text(data.netWorth, format: .currency(code: "USD"))
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(data.netWorth >= 0 ? .green : .red)
            }
            
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Assets")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.6))
                    Text(data.assets, format: .currency(code: "USD"))
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.green)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Liabilities")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.6))
                    Text(data.liabilities, format: .currency(code: "USD"))
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.red)
                }
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
    }
}


// MARK: - Year Detail View (with TabView)
struct YearDetailView: View {
    @ObservedObject var viewModel: NetWorthViewModel
    @State private var selectedTab = 0
    @State private var showingAddSheet = false
   
    let year: Int
    
    var body: some View {
        
        TabView(selection: $selectedTab) {
            AllItemsView(viewModel: viewModel, year: year)
                .tabItem {
                    Label("All Items", systemImage: "list.bullet")
                }
                .tag(0)
            
            AssetsView(viewModel: viewModel, year: year)
                .tabItem {
                    Label("Assets", systemImage: "dollarsign.circle.fill")
                }
                .tag(1)
            
            LiabilitiesView(viewModel: viewModel, year: year)
                .tabItem {
                    Label("Liabilities", systemImage: "creditcard.fill")
                }
                .tag(2)
            
            YearSummaryView(viewModel: viewModel, year: year)
                .tabItem {
                    Label("Summary", systemImage: "chart.pie.fill")
                }
                .tag(3)
        }
        .navigationTitle("\(year, format: .number.grouping(.never))")
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            viewModel.refreshData()
        }
        .toolbar{
            ToolbarItem(placement: .navigationBarTrailing) {
                if selectedTab == 1 || selectedTab == 2 {
                  
                    Button {
                        showingAddSheet = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundColor(.blue)
                    }
                }
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            AddItemView(viewModel: viewModel, type: selectedTab == 1 ? .asset : .liability, year: year)
        }
    }
}

// MARK: - Add Year View
struct AddYearView: View {
    @ObservedObject var viewModel: NetWorthViewModel
    @Binding var newYear: Int
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(red: 0.05, green: 0.1, blue: 0.2)
                    .ignoresSafeArea()
                
                VStack(spacing: 30) {
                    Image(systemName: "calendar.badge.plus")
                        .font(.system(size: 80))
                        .foregroundColor(.blue.opacity(0.8))
                    
                    Text("Add New Year")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    VStack(spacing: 16) {
                        Stepper(value: $newYear, in: 2000...2100) {
                            HStack {
                                Spacer()
                                Text("\(newYear, format: .number.grouping(.never))"
                                   )
                                    .font(.system(size: 48, weight: .bold))
                                    .foregroundColor(.blue)
                            }
                        }
                        .padding()
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(12)
                        
                        if viewModel.years.contains(newYear) {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                                Text("This year already exists")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                            }
                        }
                    }
                    .padding(.horizontal)
                    
                    Spacer()
                    
                    Button {
                        viewModel.addYear(newYear)
                        dismiss()
                    } label: {
                        Text("Add Year")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                LinearGradient(
                                    colors: [.blue, .blue.opacity(0.8)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(12)
                    }
                    .disabled(viewModel.years.contains(newYear))
                    .opacity(viewModel.years.contains(newYear) ? 0.5 : 1)
                    .padding(.horizontal)
                }
                .padding()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.blue)
                }
            }
        }
    }
}

// MARK: - Year Summary View
struct YearSummaryView: View {
    @ObservedObject var viewModel: NetWorthViewModel
    let year: Int
    
    var yearData: YearlyData {
        viewModel.getYearData(for: year)
    }
    
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.05, green: 0.15, blue: 0.35), Color(red: 0.1, green: 0.25, blue: 0.45)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 20) {
                    // Summary Cards
                    HStack(spacing: 12) {
                        SummaryCard(
                            title: "Assets",
                            amount: yearData.assets,
                            color: .green
                        )
                        SummaryCard(
                            title: "Liabilities",
                            amount: yearData.liabilities,
                            color: .red
                        )
                    }
                    
                    SummaryCard(
                        title: "Net Worth",
                        amount: yearData.netWorth,
                        color: .blue,
                        isLarge: true
                    )
                    
                    // Assets vs Liabilities Comparison
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Financial Overview")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        Chart {
                            BarMark(
                                x: .value("Type", "Assets"),
                                y: .value("Amount", yearData.assets)
                            )
                            .foregroundStyle(.green)
                            
                            BarMark(
                                x: .value("Type", "Liabilities"),
                                y: .value("Amount", yearData.liabilities)
                            )
                            .foregroundStyle(.red)
                        }
                        .frame(height: 250)
                    }
                    .padding()
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(16)
                }
                .padding()
            }
        }
    }
}

struct SummaryCard: View {
    let title: String
    let amount: Int
    let color: Color
    var isLarge: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(isLarge ? .headline : .subheadline)
                .foregroundColor(.white.opacity(0.8))
            
            Text(amount, format: .currency(code: "USD"))
                .font(isLarge ? .system(size: 32, weight: .bold) : .title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(
            LinearGradient(
                colors: [color.opacity(0.6), color.opacity(0.8)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(16)
    }
}

// MARK: - Preview

struct AddYearView_Previews: PreviewProvider {
    
    static var previews: some View {
        
        let netW: NetWorthViewModel = NetWorthViewModel()
        AddYearView(viewModel: netW, newYear: .constant(2024))
        
    }
}

struct YearDetailView_Previews: PreviewProvider {
    
    static var previews: some View {
        
        let netW: NetWorthViewModel = NetWorthViewModel()

        YearDetailView(viewModel: netW, year: 2025)
        
    }
}

struct YearCard_Previews: PreviewProvider {
    
    static var previews: some View {
        
        YearCard(year: 2025, data: YearlyData(year: 2025, assets: 20320, liabilities: 23009, netWorth: 123344))
            .background(Color.black.edgesIgnoringSafeArea(.all))
        
    }
}
