//
//  OverallAnalysisView.swift
//  myNetworth
//
//  Created by BeastMode on 12/5/25.
//

import SwiftUI
import Charts

// MARK: - Overall Analysis View
struct OverallAnalysisView: View {
    @ObservedObject var viewModel: NetWorthViewModel
    
    var body: some View {
        ZStack {
            
            LinearGradient(
                colors: [.bgMain1, .bgMain2],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            ScrollView {
                
                VStack(spacing: 20) {
                    
                    if viewModel.yearlyData.isEmpty {
                        EmptyStateView(
                            icon: "chart.bar",
                            message: "No data to analyze",
                            subMessage: "Add assets and liabilities to see insights"
                        )
                        .padding(.top, 100)
                    }
                    else {
                        // Net Worth Trend Chart
                        NetWorthChartView(data: viewModel.yearlyData)
                        
                        // Assets vs Liabilities Chart
                        ComparisonChartView(data: viewModel.yearlyData)
                        
                        // Year-by-Year Breakdown
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Year-by-Year Breakdown")
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            ForEach(viewModel.yearlyData.reversed()) { data in
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("\(data.year)")
                                        .font(.title3)
                                        .fontWeight(.bold)
                                        .foregroundColor(.white)
                                    
                                    HStack {
                                        VStack(alignment: .leading) {
                                            Text("Assets")
                                                .font(.caption)
                                                .foregroundColor(.white.opacity(0.7))
                                            Text(data.assets, format: .currency(code: "USD").precision(.fractionLength(0)))
                                                .font(.subheadline)
                                                .foregroundColor(.green)
                                        }
                                        
                                        Spacer()
                                        
                                        VStack(alignment: .trailing) {
                                            Text("Liabilities")
                                                .font(.caption)
                                                .foregroundColor(.white.opacity(0.7))
                                            Text(data.liabilities, format: .currency(code: "USD").precision(.fractionLength(0)))
                                                .font(.subheadline)
                                                .foregroundColor(.red)
                                        }
                                        
                                        Spacer()
                                        
                                        VStack(alignment: .trailing) {
                                            Text("Net Worth")
                                                .font(.caption)
                                                .foregroundColor(.white.opacity(0.7))
                                            Text(data.netWorth, format: .currency(code: "USD").precision(.fractionLength(0)))
                                                .font(.subheadline)
                                                .fontWeight(.bold)
                                                .foregroundColor(.blue)
                                        }
                                    }
                                }
                                .padding()
                                .background(Color.white.opacity(0.1))
                                .cornerRadius(12)
                            }
                        }
                        .padding()
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(16)
                    }
                }
                .padding()
            }
        }
        .navigationTitle("Overall Analysis")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct NetWorthChartView: View {
    let data: [YearlyData]
    
    var body: some View {
        
        VStack(alignment: .leading, spacing: 12) {
            
            Text("Net Worth Over Time")
                .font(.headline)
                .foregroundColor(.white)
            
            Chart(data) { item in
                LineMark(
                    x: .value("Year", item.year),
                    y: .value("Net Worth", item.netWorth)
                )
                .foregroundStyle(.blue)
                .lineStyle(StrokeStyle(lineWidth: 3))
                
                
                PointMark(
                    x: .value("Year", item.year),
                    y: .value("Net Worth", item.netWorth)
                )
                .foregroundStyle(.blue)
            }
            .frame(height: 250)
            .chartXAxis {
                AxisMarks(position: .automatic) { value in
                    AxisGridLine()
                    AxisValueLabel()
                        .foregroundStyle(.white) // Makes X-axis labels white
                }
            }
            .chartYAxis() {
                AxisMarks(position: .leading) { value in
                    AxisGridLine()
                    AxisValueLabel()
                        .foregroundStyle(.white) // Makes Y-axis labels white too
                }
            }
            .chartXScale(domain: 2000...2100)

        }
        .padding()
        .background(Color.white.opacity(0.1))
        .cornerRadius(16)
    }
}


struct ComparisonChartView: View {
    let data: [YearlyData]
    
    var chartData: [(year: Int, category: String, value: Int)] {
        data.flatMap { data in
            [
                (year: data.year, category: "Assets", value: data.assets),
                (year: data.year, category: "Liabilities", value: data.liabilities)
            ]
        }
    }

    let currentYear =  Calendar.current.component(.year, from: Date.now)
    
    var body: some View {
        
        VStack(alignment: .leading, spacing: 12) {
            
//            Chart(chartData, id: \.year) { dataPoint in
//                        BarMark(
//                            x: .value("Month", dataPoint.category), // X-axis by month
//                            y: .value("Sales", dataPoint.value)   // Y-axis by sales value
//                        )
//                        .foregroundStyle(by: .value("Type", dataPoint.type)) // Group by type (Actual/Forecast)
//                        .position(by: .value("Type", dataPoint.type)) // Crucial for side-by-side
//                    }
//                    .chartXAxis { AxisMarks(values: .automatic) } // Standard X-axis
//                    .padding()
                
        
            Text("Assets vs Liabilities")
                .font(.headline)
                .foregroundColor(.white)
            
           Chart(chartData, id: \.year) { item in
               
                BarMark(
                    x: .value("Year", item.year),
                    y: .value("Amount", item.value)
                )
                .foregroundStyle(by: .value("category", item.category)) // Group by type (Actual/Forecast)
                .position(by: .value("category", item.category)) // Crucial for side-by-side
                
            }
            .frame(height: 250)
            //.chartYScale(domain: 0...5_000_000)
            .chartXScale(domain: currentYear-20...currentYear+20)
            .chartXScale(domain: 2020...2028)

            .chartYAxis {
                AxisMarks(position: .leading, values: .stride(by: 1_000_000)) { value in
                    AxisGridLine()
                        .foregroundStyle(.white.opacity(0.2))
                    AxisValueLabel {
                        if let intValue = value.as(Int.self) {
                            Text(formatNumber(intValue))
                                .foregroundStyle(.white)
                                .font(.caption)
                        }
                    }
                }
            }
            .chartXAxis {
                AxisMarks(position: .automatic, values: .stride(by: 10)) { value in
                    AxisValueLabel()
                        .foregroundStyle(.white)
                }
            }
            .chartLegend(position: .bottom) {
                HStack(spacing: 16) {
                    ForEach(["Assets", "Liabilities"], id: \.self) { category in
                        HStack(spacing: 6) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(category == "Assets" ? Color.green : Color.red)
                                .frame(width: 8, height: 8)
                            
                            Text(category)
                                .foregroundColor(.white)
                                .font(.footnote)
                        }
                    }
                }
                .padding(.vertical, 8)
            }
            .chartForegroundStyleScale([ // Define the specific colors for categories
                "Assets": .green,
                "Liabilities": .red
            ])
        }
        .padding()
        .background(Color.white.opacity(0.1))
        .cornerRadius(16)
    }
}

func formatNumber(_ number: Int) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    formatter.groupingSeparator = ","
    return formatter.string(from: NSNumber(value: number)) ?? "\(number)"
}

#Preview{
    OverallAnalysisView(viewModel: NetWorthViewModel())
}

struct HomePage_Previews: PreviewProvider {
    
    static var previews: some View {
        
        HomePage()
        
    }
}

