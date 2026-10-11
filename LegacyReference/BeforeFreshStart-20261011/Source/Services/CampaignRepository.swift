import Foundation

nonisolated protocol CampaignRepository: Sendable {
    func workspaces() async throws -> [LeadWorkspaceSummary]
    func campaigns(partnerID: UUID, offset: Int) async throws -> [CampaignRecord]
    func campaign(partnerID: UUID, id: UUID) async throws -> CampaignRecord
    func saveCampaign(partnerID: UUID, id: UUID?, config: CampaignConfig, expectedRevision: Int?) async throws -> CampaignRecord
    func prepareCampaign(partnerID: UUID, id: UUID, expectedRevision: Int) async throws -> CampaignRecord
    func controlCampaign(partnerID: UUID, id: UUID, action: String, reason: String, expectedRevision: Int) async throws -> CampaignRecord
    func campaignHistory(partnerID: UUID, id: UUID, offset: Int) async throws -> [CampaignActivity]
    func conversations(partnerID: UUID, campaignID: UUID, offset: Int) async throws -> [ConversationRecord]
    func trackConversation(partnerID: UUID, campaignID: UUID, leadID: UUID, note: String) async throws -> ConversationRecord
    func updateConversation(partnerID: UUID, campaignID: UUID, id: UUID, status: ConversationStatus, note: String, expectedRevision: Int) async throws -> ConversationRecord
    func conversationHistory(partnerID: UUID, campaignID: UUID, id: UUID, offset: Int) async throws -> [ConversationNote]
}
