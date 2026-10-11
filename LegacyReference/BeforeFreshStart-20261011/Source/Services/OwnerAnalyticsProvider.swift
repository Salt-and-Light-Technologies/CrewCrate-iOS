import Foundation

nonisolated protocol OwnerAnalyticsProvider: Sendable {
    func performance() async throws -> [OwnerPartnerAnalytics]
}
nonisolated struct DemoOwnerAnalyticsProvider: OwnerAnalyticsProvider {
    func performance() async throws -> [OwnerPartnerAnalytics] {
        [
            OwnerPartnerAnalytics(id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!, totalLeads: 1200, messaged: 840, replied: 252, qualified: 168, salesTouched: 126, qualifiedAwaitingSales: 42, appointments: 84, converted: 42, overdueFollowUps: 24, salesWithRecords: 34, reportedRevenue: 50400),
            OwnerPartnerAnalytics(id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!, totalLeads: 1000, messaged: 620, replied: 186, qualified: 124, salesTouched: 100, qualifiedAwaitingSales: 24, appointments: 60, converted: 25, overdueFollowUps: 18, salesWithRecords: 20, reportedRevenue: 87500),
            OwnerPartnerAnalytics(id: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!, totalLeads: 800, messaged: 400, replied: 100, qualified: 70, salesTouched: 50, qualifiedAwaitingSales: 20, appointments: 35, converted: 10, overdueFollowUps: 12, salesWithRecords: 7, reportedRevenue: 30000)
        ]
    }
}
