import Foundation

/// Fictional analytics only; never writes campaigns or contacts to a workspace.
actor DemoCampaignAnalyticsRepository: CampaignAnalyticsRepository {
    private let rows: [CampaignSnapshot]
    init() {
        let partnerID = UUID()
        let examples: [(String, CampaignStatus, Int, DemoCampaignMetrics)] = [
            ("Dormant lead recovery", .readyToConnect, 1200, .init(sent: 960, replies: 288, touches: 210, interested: 140, appointments: 84, handoffs: 56, conversions: 42, revenue: 25200)),
            ("Unclosed opportunities", .paused, 600, .init(sent: 420, replies: 126, touches: 98, interested: 72, appointments: 35, handoffs: 28, conversions: 21, revenue: 16800)),
            ("Customer win-back", .archived, 400, .init(sent: 400, replies: 132, touches: 110, interested: 90, appointments: 48, handoffs: 32, conversions: 36, revenue: 14400)),
            ("New recovery pilot", .draft, 250, .init(sent: 0, replies: 0, touches: 0, interested: 0, appointments: 0, handoffs: 0, conversions: 0, revenue: 0))
        ]
        rows = examples.enumerated().map { index, row in
            var config = CampaignConfig(); config.name = row.0; config.leadIDs = (0..<row.2).map { _ in UUID() }
            var campaign = CampaignRecord(id: UUID(), partnerID: partnerID, status: row.1, config: config)
            campaign.updatedAt = Date(timeIntervalSince1970: 1_790_000_000 - Double(index * 86400))
            return CampaignSnapshot(campaign: campaign, partnerName: "Demo partner", conversations: [], demoMetrics: row.3)
        }
    }
    func snapshots() async throws -> [CampaignSnapshot] { rows }
}
