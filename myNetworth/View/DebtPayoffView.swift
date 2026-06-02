//
//  DebtPayoffView.swift
//  myNetworth
//

import SwiftUI
import Charts

// MARK: - Debt Payoff View

struct DebtPayoffView: View {
    var viewModel: NetWorthViewModel

    @State private var monthlyPayment = 0
    @State private var annualInterestRate = 0.0

    private var totalDebt: Int {
        let currentYear = Calendar.current.component(.year, from: .now)
        return viewModel.getYearData(for: currentYear).liabilities
    }

    private var payoffData: PayoffResult {
        calculatePayoff(
            principal: Double(totalDebt),
            annualRate: annualInterestRate / 100,
            monthlyPayment: Double(monthlyPayment)
        )
    }

    var body: some View {
        ZStack {
            Background(bgColor1: Theme.mainGradient1, bgColor2: Theme.mainGradient2)

            ScrollView {
                VStack(spacing: 20) {
                    // Current Debt Summary
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Current Total Liabilities")
                            .font(.caption)
                            .foregroundStyle(Theme.textSecondary)
                        Text(totalDebt, format: .currency(code: viewModel.currencyCode).precision(.fractionLength(0)))
                            .font(.title)
                            .bold()
                            .foregroundStyle(Theme.negativeAmount)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Theme.cardBackground)
                    .clipShape(.rect(cornerRadius: 12))

                    // Input Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Payoff Calculator")
                            .font(.headline)
                            .foregroundStyle(Theme.textPrimary)

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Monthly Payment")
                                .font(.caption)
                                .foregroundStyle(Theme.textSecondary)
                            TextField("Monthly Payment", value: $monthlyPayment, format: .number)
                                .keyboardType(.numberPad)
                                .textFieldStyle(.roundedBorder)
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Annual Interest Rate (%)")
                                .font(.caption)
                                .foregroundStyle(Theme.textSecondary)
                            TextField("Interest Rate", value: $annualInterestRate, format: .number.precision(.fractionLength(1)))
                                .keyboardType(.decimalPad)
                                .textFieldStyle(.roundedBorder)
                        }
                    }
                    .padding()
                    .background(Theme.cardBackground)
                    .clipShape(.rect(cornerRadius: 12))

                    // Results
                    if monthlyPayment > 0 && totalDebt > 0 {
                        if payoffData.isPossible {
                            // Payoff Summary
                            PayoffSummaryCard(result: payoffData, currencyCode: viewModel.currencyCode)

                            // Balance Chart
                            PayoffChartView(
                                balanceOverTime: payoffData.balanceOverTime,
                                currencyCode: viewModel.currencyCode
                            )
                        } else {
                            VStack(spacing: 12) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.largeTitle)
                                    .foregroundStyle(.orange)
                                Text("Payment too low")
                                    .font(.headline)
                                    .foregroundStyle(Theme.textPrimary)
                                Text("Your monthly payment doesn't cover the interest. Increase your payment to make progress on the debt.")
                                    .font(.subheadline)
                                    .foregroundStyle(Theme.textSecondary)
                                    .multilineTextAlignment(.center)
                            }
                            .padding()
                            .background(Theme.cardBackground)
                            .clipShape(.rect(cornerRadius: 12))
                        }
                    }
                }
                .padding()
            }
        }
        .navigationTitle("Debt Payoff")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Payoff Calculation

struct PayoffResult {
    let monthsToPayoff: Int
    let totalInterest: Double
    let totalPaid: Double
    let projectedDate: Date
    let isPossible: Bool
    let balanceOverTime: [(month: Int, balance: Double)]
}

private func calculatePayoff(principal: Double, annualRate: Double, monthlyPayment: Double) -> PayoffResult {
    guard principal > 0, monthlyPayment > 0 else {
        return PayoffResult(
            monthsToPayoff: 0, totalInterest: 0, totalPaid: 0,
            projectedDate: .now, isPossible: false, balanceOverTime: []
        )
    }

    let monthlyRate = annualRate / 12
    var balance = principal
    var totalInterest = 0.0
    var months = 0
    var balanceOverTime: [(month: Int, balance: Double)] = [(0, balance)]

    // Check if payment covers at least the interest
    let firstMonthInterest = balance * monthlyRate
    if monthlyPayment <= firstMonthInterest && annualRate > 0 {
        return PayoffResult(
            monthsToPayoff: 0, totalInterest: 0, totalPaid: 0,
            projectedDate: .now, isPossible: false, balanceOverTime: []
        )
    }

    let maxMonths = 600 // 50 years cap
    while balance > 0 && months < maxMonths {
        let interest = balance * monthlyRate
        totalInterest += interest
        balance = balance + interest - monthlyPayment
        months += 1

        if balance < 0 { balance = 0 }
        balanceOverTime.append((months, balance))
    }

    let projectedDate = Calendar.current.date(byAdding: .month, value: months, to: .now) ?? .now

    return PayoffResult(
        monthsToPayoff: months,
        totalInterest: totalInterest,
        totalPaid: totalInterest + principal,
        projectedDate: projectedDate,
        isPossible: months < maxMonths,
        balanceOverTime: balanceOverTime
    )
}

// MARK: - Payoff Summary Card

struct PayoffSummaryCard: View {
    let result: PayoffResult
    var currencyCode: String = "USD"

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Payoff Summary")
                .font(.headline)
                .foregroundStyle(Theme.textPrimary)

            HStack {
                PayoffStat(
                    label: "Months",
                    value: "\(result.monthsToPayoff)",
                    icon: "calendar"
                )

                Spacer()

                PayoffStat(
                    label: "Years",
                    value: "\(result.monthsToPayoff / 12)y \(result.monthsToPayoff % 12)m",
                    icon: "clock"
                )
            }

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Total Interest")
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                    Text(Int(result.totalInterest), format: .currency(code: currencyCode).precision(.fractionLength(0)))
                        .font(.subheadline)
                        .bold()
                        .foregroundStyle(Theme.negativeAmount)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("Payoff Date")
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                    Text(result.projectedDate, format: .dateTime.year().month())
                        .font(.subheadline)
                        .bold()
                        .foregroundStyle(Theme.positiveAmount)
                }
            }
        }
        .padding()
        .background(Theme.cardBackground)
        .clipShape(.rect(cornerRadius: 12))
    }
}

// MARK: - Payoff Stat

struct PayoffStat: View {
    let label: String
    let value: String
    let icon: String

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .foregroundStyle(.blue)
            Text(value)
                .font(.title3)
                .bold()
                .foregroundStyle(Theme.textPrimary)
            Text(label)
                .font(.caption)
                .foregroundStyle(Theme.textSecondary)
        }
    }
}

// MARK: - Payoff Chart

struct PayoffChartView: View {
    let balanceOverTime: [(month: Int, balance: Double)]
    var currencyCode: String = "USD"

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Balance Over Time")
                .font(.headline)
                .foregroundStyle(Theme.textPrimary)

            Chart(balanceOverTime, id: \.month) { dataPoint in
                AreaMark(
                    x: .value("Month", dataPoint.month),
                    y: .value("Balance", dataPoint.balance)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.red.opacity(0.3), Color.green.opacity(0.1)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

                LineMark(
                    x: .value("Month", dataPoint.month),
                    y: .value("Balance", dataPoint.balance)
                )
                .foregroundStyle(.red)
                .lineStyle(StrokeStyle(lineWidth: 2))
            }
            .frame(height: 250)
            .chartXAxisLabel("Months")
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisGridLine()
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
                AxisMarks { _ in
                    AxisGridLine()
                    AxisValueLabel()
                        .foregroundStyle(.white)
                }
            }
        }
        .padding()
        .background(Theme.cardBackground)
        .clipShape(.rect(cornerRadius: 16))
    }
}
