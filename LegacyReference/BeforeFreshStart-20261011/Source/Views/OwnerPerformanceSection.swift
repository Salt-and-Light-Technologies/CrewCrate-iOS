import SwiftUI

struct OwnerPerformanceSection: View {
    let viewModel: OwnerDashboardViewModel
    var body: some View {
        Section {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("Lead recovery & sales").font(.headline)
                    Spacer()
                    Text("DEMO").font(.caption.bold()).foregroundStyle(.indigo)
                }
                Text("Example 30-day performance · all partners").font(.caption).foregroundStyle(.secondary)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 135), alignment: .leading)], alignment: .leading, spacing: 18) {
                    metric("Total leads", value: viewModel.totalLeadCount.formatted(), symbol: "person.3")
                    metric("Leads messaged", value: viewModel.totalMessagedCount.formatted(), symbol: "message")
                    metric("Sales conversions", value: viewModel.totalConvertedCount.formatted(), symbol: "checkmark.seal")
                    metric("Awaiting sales contact", value: viewModel.totalAwaitingSalesCount.formatted(), symbol: "person.badge.clock")
                }
                LabeledContent("Reported recovered revenue", value: viewModel.totalReportedRevenue.formatted(.currency(code: "USD"))).font(.subheadline)
            }.padding(.vertical, 8)
            ForEach(viewModel.performance) { metric in
                PartnerPerformanceCard(name: viewModel.partnerName(for: metric), metric: metric)
            }
        } header: {
            Text("Partner sales performance")
        } footer: {
            Text("Illustrative figures, separate from local demo activity. Counts represent unique leads; stages overlap and should not be added together. Conversions mean reported closed sales. Supporting records are simulated, not verified live evidence.")
        }
    }
    private func metric(_ title: String, value: String, symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Label(title, systemImage: symbol).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.title2.bold()).monospacedDigit()
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct PartnerPerformanceCard: View {
    let name: String
    let metric: OwnerPartnerAnalytics
    @State private var expanded: Bool
    init(name: String, metric: OwnerPartnerAnalytics) {
        self.name = name; self.metric = metric
        _expanded = State(initialValue: metric.id == UUID(uuidString: "00000000-0000-0000-0000-000000000002"))
    }
    var body: some View {
        DisclosureGroup(isExpanded: $expanded) {
            VStack(alignment: .leading, spacing: 12) {
                OwnerCountChart(title: "Total leads", value: metric.totalLeads, total: metric.totalLeads, context: "Full lead database", color: .indigo)
                OwnerCountChart(title: "Messaged", value: metric.messaged, total: metric.totalLeads, context: "Of all leads", color: .blue)
                OwnerCountChart(title: "Not yet messaged", value: metric.notMessaged, total: metric.totalLeads, context: "Of all leads", color: .orange)
                OwnerCountChart(title: "Replied", value: metric.replied, total: metric.messaged, context: "Of messaged leads", color: .cyan)
                OwnerCountChart(title: "Qualified leads", value: metric.qualified, total: metric.totalLeads, context: "Of all leads", color: .teal)
                OwnerCountChart(title: "Touched by sales team", value: metric.salesTouched, total: metric.totalLeads, context: "Of all leads", color: .purple)
                OwnerCountChart(title: "Qualified, awaiting sales contact", value: metric.qualifiedAwaitingSales, total: metric.qualified, context: "Of qualified leads", color: .orange)
                OwnerCountChart(title: "Appointments booked", value: metric.appointments, total: metric.totalLeads, context: "Of all leads", color: .mint)
                OwnerCountChart(title: "Converted to sales", value: metric.converted, total: metric.totalLeads, context: "Of all leads", color: .green)
                OwnerCountChart(title: "Overdue sales follow-ups", value: metric.overdueFollowUps, total: metric.salesTouched, context: "Of leads touched by sales", color: .red)
                OwnerCountChart(title: "Sales with supporting records", value: metric.salesWithRecords, total: metric.converted, context: "Of reported sales", color: .green)
                OwnerCountChart(title: "Sales missing supporting records", value: metric.salesMissingRecords, total: metric.converted, context: "Of reported sales", color: .orange)
                OwnerRevenueChart(revenue: metric.reportedRevenue)
            }.font(.subheadline).padding(.vertical, 12)
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                Text(name).font(.headline)
                Text("\(metric.messaged.formatted()) of \(metric.totalLeads.formatted()) leads messaged").font(.subheadline).foregroundStyle(.secondary)
                HStack(spacing: 14) {
                    Text("\(metric.converted) sales")
                    Text("\(metric.qualifiedAwaitingSales) awaiting sales contact").foregroundStyle(.orange)
                }.font(.caption.weight(.semibold))
            }.padding(.vertical, 6)
        }
    }
}
