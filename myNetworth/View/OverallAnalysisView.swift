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
                colors: [Color(red: 0.05, green: 0.15, blue: 0.35), Color(red: 0.1, green: 0.25, blue: 0.45)],
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
                    } else {
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
                                            Text(data.assets, format: .currency(code: "USD"))
                                                .font(.subheadline)
                                                .foregroundColor(.green)
                                        }
                                        
                                        Spacer()
                                        
                                        VStack(alignment: .trailing) {
                                            Text("Liabilities")
                                                .font(.caption)
                                                .foregroundColor(.white.opacity(0.7))
                                            Text(data.liabilities, format: .currency(code: "USD"))
                                                .font(.subheadline)
                                                .foregroundColor(.red)
                                        }
                                        
                                        Spacer()
                                        
                                        VStack(alignment: .trailing) {
                                            Text("Net Worth")
                                                .font(.caption)
                                                .foregroundColor(.white.opacity(0.7))
                                            Text(data.netWorth, format: .currency(code: "USD"))
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
        .navigationBarTitleDisplayMode(.large)
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
            .chartYAxis {
                AxisMarks(position: .leading)
            }
        }
        .padding()
        .background(Color.white.opacity(0.1))
        .cornerRadius(16)
    }
}


struct ComparisonChartView: View {
    let data: [YearlyData]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Assets vs Liabilities")
                .font(.headline)
                .foregroundColor(.white)
            
            Chart(data) { item in
                BarMark(
                    x: .value("Year", item.year),
                    y: .value("Assets", item.assets)
                )
                .foregroundStyle(.green)
                
                BarMark(
                    x: .value("Year", item.year),
                    y: .value("Liabilities", item.liabilities)
                )
                .foregroundStyle(.red)
            }
            .frame(height: 250)
        }
        .padding()
        .background(Color.white.opacity(0.1))
        .cornerRadius(16)
    }
}

#Preview{
    OverallAnalysisView(viewModel: NetWorthViewModel())
}
