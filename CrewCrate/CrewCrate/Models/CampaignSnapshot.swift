import Foundation

nonisolated struct CampaignSnapshot: Identifiable, Sendable {
    let campaign: CampaignRecord
    let partnerName: String
    let conversations: [ConversationRecord]
    var demoMetrics: DemoCampaignMetrics? = nil
    var id: UUID { campaign.id }
    var recipients: Int { Set(campaign.config.leadIDs).count }
    var salesTouches: Int { if let demoMetrics { return demoMetrics.touches }; return Set(conversations.map(\.leadID)).count }
    func recorded(_ status: ConversationStatus) -> Int { if let demoMetrics { return demoMetrics.count(for: status) }; return Set(conversations.filter { $0.status == status }.map(\.leadID)).count }
}

nonisolated struct DemoCampaignMetrics: Sendable {
    let sent: Int
    let replies: Int
    let touches: Int
    let interested: Int
    let appointments: Int
    let handoffs: Int
    let conversions: Int
    let revenue: Double
    func count(for status: ConversationStatus) -> Int {
        switch status { case .interested: interested; case .appointment: appointments; case .handoff: handoffs; case .closed: conversions; case .new: 0 }
    }
}
