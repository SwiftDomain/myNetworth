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
    
    @ObservedObject var viewModel: NetWorthViewModel

    let year: Int
    let data: YearlyData
    
    var yearAssets: [FinancialItem] {
        viewModel.assets.filter { $0.year == year }
    }
    
    var yearLiabilities: [FinancialItem] {
        viewModel.liabilities.filter { $0.year == year }
    }
    
    
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
                
                Text(data.netWorth, format: .currency(code: "USD").precision(.fractionLength(0)))
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(data.netWorth >= 0 ? .green : .red)
            }
            
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    
                    
                    
                        Text("\(yearAssets.count) Assets")
                        .font(.caption2)
                    .foregroundColor(.white)
                    
                    Text(data.assets, format: .currency(code: "USD").precision(.fractionLength(0)))
                        .font(.caption2)
                        .foregroundColor(.green)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(yearLiabilities.count) Liabilities")
                        .font(.caption2)
                    .foregroundColor(.white)
                    
                    Text(data.liabilities, format: .currency(code: "USD").precision(.fractionLength(0)))
                        .font(.caption2)
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
            
            YearSummaryView(viewModel: viewModel, year: year)
                .tabItem {
                    Label("Summary", systemImage: "chart.pie.fill")
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
    
    let years: [Int] = {
            return Array(2020...2070)
        }()
    
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
//                        Stepper(value: $newYear, in: 2000...2100) {
//                            HStack {
//                                Spacer()
//                                Text("\(newYear, format: .number.grouping(.never))"
//                                   )
//                                    .font(.system(size: 48, weight: .bold))
//                                    .foregroundColor(.blue)
//                            }
//                        }
//                        .padding()
//                        .background(Color.white.opacity(0.1))
//                        .cornerRadius(12)
                        
                        ScrollableYearPicker(newYear: $newYear)

                        
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

struct ScrollableYearPicker: View {
    
    //@State private var selectedYear = Calendar.current.component(.year, from: Date())
    @Binding var newYear: Int
    
    let years: [Int] = {
        let currentYear = Calendar.current.component(.year, from: Date())
        return Array((currentYear - 20)...(currentYear + 10))
    }()
    
    var body: some View {
        
        VStack(spacing: 24) {
            
            
            Text("\(newYear)")
                .font(.largeTitle)
                .bold()
                .foregroundColor(.blue)
            
            ScrollViewReader { proxy in
                
                ScrollView(.horizontal, showsIndicators: false) {
                    
                    HStack(spacing: 12) {
                        ForEach(years, id: \.self) { year in
                            Button {
                                withAnimation {
                                    newYear = year
                                }
                            } label: {
                                Text(String(year))
                                    .font(.headline)
                                    .foregroundColor(newYear == year ? .white : .gray)
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 12)
                                    .background(
                                        RoundedRectangle(cornerRadius: 10)
                                            .fill(newYear == year ? Color.blue : Color.clear)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 10)
                                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                            )
                                    )
                            }
                            .id(year)
                        }
                    }
                    .padding()
                }
                .onAppear {
                    proxy.scrollTo(newYear, anchor: .center)
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
                    
                    VStack(spacing: 20){
                        // Summary Cards
                        SummaryCard(
                            title: "Net Worth",
                            amount: yearData.netWorth,
                            itemType: "Networth",
                            isLarge: true
                        )
                        
                        HStack(spacing: 12) {
                            
                            SummaryCard(
                                title: "Assets",
                                amount: yearData.assets,
                                itemType: "assets",
                                isLarge: false
                            )
                            
                            
                            SummaryCard(
                                title: "Liabilities",
                                amount: yearData.liabilities,
                                itemType: "liabilities",
                                isLarge: false
                            )
                            
                        }
                    }
                    .padding()
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(16)
                    
                    
                    // Assets Breakdown
                    CategoryBreakdownTile(
                        yearData: yearData,
                        type: .asset
                    )

                    // Liabilities Breakdown
                    CategoryBreakdownTile(
                        yearData: yearData,
                        type: .liability
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
                        .chartYAxis {
                            AxisMarks(position: .leading, values: .stride(by: 500_000)) { value in
                                AxisGridLine()
                                    .foregroundStyle(.white.opacity(0.2))
                                AxisValueLabel {
                                    if let intValue = value.as(Int.self) {
                                        Text(formatNumber(intValue))
                                            .foregroundStyle(.white)
                                            .font(.caption2.weight(.light))
                                    }
                                }
                            }
                        }
                        .chartXAxis {
                            AxisMarks(position: .automatic, values: .stride(by: 20)) { value in
                                AxisValueLabel()
                                    .foregroundStyle(.white)
                            }
                        }
                    }
                    .padding()
                    .background(Color.white.opacity(0.05))
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
    let itemType: String
    var isLarge: Bool = false
    
    var body: some View {
        
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(isLarge ? .title : .callout)
                .foregroundColor(.white.opacity(1))
            
            Text(amount, format: .currency(code: "USD").precision(.fractionLength(0)))
                .font(isLarge ? .title : .subheadline)
                .fontWeight(.bold)
                .foregroundColor(itemType=="assets" ? .green: itemType == "liabilities" ? .red : amount > 0 ? .green : .red)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
       
        Group{
            
            YearCard(viewModel: NetWorthViewModel(), year: 2025, data: YearlyData(year: 2025, assets: 2022, liabilities: 22332, netWorth: 23321,assetCategortyTotal: [.furniture:2], liabilityCategortyTotal:  [.other:2]))
                .background(Color.black.edgesIgnoringSafeArea(.all))
            
            
        }
        
    }
}

struct YearSummaryView_Previews: PreviewProvider {
    
    var netW: NetWorthViewModel = NetWorthViewModel()
    
    static var previews: some View {
       
        Group{
            
            YearSummaryView(viewModel: NetWorthViewModel(), year: 2025)
            
        }
        
    }
}


