import SwiftUI
import Charts

/// Snapshot comparisons only; no historical series is inferred from the demo totals.
struct OwnerCountChart: View {
    let title: String
    let value: Int
    let total: Int
    let context: String
    let color: Color
    private var scale: Int { max(1, total, value) }
    private var rate: Double { total > 0 ? Double(value) / Double(total) : 0 }
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(title).font(.subheadline.weight(.semibold))
                Spacer(minLength: 10)
                Text(value.formatted()).font(.headline).monospacedDigit()
            }
            Chart {
                BarMark(xStart: .value("Start", 0), xEnd: .value("Leads", value), y: .value("Metric", title), height: .fixed(18))
                    .foregroundStyle(color)
                if total > value {
                    BarMark(xStart: .value("Start", value), xEnd: .value("Remaining", total), y: .value("Metric", title), height: .fixed(18))
                        .foregroundStyle(Color.secondary.opacity(0.15))
                }
            }
            .chartXScale(domain: 0...scale)
            .chartYAxis(.hidden)
            .chartXAxis {
                AxisMarks(values: [0, scale / 2, scale]) {
                    AxisValueLabel().font(.caption2)
                }
            }
            .frame(height: 48)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(title)
            .accessibilityValue("\(value) of \(total). \(context).")
            HStack(alignment: .top) {
                Text(context).font(.caption).foregroundStyle(.secondary)
                Spacer()
                if total > 0 { Text("\(rate.formatted(.percent.precision(.fractionLength(1)))) · \(value.formatted()) / \(total.formatted())").font(.caption).foregroundStyle(.secondary).monospacedDigit() }
                else { Text("No records").font(.caption).foregroundStyle(.secondary) }
            }
        }.padding(.vertical, 10)
    }
}

struct OwnerRevenueChart: View {
    let revenue: Decimal
    private var amount: Double { NSDecimalNumber(decimal: revenue).doubleValue }
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Reported recovered revenue").font(.subheadline.weight(.semibold))
            Text(revenue.formatted(.currency(code: "USD"))).font(.title3.bold()).monospacedDigit()
            Chart {
                BarMark(x: .value("Reported revenue", amount), y: .value("Period", "Example period"), height: .fixed(20))
                    .foregroundStyle(.indigo)
            }
            .chartXScale(domain: 0...max(1, amount))
            .chartYAxis(.hidden)
            .chartXAxis {
                AxisMarks(values: [0, max(1, amount) / 2, max(1, amount)]) { value in
                    if let dollars = value.as(Double.self) {
                        AxisValueLabel { Text(dollars.formatted(.currency(code: "USD").precision(.fractionLength(0)))).font(.caption2) }
                    }
                }
            }
            .frame(height: 52)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Reported recovered revenue for the example period")
            .accessibilityValue(revenue.formatted(.currency(code: "USD")))
            Text("Demo period total in USD; no revenue trend or target is implied.").font(.caption).foregroundStyle(.secondary)
        }.padding(.vertical, 10)
    }
}
