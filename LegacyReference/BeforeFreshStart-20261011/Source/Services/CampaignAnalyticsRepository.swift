import Foundation

nonisolated protocol CampaignAnalyticsRepository: Sendable {
    func snapshots() async throws -> [CampaignSnapshot]
}

/// Loads complete, authorized campaign/manual-tracking data behind one async boundary.
actor CampaignAnalyticsService: CampaignAnalyticsRepository {
    private let campaigns: any CampaignRepository
    init(campaigns: any CampaignRepository) { self.campaigns = campaigns }
    func snapshots() async throws -> [CampaignSnapshot] {
        var result: [CampaignSnapshot] = []
        for partner in try await campaigns.workspaces() {
            var records: [CampaignRecord] = []; var offset = 0
            while true {
                let page = try await campaigns.campaigns(partnerID: partner.id, offset: offset)
                records += page; if page.count < 50 { break }; offset += 50
            }
            for campaign in records {
                var conversations: [ConversationRecord] = []; var offset = 0
                while true {
                    let page = try await campaigns.conversations(partnerID: partner.id, campaignID: campaign.id, offset: offset)
                    conversations += page; if page.count < 50 { break }; offset += 50
                }
                result.append(CampaignSnapshot(campaign: campaign, partnerName: partner.name, conversations: conversations))
            }
        }
        return result
    }
}
