import Foundation

nonisolated struct CampaignEditorData: Sendable {
    let emails: [String]
    let leads: [LeadRecord]
    let files: [LeadImportBatch]
    let campaign: CampaignRecord?
    let history: [CampaignActivity]
}

/// Fetches and assembles initial editor data off the main actor. Lists are paginated.
actor CampaignEditorLoader {
    let campaigns: any CampaignRepository
    let leads: any LeadRepository
    init(campaigns: any CampaignRepository, leads: any LeadRepository) { self.campaigns = campaigns; self.leads = leads }
    private func emails(_ partnerID: UUID) async throws -> [String] {
        guard let directory = campaigns as? any SalesHandoffRepository else { return [] }
        return try await directory.handoffEmails(partnerID: partnerID)
    }
    private func campaign(_ partnerID: UUID, _ id: UUID?) async throws -> CampaignRecord? {
        guard let id else { return nil }
        return try await campaigns.campaign(partnerID: partnerID, id: id)
    }
    private func history(_ partnerID: UUID, _ id: UUID?) async throws -> [CampaignActivity] {
        guard let id else { return [] }
        return try await campaigns.campaignHistory(partnerID: partnerID, id: id, offset: 0)
    }
    func load(partnerID: UUID, campaignID: UUID?, importID: UUID?) async throws -> CampaignEditorData {
        async let directory = emails(partnerID)
        async let contacts = leads.leadsInImport(partnerID: partnerID, importID: importID, offset: 0)
        async let files = leads.imports(partnerID: partnerID, offset: 0)
        async let record = campaign(partnerID, campaignID)
        async let events = history(partnerID, campaignID)
        return try await CampaignEditorData(emails: directory, leads: contacts, files: files, campaign: record, history: events)
    }
}
